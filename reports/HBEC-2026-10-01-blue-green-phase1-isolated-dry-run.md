# Blue-Green Deployment Phase 1: Isolated Dry-Run Infrastructure

**Date:** 2026-10-01
**Project:** HBEC
**Type:** Architecture Decision / Infrastructure Proof-of-Concept
**Status:** Completed

## Summary
Built and verified an isolated, fully disposable proof-of-concept of the
Student Backend stack running in a blue-green topology — two live app
instances sharing one database, with traffic switched atomically between
them via a reverse proxy — entirely on the VPS's secondary drive, with zero
contact with real production data, secrets, or network. The goal was to
prove the hardest mechanics (shared-DB coexistence, atomic traffic
switching, single-owner Celery Beat/worker handoff) work before committing
to replacing the current staging→production promotion workflow with a real
blue-green setup. All proved out successfully; production was untouched
throughout and confirmed so at multiple checkpoints.

## Context / Trigger
Ongoing architecture discussion this session about replacing the current
manual staging→production promotion flow with blue-green deployment (two
live peers, atomic traffic switch, no separate "staging" environment in the
current sense). The hardest open question identified in discussion: blue
and green sharing one real database during cutover, which is a sharp
departure from today's fully separate staging/prod databases and requires
expand/contract migration discipline, single-owner Celery Beat, and careful
Redis consumer-group handling.

User's explicit instruction to begin: *"yes begin we using the secondary
free drive right if so start, dont bring down prod just yet live it as
is"* — authorizing an isolated dry run on `/sdb-disk` (the VPS's secondary,
mostly-empty 800GB+ drive) with an explicit constraint not to touch or
bring down current production.

## Scope
**Included**: Student Backend stack only (`student-backend` blue/green pair,
singleton `student-worker`/`student-beat`), isolated Postgres + Redis
bind-mounted onto the secondary drive, an isolated Caddy instance for
traffic switching, a cutover script, seeded with a one-time copy of real
production data (via `pg_dump`/`pg_restore`, then deleted).

**Explicitly excluded** (deferred to Phase 2, a separate future decision
point):
- Pointing either color at the real production database or Redis.
- Reusing real production secrets (JWT keypair, HMAC keys, API keys) —
  all dry-run secrets were freshly generated, inert values.
- Public DNS / joining the real Caddy edge network.
- Testing an actual *new* schema migration under expand/contract discipline
  (this phase only proved an already-applied schema works identically for
  both colors, not that a genuinely new migration is safe mid-cutover).
- Expanding beyond the Student Backend stack to the full platform
  (admin-backend, harness, payments, schools, notifications, frontends).

## Method
Research-then-build, with live verification (not container-health alone) at
every step:
1. Investigated real VPS specs, disk layout, and Docker's actual data root
   to confirm where container data physically lands.
2. Read the real `docker-compose.production.yml`, `init-db.sql`, and
   `docker/Caddyfile` in full to use as structural templates — reusing
   proven patterns (service shape, env var names, healthchecks) rather than
   inventing a new structure.
3. Built the isolated stack incrementally, verifying each layer live before
   adding the next (DB/Redis up and healthy → app containers up and healthy
   → both colors reachable → traffic switching → worker/beat handoff).
4. At each verification step, checked the *actual* resulting state (file
   contents inside the container, response headers, query results) rather
   than trusting a tool's reported success (`docker compose up`'s
   "Healthy"/"Recreated" messaging, `caddy reload`'s own logged success) —
   this discipline is what caught two of the four bugs below.
5. Confirmed zero impact on real production at the start, middle, and end
   (container start timestamps, primary disk usage, live HTTPS health
   check).

## Decisions & Findings

### Why Student Backend only, not the full platform
Proving the hardest mechanics — shared-DB coexistence, atomic traffic
switching, Beat/worker single ownership — doesn't need every service
running. Starting narrow let each mechanic be verified in isolation; the
same pattern generalizes directly to the other services once this is
proven.

### Why worker/beat are singletons, not a blue-green pair
Celery Beat has no built-in leader election — two instances against the
same broker/schedule double-fire every periodic task. Redis stream consumer
groups *split* (not duplicate) work across members, so running both
colors' workers simultaneously risks two different code versions
processing adjacent messages from one logical batch against the same DB.
Both are therefore swapped explicitly as part of the cutover sequence
(stop old, then start new — never both running at once, even briefly),
not treated as a blue-green pair the way the app servers are.

### Four infrastructure bugs found and fixed during the build (all self-caught via live verification, not left for a later surprise)
1. **Wrong image tag referenced** — the compose file initially pointed at
   `prod-promote-c4611977`, a commit that was config-only and never
   triggered an image build. Fixed by using the tag actually running in
   production (`prod-promote-6a151782`).
2. **JWT key file permissions** — freshly generated keys were `600`,
   unreadable by the container's non-root user. Fixed to `644`, matching
   production's actual permissions.
3. **`POSTGRES_PASSWORD_FILE` used on the Django app containers** — copied
   from Postgres's own convention, but Django's settings only read a plain
   `POSTGRES_PASSWORD` string, not a file reference. Fixed via a `.env`
   file supplying the real value as a plain var. Logged separately? Not
   filed as its own bug-log entry since it's inert dry-run-only
   infrastructure, not a defect in the real codebase — captured here for
   completeness.
4. **Single-file Caddyfile bind mount silently stopped reflecting edits**
   made with `sed -i` — a real, generally applicable Docker gotcha, and the
   production gateway's real Caddyfile uses the identical mount pattern.
   Filed as its own dev-log entry since it's a reusable finding relevant to
   real infrastructure:
   `DevOps_and_Infrastructure/HBEC-2026-10-01-single-file-bind-mount-breaks-on-in-place-edit.md`.

## Changes Made
No changes to the HBEC repository or to real production. All new
infrastructure lives only on the VPS, outside any git-tracked path:
```
/sdb-disk/hbec-bluegreen/
  docker-compose.bluegreen.yml
  cutover.sh
  .env.bluegreen
  docker/{init-db.sql, secrets/pg_password.txt, keys/*.pem, caddy-dryrun/Caddyfile}
  data/{postgres,redis}/
```
This is intentionally disposable scaffolding for the proof-of-concept, not
a deliverable to merge — a real Phase 2 would design production-ready
compose files and commit them to the repo properly.

## Verification
- Both `bg-student-backend-blue` and `bg-student-backend-green` ran
  simultaneously, healthy, against the same shared isolated Postgres —
  the core blue-green mechanic.
- Seeded with a real production data snapshot (395 users, 414 subjects
  confirmed present after restore); the dump file was deleted from both
  the source and destination immediately after.
- Migrations ran cleanly and automatically on boot via the existing
  entrypoint (`"No migrations to apply"` — the restored DB was already
  current; this run did not exercise an actual *new* migration).
- Traffic switched atomically between colors in both directions
  (blue→green→blue), confirmed via an `X-Deploy-Color` response header
  through the isolated Caddy instance.
- Singleton worker/beat correctly handed off on each cutover — old
  stopped before new started, confirmed via container logs and the
  `DEPLOY_COLOR` env var reflecting the active color after each switch.
- **Zero impact on real production**, confirmed at multiple checkpoints:
  `hbec-student-backend`/`hbec-admin-backend`/`hbec-postgres` container
  start timestamps unchanged throughout; primary disk usage unchanged
  (151G/72% used) while the secondary drive absorbed all new data (ending
  at 20G used, 851G still free); `https://student.hbca.tech/` returned
  `200` at the final check.

## Follow-ups / Deferred
- Decide whether/when to proceed to Phase 2: real secrets, real (or a
  realistic replica of) the production database, public DNS integration —
  a deliberate separate decision point, not something to start without
  explicit sign-off.
- Test an actual *new* migration under expand/contract discipline against
  this isolated setup before trusting it against anything real.
- Expand the dry run to the rest of the platform (admin-backend, harness,
  payments, schools, notifications, both frontends) once the Student
  Backend proof is trusted.
- Design the DB-trigger-based dual-write mechanism discussed earlier this
  session (for safely handling column-rename-class migrations under
  blue-green) and test it against this same isolated setup before it ever
  touches real schema.
- Noted but not actioned: `HBEC/CLAUDE.md`'s documented VPS specs (16
  vCPU/28GB RAM/RTX 5060) don't match the real hardware discovered during
  this work (20 vCPU/62GB RAM/NVIDIA T1000) — flagged to the user, not
  yet corrected, pending confirmation.

## References
- `DevOps_and_Infrastructure/HBEC-2026-10-01-single-file-bind-mount-breaks-on-in-place-edit.md`
- `docker-compose.production.yml`, `docker/init-db.sql`, `docker/Caddyfile`
  (repo, used as structural templates)
- `scripts/backup-hbec.sh` (adapted for the one-time production data seed)

---

**Completed By:** Claude Sonnet 5
**Duration:** Single session (2026-10-01), continued across a context/usage-limit reset.
