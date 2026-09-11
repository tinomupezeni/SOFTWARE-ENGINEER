# `zchpc-hbca-vps` Has No Celery Beat/Worker Containers — Admin Content Has Never Auto-Replicated There

**Date:** 2026-09-09
**Project:** HBEC
**Environment:** `zchpc-hbca-vps` (a separate, single-environment deployment)
**Severity:** High
**Status:** Identified, Not Fixed — worked around for one specific record, underlying gap remains

## Summary
While applying an O-Level exam-board data fix across all three HBEC environments, the same fix that propagated automatically on `hbca-vps` production and staging within seconds simply never arrived on `zchpc-hbca-vps`. The reason: this host runs **no Celery beat or worker containers at all** — not Admin's outbox-drainer, not the student backend's stream consumer. Both halves of the admin→student replication pipeline depend on a Celery beat task running every 10 seconds; neither exists here. This means no content change Admin has ever published — this exam board or anything else — has automatically reached students on this environment.

## Symptoms
- Admin-side `ExamBoard.save()` correctly queued a `StreamOutbox` row (log line confirmed: `Outbox queued exam_board updated: ZIM-HBCA`) and updated the Admin DB.
- The student-side `curriculum_examboard.supported_levels` field on the same host stayed at its old value indefinitely — no delay, permanently stale, because nothing was ever going to drain the outbox.
- `docker ps -a` on the host shows a full application stack (harness, student/admin backend and frontend, schools, payments, litellm, ollama, qdrant, postgres/pgbouncer, redis) but **zero** containers matching beat/worker for either service.

## Environment Details
- **Server/Host:** `zchpc-hbca-vps` (`ssh zchpc-hbca-vps`, root@192.168.50.245) — a standalone deployment, not part of the `hbca-vps` prod/staging pair
- **Services Affected:** All Admin→Student content replication (exam boards, grades, subjects, topics, papers, marking standards, SBP templates) — everything `apps/replication/signals.py` (Admin) and `apps/replication/stream_consumer.py` (Student) are responsible for
- **Related Components:** `docker-compose.production.yml`'s (or whatever compose file this host actually runs) `admin-beat`/`admin-worker`/`student-beat`/`student-worker` service definitions
- **Time First Observed:** 2026-09-09, discovered as a side effect of deploying an unrelated data fix, not through any monitoring or alert

## Investigation Steps

### 1. Initial Diagnosis
Applied the same `ExamBoard.save()` fix used successfully on `hbca-vps` prod and staging (both propagated within seconds). Re-checked the student-side value on `zchpc-hbca-vps` and found it unchanged.

### 2. Root Cause Analysis
```bash
docker ps -a --format "{{.Names}}"
# hbec-pgbouncer, hbec-main-pgbouncer, hbec-redis-sentinel, hbec-harness,
# hbec-student-frontend, hbec-admin-frontend, hbec-redis-replica, hbec-litellm,
# hbec-schools-backend, hbec-payments, hbec-student-backend, hbec-admin-backend,
# hbec-harness-db, hbec-gateway, hbec-redis, hbec-qdrant, hbec-ollama,
# hbec-harness-embeddings, hbec-schools-dashboard, hbec-postgres
```
No `-beat` or `-worker` container anywhere in the list — not running, not stopped, not present at all. Per `CLAUDE.md`, the admin→student pipeline is signal-driven → `StreamOutbox` → Celery beat (`poll_stream_outbox`, every 10s) → Redis stream → student backend's own Celery-beat-driven `stream_consumer.py`. Both beat schedules live in worker/beat containers this host simply never got.

### 3. Key Findings
- This isn't a transient failure or a stuck queue — there has never been a process on this host capable of draining `StreamOutbox` or consuming the replication stream.
- `hbca-vps` (both prod and staging) correctly runs `admin-beat`, `admin-worker`, `student-beat`, `student-worker` containers — this gap is specific to `zchpc-hbca-vps`'s deployment, not a code issue.
- Because nothing alerts on outbox backlog size or replication lag, this has been silently accumulating unreplicated content indefinitely with no signal anywhere that it was happening.

## Root Cause
Whatever process stood up `zchpc-hbca-vps` never deployed the `admin-beat`/`admin-worker`/`student-beat`/`student-worker` services that the replication pipeline requires, and nothing has caught the absence since — the rest of the stack runs fine without them, so there's no crash or error, just permanently stale content.

## Solution

### Immediate Fix (workaround, not a real fix)
Applied to unblock one specific record: since the Admin side was already correctly fixed, directly wrote the same translated value Admin's `_handle_exam_board` would have produced onto the student-side `ExamBoard.supported_levels` via the ORM (not raw SQL) — functionally equivalent to what the pipeline would have done, just performed by hand because the pipeline doesn't exist here. This does **not** fix the underlying gap and does **not** scale — every other piece of content already published from Admin while this host has been running is presumably in the same stale state, and nothing new will replicate either.

### Long-term Fix — Not Done
Deploy the missing `admin-beat`, `admin-worker`, `student-beat`, `student-worker` services on `zchpc-hbca-vps`, matching whatever compose profile `hbca-vps` production actually runs them under. Once running, likely need `docker exec hbec-admin-backend python manage.py republish_canonical` (or equivalent) to catch this host up on everything it's missed, not just the one record fixed by hand today.

## Prevention
- [ ] Deploy the missing beat/worker containers on `zchpc-hbca-vps`
- [ ] After deploying them, run a full `republish_canonical` (or equivalent) to catch up on everything missed
- [ ] Monitoring/alerts to add: alert on `StreamOutbox` backlog size and on replication lag, so a missing consumer is visible immediately rather than discovered incidentally
- [ ] Audit whether any other environment/host in this project has the same gap — this one was found by accident, not by any systematic check

## Related Issues
- [2026-09-09: O-Level Silently Unselectable — Dropped From Every Exam Board's supported_levels](./2026-09-09-olevel-not-in-exam-board-supported-levels.md) — the fix that surfaced this gap
- [2026-09-09: Staging Postgres/Pgbouncer Password Drift](./2026-09-09-staging-postgres-secret-drift-crash-loop.md) — a different infra-drift issue found the same session, on a different host

## References
- `docker-compose.production.yml` (or the compose file actually deployed on this host) — `admin-beat`/`admin-worker`/`student-beat`/`student-worker` service definitions
- `ADMIN/adminBackend/apps/replication/signals.py`, `tasks.py` (`poll_stream_outbox`)
- `STUDENT/hbec_backend/apps/replication/stream_consumer.py`
- `ADMIN/adminBackend/apps/replication/management/commands/republish_canonical.py`

---

**Identified By:** Claude Code (Sonnet 5)
**Status:** One record worked around; the actual fix (deploying the missing services) not done
