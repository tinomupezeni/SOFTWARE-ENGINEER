# A floating celery[redis] outgrew its pinned redis-py ceiling and killed every Celery worker on deploy

**Date:** 2026-11-10
**Project:** HBEC
**Environment:** Production (VPS, blue-green)
**Severity:** High
**Status:** Resolved

## Summary
Deploying PR #120 (heritage subject-gate fix) to production via the manual
blue-green runbook built and cut over cleanly on the web-serving side, but
`student-worker` and `admin-worker` (Celery) came up unhealthy immediately
after cutover and blocked the rest of the singleton follower handoff
(`admin-beat`, `student-beat`). Root cause was an unrelated, pre-existing
dependency pin that had simply never been exercised by a fresh rebuild until
this deploy.

## Symptoms
- `manual-cutover.sh` flipped Caddy to the new color successfully (web
  traffic fine, all 10 colored app services healthy and verified on-SHA),
  but failed at the "hand singleton workers/beats to the new color" step:
  `dependency failed to start: container hbec-student-worker is unhealthy`.
- `docker logs hbec-student-worker` / `hbec-admin-worker` showed Celery
  dying on startup with `kombu.exceptions.VersionMismatch: Redis transport
  requires redis-py versions 6.1.0 or later. You have 5.3.1`.
- `hbec-notifications-worker` (same host, same cutover) came up healthy —
  its requirements file resolves to a different dependency set.

## Environment Details
- **Server/Host:** production VPS (`/opt/hbec`), blue-green deploy
- **Services Affected:** `student-worker`, `admin-worker` (Celery); by
  extension `student-beat`, `admin-beat` never started (blocked on the
  dependency failure), stalling replication, remarking sweeps, streak
  writes, reminders and every other Celery-driven background job
- **Related Components:** `STUDENT/hbec_backend/requirements.txt`,
  `ADMIN/adminBackend/requirements/base.txt`, `scripts/deploy/manual-cutover.sh`
- **Time First Observed:** 2026-11-10, during the first cutover of PR #120
  (commit `437d14c67`)

## Investigation Steps

### 1. Initial Diagnosis
Checked `docker ps -a` for the follower containers — `student-worker` and
`admin-worker` were stuck in a restart loop (`health: starting` →
unhealthy), while the content-serving containers for the same color were
all healthy. Pulled the worker's own logs.

### 2. Root Cause Analysis
```bash
docker logs hbec-student-worker --tail 60
# kombu.exceptions.VersionMismatch: Redis transport requires redis-py
# versions 6.1.0 or later. You have 5.3.1

docker exec hbec-notifications-worker pip show redis kombu celery
# redis 8.1.0 / kombu 5.7.0 / celery 5.7.0  -> healthy

grep -n "redis\|celery" STUDENT/hbec_backend/requirements.txt \
                        ADMIN/adminBackend/requirements/base.txt \
                        NOTIFICATIONS/requirements.txt
# student + admin: celery[redis]>=5.x,<6.0 / redis>=5.0,<6.0 (upper-bounded)
# notifications:   celery>=5.4.0 / redis[hiredis]>=5.1.0 (no upper bound)
```
Both broken services pin `redis>=5.0,<6.0` against an **unbounded**
`celery[redis]`. With no lock file, a fresh `pip install` picks the newest
`celery`/`kombu` allowed by that range — which is now 5.7.0, and 5.7's
Redis transport hard-refuses redis-py below 6.1.0. The `<6.0` ceiling on
`redis` made that combination unsatisfiable in a *correct* way (pip should
have refused to resolve it), but at build time pip's resolver picked
`redis==5.3.1` anyway, which only raises at runtime via kombu's manual
version gate — so the build succeeded and the break only surfaced when the
container actually tried to connect.

### 3. Key Findings
- The pin predates this deploy entirely (`git log -p` shows it unchanged
  since it was first added) — this was not introduced by PR #120. It was
  latent: any fresh image rebuild of student-backend or admin-backend from
  this point on would have hit it, regardless of what else changed.
- `notifications`'s unbounded `redis[hiredis]>=5.1.0` resolved to the exact
  combination (`redis 8.1.0` + `kombu 5.7.0`) that worked — proving the fix
  direction immediately, with a live, already-running example on the same
  host.
- Confirmed the fix with a dry-run resolve before touching production again:
  `pip install --dry-run "redis>=6.1,<9.0" "celery[redis]>=5.3,<6.0"
  "django-redis>=5.4,<6.0"` resolved cleanly to celery 5.7.0 / kombu 5.7.0 /
  redis 8.1.0 / django-redis 5.4.0 — no conflict with the existing
  `django-redis` ceiling.

## Root Cause
`STUDENT/hbec_backend/requirements.txt` and
`ADMIN/adminBackend/requirements/base.txt` pinned `redis>=5.0,<6.0` while
leaving `celery[redis]`'s own transitive `kombu` dependency unbounded. Once
kombu's release line crossed the point where its Redis transport requires
redis-py ≥6.1.0, the two pins in the same file became mutually
unsatisfiable at runtime — but nothing in the build enforced that, so the
image built "successfully" with a broken combination baked in, and the
failure only appeared the moment the containers actually tried to connect
to Redis in production.

## Prevention / Rule
**Guardrail:** lock dependencies (e.g. `pip-compile`/`uv lock`) for
`STUDENT/hbec_backend` and `ADMIN/adminBackend` so a rebuild resolves to the
exact versions last verified, not whatever the floating ranges allow on
build day; CI fails if the lock file is stale against `requirements.txt`.

This closes the gap directly: the bug existed because two *independently
plausible* version ranges, written on different days, turned out to be
jointly impossible once a third library's own floor moved — a class of
break no amount of "be more careful" catches, because neither range was
wrong in isolation. A lock file pins the resolver's actual choice so this
can only break at the moment someone deliberately re-resolves and reviews
the diff, not silently on the next unrelated rebuild.

## Solution

### Immediate Fix
Blue-green made this safe to fix forward rather than roll back: web traffic
was already healthy on the new color, so the broken color's workers were
left stopped while the fix was prepared, built into the *other* (then
inactive) color, verified, and cut over again.

```bash
# requirements fix (both files):
# redis>=5.0,<6.0  ->  redis>=6.1,<9.0

# redeploy the (then-inactive) color at the fixed commit, verify, cut over:
bash scripts/deploy/manual-deploy-color.sh   # builds + verifies all 10 images + the fix
bash scripts/deploy/manual-cutover.sh        # flips traffic AND re-runs the follower handoff
```
Second cutover completed clean: all 10 app services plus all 7
worker/beat/embeddings singletons verified on-SHA and healthy.

### Long-term Fix
Add the lock-file guardrail above for both backends' Python dependencies,
mirroring how `admin-backend`'s test toolchain is already version-bounded
in CI per the project's own CLAUDE.md note on floating test tooling.

## Prevention
- [ ] Add `pip-compile`/`uv lock` + a CI staleness check for
      `STUDENT/hbec_backend` and `ADMIN/adminBackend`
- [ ] Audit other unbounded-vs-bounded dependency pairs across the 3
      backend requirement files for the same latent-conflict shape
- [x] Monitoring/alerts to add — N/A, caught live during a verified cutover,
      not silently in the background
- [x] Documentation to update — N/A
- [x] Code changes required — done (requirements pin raised)

## Related Issues
- Surfaced during the deploy of PR #120 (heritage subject-gate +
  search-window fix) — see
  `reports/HBEC-2026-11-10-heritage-subject-gate-merge-and-deploy.md` for
  the full deploy narrative this bug was found inside of.

## References
- `STUDENT/hbec_backend/requirements.txt`
- `ADMIN/adminBackend/requirements/base.txt`
- `NOTIFICATIONS/requirements.txt` (the working reference combination)
- `scripts/deploy/manual-deploy-color.sh`, `scripts/deploy/manual-cutover.sh`

---

**Resolved By:** Tinotenda Mupezeni (with Claude Code)
**Time to Resolution:** ~25 minutes (diagnosis to verified second cutover)
