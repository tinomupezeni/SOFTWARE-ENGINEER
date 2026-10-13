# notifications-backend-blue held a stale REDIS_URL pointed at the read-only replica; the drift checker couldn't have caught it

**Date:** 2026-10-13
**Project:** HBEC Platform
**Environment:** Production (`hbca-vps`)
**Severity:** High (real user-facing 500 on a live admin action; silent for an unknown prior period)
**Status:** Resolved

## Summary
`PATCH /v1/notifications/drafts/{id}/approve` 500'd in production. Root cause:
`hbec-notifications-backend-blue` — the container serving 100% of real
traffic — was running with `REDIS_URL=redis://redis-replica:6379/3` (the
read-only replica) instead of `redis://redis:6379/3` (master), while the
committed compose file, and this same service's own `notifications-worker`/
`notifications-beat` siblings, were already correct. The container simply
hadn't been recreated since whenever this was last wrong. Reads kept working
(hence no earlier visible symptom); the first write-triggering action —
approving a draft, which publishes a Celery task — failed with
`redis.exceptions.ReadOnlyError`.

## Symptoms
- Admin-reported: `Server error (500) — /v1/notifications/drafts/{id}/approve`.
- `hbec-notifications-backend-blue` logs: `kombu.exceptions.OperationalError:
  You can't write against a read only replica.`, raised from
  `fan_out_draft.delay()` inside `approve_draft`.
- Every GET on the same service (`/notifications/banner`, `/notifications?status=all`,
  the websocket, drafts list) returned `200` throughout — reads against a
  replica work fine, which is exactly what made this invisible until a write
  was attempted.
- Not present in the HTTP error tracker at all, for any time range, for this
  service — confirmed the tracker isn't wired for notifications; found this
  purely by reading live container logs.

## Environment Details
- **Server/Host:** hbca-vps, `hbec-notifications-backend-blue`
- **Services Affected:** `NOTIFICATIONS` (web container only — worker/beat
  were already correct)
- **Related Components:** Redis (`redis` master vs `redis-replica`), Celery/Kombu
- **Time First Observed:** 2026-10-13T13:55:33Z

## Investigation Steps

### 1. Initial Diagnosis
User provided the exact failing path. Checked the error tracker first (zero
hits, any time range, any status code, for this service) — confirmed the
tracker doesn't cover this service, so went straight to live logs.

### 2. Root Cause Analysis
```bash
ssh hbca-vps "sudo docker logs hbec-notifications-backend-blue --since 6h -t 2>&1 | grep -i '<draft-id>'"
```
Found the full traceback ending in `redis.exceptions.ReadOnlyError`. Checked
`redis-cli info replication` on the primary — `role:master`, no failover in
progress, one connected slave, healthy — ruling out an actual live Sentinel
failover as the trigger. Checked `redis-sentinel`'s own logs for the same
window — nothing, confirming no failover event had occurred at all. Then
compared the container's actual env directly:
```bash
docker exec hbec-notifications-backend-blue env | grep REDIS_URL
# redis://redis-replica:6379/3   <-- wrong
docker exec hbec-notifications-worker env | grep REDIS_URL
docker exec hbec-notifications-beat env | grep REDIS_URL
# both: redis://redis:6379/3     <-- correct, same compose anchor's sibling values
```
Grepped the entire committed `docker-compose.production.yml` for `REDIS_URL`
— every single reference, for every service, was `redis://redis:6379/...`.
No `redis-replica` string exists anywhere in the file. Confirmed
`notifications-backend-green` (recreated minutes earlier for an unrelated
deploy) already had the correct value from the same compose source.

### 3. Key Findings
- The compose file was never wrong. This was pure runtime drift: a
  long-running container holding a stale value baked in at whenever it was
  last created, never refreshed since.
- The *existing* runtime-drift checker (`scripts/check_runtime_secret_drift.py`,
  already run as the last step of every `deploy-color`/`cutover`) would not
  have caught this even if `REDIS_URL` had been a tracked variable: it only
  ever compares the bare/legacy service name (`notifications`) against
  `notifications-worker`/`-beat`. The legacy `notifications` container
  carries zero real traffic once a color is live and was never wrong — so
  the check would have read "all agree, clean" throughout this entire
  incident while the actual traffic-serving `-blue` container was broken.

## Root Cause
Two independent gaps compounded:
1. Whatever process last created `notifications-backend-blue` did so with
   (or later drifted to) an incorrect `REDIS_URL`, and nothing since has
   recreated that specific container to pick up the always-correct compose
   value.
2. The runtime drift-detection mechanism built for exactly this failure
   shape (`scripts/runtime_secrets.py`'s own docstring: "a long-running
   process holding a stale value") structurally could not see it, because
   it compares against the legacy singleton instead of whichever color is
   actually live.

## Prevention / Rule
**Guardrail:** `scripts/check_runtime_secret_drift.py` now resolves every
service name to its *live color's own container* (reading `active_color`,
the same convention `scripts/deploy/color-env.sh` uses) before comparing,
falling back to the bare name only when no colored variant exists (worker/
beat/shared singletons, or a pre-blue-green stack like staging). `REDIS_URL`
was also added as a compared group for all three web+worker+beat trios
(student-backend, admin-backend, notifications) — there was no `REDIS_URL`
check at all before this, for any service. This runs automatically on every
future `deploy-color`/`cutover` and will fail the deploy loudly the moment
any service's live container disagrees with its own worker/beat on this
value, rather than waiting for a real admin action to surface it.

**Second, independent guardrail:** `approve_draft`'s Celery dispatch is now
wrapped so a broker failure (whatever causes it — this drift, or a genuine
future Sentinel failover) logs loudly but never fails a request whose
database-side approval has already committed. This doesn't prevent the
underlying cause, but it converts "500, approval lost" into "approval
stands, fan-out failure is visible in logs" — matching the same principle
already applied at two other call sites in this codebase (admin paper
creation, harness paper generation).

## Solution

### Immediate Fix
```bash
# Recreated the one container, on its SAME image/revision (no code change) -
# this just refreshes it from the already-correct compose config.
source scripts/deploy/color-env.sh blue >/dev/null
docker compose -f docker-compose.production.yml --profile color-blue \
  up -d --no-deps notifications-blue
```
Verified: `REDIS_URL` corrected, container healthy, a real `redis.set()` and
a real Celery `send_task()` both succeeded post-recreate (not just that the
env var looked right).

### Long-term Fix
- `scripts/check_runtime_secret_drift.py` + `scripts/runtime_secrets.py`:
  active-color resolution (see Prevention/Rule above) plus three new
  `REDIS_URL` comparison groups.
- `NOTIFICATIONS/app/notifications/router_admin.py`: `fan_out_draft.delay()`
  wrapped in try/except, logs `redis_readonly_replica` explicitly when
  detected (matching the project's established READONLY-diagnostic
  convention), never fails the already-committed approval.

Both deployed to the idle (`green`) blue-green color on `hbca-vps`,
verified (revisions, signed links, secret drift — now 12 groups instead of
9 — all pass). Blue, serving live traffic, was untouched by this second
deploy (only the one-off container recreation above touched blue, and only
to fix its own drift, on the same code).

## Prevention
- [x] Drift checker closed (active-color resolution + REDIS_URL groups)
- [x] `approve_draft` hardened against the same failure class recurring for
      a genuine reason (a real Sentinel failover), not just this drift
- [x] Regression tests reproduce the exact incident for both layers,
      including a test proving the *old* checker behavior would have missed it
- [ ] Consider wiring the HTTP error tracker to cover the notifications
      service at all — it currently has zero historical coverage, for any
      status code, which is how this and the "no tracker hits" dead end in
      the initial investigation both happened

## Related Issues
- None directly, but this is the same failure *class* as the two prior
  "a side effect must not fail the thing that already succeeded" fixes
  (admin paper creation, harness paper generation) — see HBEC `CLAUDE.md`'s
  own cross-reference under that heading.

## References
- `scripts/runtime_secrets.py`, `scripts/check_runtime_secret_drift.py`
- `scripts/tests/test_check_runtime_secret_drift.py`
- `NOTIFICATIONS/app/notifications/router_admin.py` (`approve_draft`)
- `NOTIFICATIONS/tests/test_router_admin.py`
- HBEC PR #98

---

**Resolved By:** Tinotenda Mupezeni
**Time to Resolution:** ~1.5 hours (investigation, immediate fix, and the
two prevention layers through to deployed+verified)
