# Production Skipped the Payment Wall for New Signups — 2-Day-Stale student-backend/payments Deploy

**Date:** 2026-09-24
**Project:** HBEC
**Environment:** Production
**Severity:** Critical — real revenue impact, new students getting full
product access with no subscription
**Status:** Resolved

## Summary
A newly-registered student account (`mupezeni22233@gmail.com`, created live
on production as a manual test) went straight from personalization to the
dashboard, never seeing the subscription/payment wall. The same signup
flow worked correctly on staging. Root cause: production's `student-backend`
and `payments` containers were running images built **2 days** before the
test (`2026-09-21T11:4x UTC`), while staging had been rebuilt as recently as
12–18 hours earlier — a gap opened by the same GitHub Actions billing
outage already affecting every other service this week, compounded here by
there being no visible symptom to prompt an ad-hoc manual rebuild the way
other services had received earlier in the same session.

## Symptoms
- User-reported: "after personalization it takes user straight into
  dashboard skipping the payment part."
- Confirmed reproducible on production; staging exhibited correct behavior
  for the same flow.

## Environment Details
- **Server/Host:** `hbca-vps`, production (`/opt/hbec`)
- **Services Affected:** `hbec-student-backend`, `hbec-payments`
- **Related Components:** `apps/accounts/views.py::SubscriptionView`
  (Django proxy to Payments), `PAYMENTS/app/api/subscriptions.py::get_subscription`,
  frontend `SubscriptionGate`/`useSubscription`
- **Time First Observed:** 2026-09-24, during a manual production signup test

## Investigation Steps

### 1. Initial Diagnosis
Traced the frontend flow first: `PersonalizationPage` → `navigate('/subscription')`
on completion, `/dashboard` correctly wrapped in `SubscriptionGate`, and
`useSubscription`/`subscriptionService` both fail closed on missing/malformed
data (`status: data.status ?? 'none'`, explicit comment: "never a permissive
default"). All matched current `master` and looked correct.

### 2. Root Cause Analysis
Queried the actual production DB directly for the test account:
```bash
docker exec hbec-student-backend python manage.py shell -c "
from apps.accounts.models import User, Subscription
u = User.objects.get(email__iexact='mupezeni22233@gmail.com')
print(u.role, u.auth_provider)
print(Subscription.objects.filter(user=u).first())
"
# role=student, auth_provider=email, NO local Subscription row
```
Confirmed no `UserReference`/`Subscription` existed in Payments' own DB for
this user either — by design, `StudentSignupView` never creates one for a
plain individual signup, and the fail-closed default (`is_active: False,
status: "none"`) should apply.

Generated a real JWT for the account and called the live endpoint directly,
bypassing the browser entirely:
```bash
curl https://student.hbca.tech/api/subscription/ -H "Authorization: Bearer <token>"
# {"isActive": false, "status": "none", ...}
```
This returned the **correct** answer even before any fix was applied — so
the bug was not in the specific check being read. Compared image ages
between environments:
```bash
docker images ghcr.io/rest-creator/hbec-student-backend --format '{{.Tag}}\t{{.CreatedAt}}'
# staging: 2026-09-23 18:15:17 UTC (~12h old)
# latest (prod): 2026-09-21 11:43:49 UTC (~2 days old)
docker images ghcr.io/rest-creator/hbec-payments --format '{{.Tag}}\t{{.CreatedAt}}'
# staging: 2026-09-23 12:33:51 UTC (~18h old)
# latest (prod): 2026-09-21 11:42:52 UTC (~2 days old)
```
`git log` for that window showed 15 commits touching `apps/accounts` and
`PAYMENTS/app` — the bulk of it the family-subscription-tier project
(`resolve_family_tier`, Payments `/resize`, plan-label fixes, account
self-conversion logging) — none of it ever deployed to production.

### 3. Key Findings
- The specific `/api/subscription/` response for a no-subscription user was
  already fail-closed correct on the *old* prod build — direct evidence
  the observed dashboard-skip was not fully explained by this endpoint
  alone.
- Production `student-backend`/`payments` were nonetheless genuinely 2 days
  behind staging — the largest gap found in this outage so far, because
  unlike the admin/student frontend fixes made earlier the same day, this
  backend work had no outwardly visible symptom to prompt a manual rebuild.
- After promoting the staging images to production (see Solution) and the
  user re-testing by clicking through the flow again, the payment wall
  correctly appeared. The precise mechanism connecting the stale backend to
  the transient bypass was not conclusively isolated beyond the version gap
  itself — the fix verified as working in practice is recorded here; if it
  recurs, check for a race between `PersonalizationPage`'s two competing
  `navigate()` calls (the `isOnboarded` effect vs. the submit handler) as a
  secondary suspect, since that code path is shared and wasn't separately
  ruled out.

## Root Cause
Production's `student-backend` and `payments` containers were running
images 2 days older than staging's, due to GitHub Actions' `Deploy`
workflow having failed on every run since `2026-09-21T06:25 UTC` (account
billing/spending-limit block — see related entries). Two days of real
backend changes accumulated on staging with no deploy path to production
and no alerting on the gap itself.

## Prevention / Rule
**Guardrail:** Add an automated check (cron or CI-independent) that
compares `org.opencontainers.image.revision` (or image creation timestamp,
until every image is properly labeled — several checked in this incident
had no revision label at all) between each service's staging and
production image, and alerts when the gap exceeds a threshold (e.g. 6
hours). This is distinct from the existing runtime-secret-drift guardrail —
it detects *code* drift between environments, not secret-value drift within
one.

This closes the actual gap here: nothing currently notices when production
silently falls behind staging by days, because the previous assumption was
that CI's `Deploy` job made this impossible. That assumption is false for
as long as the GitHub Actions billing block persists, and arguably should
never have been the *only* mechanism either.

## Solution

### Immediate Fix
```bash
# Tag staging's verified images with the current commit sha, no :latest mutation
docker tag ghcr.io/rest-creator/hbec-student-backend:staging ghcr.io/rest-creator/hbec-student-backend:sha-24afb1b5
docker tag ghcr.io/rest-creator/hbec-payments:staging ghcr.io/rest-creator/hbec-payments:sha-24afb1b5

cd /opt/hbec
docker compose -f docker-compose.production.yml up -d --force-recreate student-backend payments
```
Migration `accounts.0029_accountconversionlog` applied cleanly on
recreation. Verified `/api/subscription/` still correct, both services
healthy, no errors in logs. User re-tested the live signup flow and
confirmed the payment wall now appears correctly.

### Long-term Fix
- Resolve the GitHub Actions billing/spending-limit block so `Deploy` runs
  again — this is the actual fix; everything else here is a manual
  workaround for as long as it's broken.
- Add the staging/prod image-age guardrail described above so this class of
  gap is visible before a real user (or a manual test standing in for one)
  finds it.
- Ensure every image build stamps `org.opencontainers.image.revision` —
  several images inspected in this incident (`admin-frontend`,
  `student-backend`, `payments`, all `:staging` tags) had `unknown` for this
  label, forcing image-timestamp comparison as a weaker proxy for commit
  identity.

## Verification
- `docker ps`: both `hbec-student-backend` and `hbec-payments` healthy
  after recreation.
- `docker logs`: clean startup, migration applied, no errors on either
  service.
- Direct API call with a real token for the test account: correct
  `isActive: false` both before and after (see Key Findings).
- User re-tested the live signup → personalization → dashboard flow on
  production and confirmed the payment wall now appears.

## Prevention
- [x] Configuration changes needed — done (2 containers recreated,
  sha-pinned)
- [ ] Monitoring/alerts to add — the staging/prod image-age guardrail
  described above, not yet built
- [x] Documentation to update — this entry
- [ ] Code changes required — none identified yet; the exact mechanism
  connecting the stale build to the observed bypass was not fully isolated
  (see Key Findings) since the fix was verified by version promotion, not
  by finding a single line-level bug

## Related Issues
- `HBEC-2026-09-23-staging-beat-workers-holding-stale-secrets.md` and
  `HBEC-2026-09-23-staging-postgres-drift-4th-recurrence-guardrail-closed.md`
  — same-week infra drift, different mechanism (secrets/passwords rather
  than stale images)
- Same GitHub Actions billing outage also required manual promotion of
  `admin-frontend`, `admin-backend`, and `student-frontend` earlier the
  same day (undocumented as separate entries — routine redeploys of
  already-correct code, not bugs in themselves)

## References
- `docker-compose.production.yml`, `/opt/hbec/.env`
- `apps/accounts/views.py::SubscriptionView`,
  `PAYMENTS/app/api/subscriptions.py::get_subscription`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — diagnosed, promoted, and confirmed
fixed by user re-test within roughly 30 minutes
