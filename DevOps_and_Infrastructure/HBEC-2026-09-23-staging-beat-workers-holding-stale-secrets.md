# Every Celery Beat Container on Staging Holds Stale Secrets — Found via the Runtime Drift Guardrail, Not Yet Fixed

**Date:** 2026-09-23
**Project:** HBEC
**Environment:** Staging
**Severity:** Medium — no live symptom reported yet; found by tooling,
not a user
**Status:** Investigating — found, not fixed. Flagged for follow-up.

## Summary
Running `scripts/check_runtime_secret_drift.py` against staging (as
verification after fixing an unrelated Postgres password drift, see
`HBEC-2026-09-23-staging-postgres-drift-4th-recurrence-guardrail-closed.md`)
reported 7 of the tool's 9 registered secret groups disagreeing at
runtime. In every case, the pattern is identical: `admin-worker` and
`student-worker` match their corresponding main service
(`admin-backend`/`student-backend`); `admin-beat`, `student-beat`, and
every `notifications-*` container hold a **different** value for the same
variable.

## Symptoms
None live-reported — this is a tooling finding, not a user-facing
incident. A Celery beat process that can't actually authenticate to
something it needs to call (e.g. `REPLICATION_HMAC_KEY`-signed requests
from `admin-beat` to Student Backend or the Harness) would silently fail
those specific scheduled tasks rather than crash-loop, which is likely why
nothing has surfaced yet.

## Environment Details
- **Server/Host:** `hbca-vps`, staging only
- **Services Affected:** `hbec-admin-beat-staging`, `hbec-student-beat-staging`,
  `hbec-notifications-staging`, `hbec-notifications-worker-staging`,
  `hbec-notifications-beat-staging` — all holding a stale value versus
  their corresponding main/worker service across:
  - JWT public key (session tokens)
  - `PAYMENTS_INTERNAL_SECRET`
  - `HARNESS_WEBHOOK_SECRET`/`WEBHOOK_SECRET`
  - `PAYMENTS_WEBHOOK_SECRET`/`WEBHOOK_SECRET`
  - `REPLICATION_HMAC_KEY`
  - `SCHOOLS_ADMIN_SECRET`
  - `ADMIN_JWT_SECRET`/`SECRET_KEY`

## Investigation Steps

### 1. Initial Diagnosis
```bash
python3 scripts/check_runtime_secret_drift.py \
  --compose-file docker-compose.staging.yml --env-file .env.staging
```
reported all 7 pre-existing (non-`db_auth`) groups as disagreeing, each
with the identical worker-matches/beat-and-notifications-differ shape.

### 2. Root Cause Analysis
Not yet done. The consistent pattern (workers current, beats and
notifications stale) strongly suggests these specific containers simply
haven't been restarted since the last time one or more of these secrets
were rotated in `.env.staging` — the same mechanism as every prior secret-
drift incident in this repo, just on a different set of containers.
Whether it's one rotation event or several has not been established.

## Root Cause
Not yet determined — flagged for the same investigation pattern as the
Postgres incidents (confirm current `.env.staging` values, confirm what
each stale container actually holds, restart to reconcile).

## Prevention / Rule
No new guardrail needed — this is exactly what
`scripts/check_runtime_secret_drift.py` exists to catch, and it caught it
correctly. The actual fix is operational (restart the stale containers),
not a code or tooling change.

## Solution

### Immediate Fix
Not applied in this pass — deliberately out of scope for the session that
found it (a live Postgres crash loop was the active incident; this is a
lower-severity, no-current-symptom finding surfaced as a side effect of
verifying that fix).

### Long-term Fix
- Restart `admin-beat`, `student-beat`, `notifications`,
  `notifications-worker`, `notifications-beat` on staging to pick up
  current `.env.staging` values.
- Re-run `scripts/check_runtime_secret_drift.py` afterward to confirm all
  9 groups report OK.
- Worth checking whether the same pattern exists on **production** — this
  pass only ran the checker against staging.

## Verification
Not yet — fix not applied.

## Prevention
- [ ] Configuration changes needed — restart the 5 stale containers listed
  above
- [x] Monitoring/alerts to add — n/a, the guardrail that caught this
  already exists
- [x] Documentation to update — this entry
- [ ] Code changes required — none anticipated; operational fix only

## Related Issues
- `HBEC-2026-09-23-staging-postgres-drift-4th-recurrence-guardrail-closed.md`
  — found while verifying that entry's fix.
- `HBEC-2026-09-16-runtime-secret-drift-had-no-detection-mechanism.md` —
  the guardrail that caught this.

## References
- `scripts/check_runtime_secret_drift.py`, `scripts/runtime_secrets.py`

---

**Resolved By:** Claude Sonnet 5 (found, not resolved)
**Time to Resolution:** N/A — open
