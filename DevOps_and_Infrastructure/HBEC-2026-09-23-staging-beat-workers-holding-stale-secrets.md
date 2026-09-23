# Staging: Beat/Notification Workers, Payments, and Schools-Backend All Holding Stale Secrets — Found and Fixed via the Runtime Drift Guardrail

**Date:** 2026-09-23
**Project:** HBEC
**Environment:** Staging
**Severity:** Medium — no live symptom reported yet; found by tooling,
not a user
**Status:** Resolved

## Summary
Running `scripts/check_runtime_secret_drift.py` against staging (as
verification after fixing an unrelated Postgres password drift, see
`HBEC-2026-09-23-staging-postgres-drift-4th-recurrence-guardrail-closed.md`)
reported 7 of the tool's 9 registered secret groups disagreeing at
runtime. The pattern looked uniform at first: `admin-worker`/
`student-worker` matched their main service; `admin-beat`, `student-beat`,
and every `notifications-*` container held a different value. Restarting
those 5 containers to pick up current `.env.staging` values fully resolved
4 of the 7 groups — but re-running the checker afterward revealed the
other 3 had been a coincidence of timing, not the same root cause: with
the beat-side noise gone, `payments-staging` and `schools-backend-staging`
stood out on their own as a **second, independent** instance of stale
containers, unrelated to the beat/worker pattern.

## Symptoms
None live-reported — a tooling finding, not a user-facing incident. A
process holding a stale secret for a call it makes rarely (a scheduled
Celery beat task, or a cross-service call `payments`/`schools-backend`
only make occasionally) fails quietly rather than crash-looping, which is
almost certainly why nothing had surfaced yet.

## Environment Details
- **Server/Host:** `hbca-vps`, staging only
- **Services Affected (first pass):** `hbec-admin-beat-staging`,
  `hbec-student-beat-staging`, `hbec-notifications-backend-staging`,
  `hbec-notifications-worker-staging`, `hbec-notifications-beat-staging`
- **Services Affected (second pass, only visible after the first fix):**
  `hbec-payments-staging`, `hbec-schools-backend-staging`

## Investigation Steps

### 1. Initial Diagnosis
```bash
python3 scripts/check_runtime_secret_drift.py \
  --compose-file docker-compose.staging.yml --env-file .env.staging
```
reported 7 groups disagreeing, each in the worker-matches/beat-and-
notifications-differ shape.

### 2. First Fix
```bash
docker compose -f docker-compose.staging.yml --env-file .env.staging \
  --profile workers up -d --force-recreate \
  admin-beat student-beat notifications notifications-worker notifications-beat
```
Re-ran the checker: 4 groups now fully OK. The remaining 3
(`PAYMENTS_INTERNAL_SECRET`, `PAYMENTS_WEBHOOK_SECRET`/`WEBHOOK_SECRET`,
`SCHOOLS_ADMIN_SECRET`) still failed, but the disagreeing pair had changed
— now specifically `payments` and `schools-backend` against everything
else, not against the just-fixed beat containers.

### 3. Root Cause Analysis
Re-reading the *original* (pre-fix) output line by line explained it:
```
PAYMENTS_INTERNAL_SECRET: payments=713d1dec0d6d, student-backend=f9d40016758a,
                           student-beat=713d1dec0d6d, student-worker=f9d40016758a
```
`student-beat` had coincidentally matched `payments`'s stale value before
the fix — not because they shared a cause, but because both happened to
still be holding whatever `PAYMENTS_INTERNAL_SECRET` was before its last
rotation. Fixing `student-beat` alone didn't touch `payments`, so the
group kept failing, just with a cleaner 3-vs-1 shape that made the real
outlier (`payments`) obvious. Confirmed against the authoritative source
before restarting anything:
```bash
grep '^PAYMENTS_INTERNAL_SECRET=' .env.staging | cut -d= -f2- | sha256sum
# fingerprint matched student-backend/student-beat/student-worker, not payments
```
Same confirmation for `PAYMENTS_WEBHOOK_SECRET` and `SCHOOLS_ADMIN_SECRET`
— in both cases `.env.staging` matched the majority side, confirming
`payments` and `schools-backend` (not the other side) were the ones stale.

## Root Cause
Two independent instances of the same underlying mechanism (a long-running
container that was never restarted after `.env.staging` was last updated,
so it kept whatever value it loaded at its own last startup) — one
affecting the beat/notifications containers, a second, separately-timed
one affecting `payments`/`schools-backend`. They were indistinguishable in
the first checker run only because of a coincidental value match, not
because they shared a cause.

## Prevention / Rule
No new guardrail needed — `scripts/check_runtime_secret_drift.py` (see
`HBEC-2026-09-23-staging-postgres-drift-4th-recurrence-guardrail-closed.md`
for the same-day extension that added `db_auth`) caught both instances
correctly; the second only needed a **second run after the first fix** to
become visible, which is worth calling out as a general lesson: a drift
checker's output right after a partial fix can still contain
coincidentally-matching stale values masking an unrelated second problem.
Always re-run after any fix, not just once.

## Solution

### Immediate Fix
```bash
docker compose -f docker-compose.staging.yml --env-file .env.staging \
  --profile workers up -d --force-recreate payments schools-backend
```

### Long-term Fix
None needed beyond the guardrail already in place. Worth checking whether
the same pattern exists on **production** — this pass only ran the
checker against staging.

## Verification
- `docker logs` on all 7 recreated containers (`admin-beat`,
  `student-beat`, `notifications`, `notifications-worker`,
  `notifications-beat`, `payments`, `schools-backend`): clean, no errors.
- `payments-staging`'s own `/health` endpoint: `{"status": "healthy",
  "database": "connected"}`.
- Final `scripts/check_runtime_secret_drift.py` run: **`Runtime secret
  drift check OK — 9 group(s) checked.`** — every group, including the two
  new `db_auth` ones, agrees.

## Prevention
- [x] Configuration changes needed — done (7 containers recreated)
- [x] Monitoring/alerts to add — n/a, the guardrail that caught this
  already exists
- [x] Documentation to update — this entry
- [ ] Code changes required — none; operational fix only. Production not
  yet checked (flagged above, not done in this pass).

## Related Issues
- `HBEC-2026-09-23-staging-postgres-drift-4th-recurrence-guardrail-closed.md`
  — found while verifying that entry's fix; the same session that added
  the `db_auth` check kind this entry's diagnosis also relied on.
- `HBEC-2026-09-16-runtime-secret-drift-had-no-detection-mechanism.md` —
  the guardrail that caught both instances of this.

## References
- `scripts/check_runtime_secret_drift.py`, `scripts/runtime_secrets.py`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — found, fixed, and re-verified twice
(once per independent instance)
