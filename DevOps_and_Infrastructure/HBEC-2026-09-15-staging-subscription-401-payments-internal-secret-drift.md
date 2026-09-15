# Staging `/api/subscription/` 401s for Every Student — `PAYMENTS_INTERNAL_SECRET` Drifted Between `hbec-student-backend-staging` and `hbec-payments-staging`

**Date:** 2026-09-15
**Project:** HBEC
**Environment:** Staging (`hbca-vps`, `/home/winstontino/HBEC`)
**Severity:** High (subscription page unusable for every staging user; masquerades as a student auth bug)
**Status:** Investigating (root cause identified and reproduced; no fix applied — investigation-only per task scope)

## Summary
The student frontend's Subscription page calls `GET /api/subscription/` on
`staging-student.hbca.tech` and gets a 401. The 401 has nothing to do with the
student's JWT or login state: `SubscriptionView`
(`STUDENT/hbec_backend/apps/accounts/views.py`) requires only
`IsAuthenticated`, and a request with a guaranteed-fresh, guaranteed-valid
token still 401s. The view is a pass-through proxy to an internal Payments
microservice (`hbec-payments-staging`), signing the outbound request with
`PAYMENTS_INTERNAL_SECRET` via
`STUDENT/hbec_backend/apps/accounts/payments_client.py::signature_headers`.
That env var has drifted between the two staging containers —
`hbec-student-backend-staging` signs with one value,
`hbec-payments-staging` verifies against a different one — so
`PAYMENTS/app/auth.py::verify_internal_request` rejects every call with
`401 {"detail":"Invalid internal signature"}`, and
`SubscriptionView.get()` proxies that status/body straight back to the
frontend verbatim (`return Response(response.json(), status=response.status_code)`),
which is indistinguishable from a real client-auth 401 to anyone reading the
frontend network tab or the student-backend access log.

## Symptoms
- Student frontend Subscription page fails to load; network tab shows
  `GET /api/subscription/` → `401 Unauthorized`.
- Other API calls in the same session work fine (ruling out a broadly broken
  student JWT/session).
- Student-backend's own log makes it look like the *inbound* request was
  unauthorized:
  ```
  WARNING ... "Unauthorized: /api/subscription/" {"status_code": 401, "request": "<ASGIRequest: GET '/api/subscription/'>"}
  ```
  — this is misleading. `IsAuthenticated` passed; Django's logging middleware
  is just reporting the final response status, which was set by re-proxying
  the downstream failure.

## Environment Details
- **Server/Host:** `hbca-vps`, staging stack (`hbec-student-backend-staging`,
  `hbec-payments-staging`)
- **Services Affected:** `hbec-student-backend-staging` →
  `hbec-payments-staging` internal call; user-visible as the Subscription page
- **Related Components:**
  `STUDENT/hbec_backend/apps/accounts/views.py::SubscriptionView`,
  `STUDENT/hbec_backend/apps/accounts/payments_client.py::signature_headers`,
  `PAYMENTS/app/auth.py::verify_internal_request`
- **Time First Observed:** 2026-09-15, reported by user as a live staging bug

## Investigation Steps

### 1. Initial Diagnosis
Traced the route: `config/urls.py` → `apps.accounts.subscription_urls` →
`SubscriptionView` (`permission_classes = [IsAuthenticated]`, standard
SimpleJWT). Nothing unusual in the auth class itself, so the JWT path was not
the first suspect once `IsAuthenticated` was confirmed to be the only gate.

### 2. Root Cause Analysis
Read `SubscriptionView.get()`: on `PAYMENTS_ENABLED=true` (the default) it
calls out to `PAYMENT_SERVICE_URL/v1/subscriptions/{user.id}` with HMAC
headers from `_payments_signature_headers()` → `payments_client.signature_headers()`,
which signs with `settings.PAYMENTS_INTERNAL_SECRET`. Any non-200 from that
call is returned to the client with the **same status code and body** the
Payments microservice returned — so a downstream 401 becomes a client-facing
401 with no indication it came from a service-to-service call.

Checked the shared secret on both staging containers:
```bash
docker exec hbec-student-backend-staging printenv PAYMENTS_INTERNAL_SECRET
# cb7f5ef4428adf596285750a5edf933f7a2f23e77f0d304f522bd1ef7e71637e
docker exec hbec-payments-staging printenv PAYMENTS_INTERNAL_SECRET
# hbec-payments-internal-dev-key
```
Different values — the HMAC signature `hbec-student-backend-staging` computes
can never match what `hbec-payments-staging` expects.

Confirmed via live logs (both sides of the call, same request):
```
# hbec-payments-staging
INFO: 172.27.0.15:xxxxx - "GET /v1/subscriptions/<uuid> HTTP/1.1" 401 Unauthorized

# hbec-student-backend-staging
{"message": "HTTP Request: GET http://payments:8000/v1/subscriptions/<uuid> \"HTTP/1.1 401 Unauthorized\""}
{"message": "Unauthorized: /api/subscription/", "context": {"status_code": 401, ...}}
```

### 3. Reproduction with a guaranteed-fresh, guaranteed-valid JWT
Minted a real access token for a real active staging user directly in the
container (bypassing the frontend/browser entirely) and hit the endpoint
directly:
```bash
docker exec hbec-student-backend-staging python manage.py shell -c \
  "AccessToken.for_user(<real active user>)"
curl -i https://staging-student.hbca.tech/api/subscription/ \
  -H "Authorization: Bearer <fresh token>"
# HTTP/2 401
# {"detail":"Invalid internal signature"}
```
The response body — `"Invalid internal signature"` — is the exact string
`PAYMENTS/app/auth.py::verify_internal_request` raises, proxied verbatim.
This proves the 401 is unrelated to the student's token: it fails identically
for a token that is provably fresh and valid, which rules out a frontend/
client-side bug (stale token, wrong header, missing refresh) entirely.

Also confirmed the frontend is not at fault by inspection:
`subscriptionService.getSubscription()`
(`STUDENT/Frontend/src/features/subscription/services/subscriptionService.ts`)
calls the same shared `apiFetch()` (`STUDENT/Frontend/src/lib/api.ts`) used by
every other working page, which attaches `Authorization: Bearer <token>` and
handles refresh identically — no bespoke auth logic on the subscription page.

### 4. Production comparison
```bash
docker exec hbec-student-backend printenv PAYMENTS_INTERNAL_SECRET
docker exec hbec-payments printenv PAYMENTS_INTERNAL_SECRET
# both: 4117f73dccb12280ddee1b49cdd0641f8d19d9eede534333d7abd60e38c58d65
```
Production's two containers agree on the secret, so the signature verifies
and this specific failure mode should not occur there. Also confirmed via
`git log`/`git merge-base` that `SubscriptionView` and the Payments-proxy code
were introduced in commit `8ddcf132` (2026-05-31) — an ancestor of the
production promotion range's start (`3a920b6f`, 2026-09-10) — so this is not
an unreleased feature: production has run this exact code path for months
without (as far as this investigation found) the same drift.

## Root Cause
`PAYMENTS_INTERNAL_SECRET` — the HMAC key that authenticates
service-to-service calls from Student Backend to the internal Payments
microservice — has a different value in `hbec-student-backend-staging` than
in `hbec-payments-staging`. Every signed call therefore fails Payments'
`verify_internal_request` check with a 401, and `SubscriptionView` forwards
that downstream 401 to the browser unchanged, which is indistinguishable from
a real end-user authentication failure without reading the proxy code and the
downstream service's own logs. This is an environment/secret provisioning
drift on staging, not a code bug — production's copies of the same variable
agree with each other.

## Prevention / Rule
**Guardrail:** Add a startup/health check (or a lightweight admin `manage.py`
command run as part of the staging deploy) that signs a canary payload with
`PAYMENTS_INTERNAL_SECRET` from the student-backend side and asserts
`hbec-payments-staging`'s `/health` (or a dedicated internal echo endpoint)
accepts it — failing the deploy loudly if the two services disagree, instead
of surfacing as a silent per-request 401 that looks like a client-auth bug.
Additionally, any service-to-service proxy view that forwards a downstream
non-2xx status/body verbatim (as `SubscriptionView` does) should at minimum
log which upstream produced the failure, so `Unauthorized: /api/subscription/`
in the student-backend log doesn't read as "this request's own auth failed"
when it was actually a downstream signature mismatch.

This closes the gap because the class of bug here is exactly "two
hand-maintained secrets that must match silently stopped matching" — a
same-request round-trip check at deploy time catches that before any student
hits it, and per-hop logging keeps the next occurrence (if the guardrail is
ever skipped) diagnosable in minutes instead of requiring container-log
correlation across two services.

## Solution

### Immediate Fix
None applied — this task was investigation-only. Root cause is identified and
reproduced; the actual fix (reconcile `PAYMENTS_INTERNAL_SECRET` between
`hbec-student-backend-staging` and `hbec-payments-staging`, presumably by
setting both to the same value in the hand-maintained `.env.staging`) is
handed off for a separate fix decision/action.

### Long-term Fix
Implement the pre-flight signature-agreement check described in the
guardrail above, and consider having `SubscriptionView` (and its sibling
payment proxy views) log the upstream service and status code on any non-200
response rather than silently re-emitting it.

## Prevention
- [ ] Configuration changes needed — reconcile `PAYMENTS_INTERNAL_SECRET`
      across `hbec-student-backend-staging` and `hbec-payments-staging`
      (not done — investigation only)
- [ ] Monitoring/alerts to add — alert on Payments-microservice 401 rate from
      internal callers
- [ ] Documentation to update — note in deployment docs that
      `PAYMENTS_INTERNAL_SECRET` must match exactly between the student
      backend and payments service, per environment
- [ ] Code changes required — per-hop error logging in the payment proxy
      views (see guardrail)

## Related Issues
- None yet filed for the specific fix; this entry documents the diagnosis
  that a follow-up fix should reference.

## References
- `STUDENT/hbec_backend/apps/accounts/views.py` (`SubscriptionView`, line ~1451)
- `STUDENT/hbec_backend/apps/accounts/payments_client.py` (`signature_headers`)
- `STUDENT/hbec_backend/apps/accounts/subscription_urls.py`
- `PAYMENTS/app/auth.py` (`verify_internal_request`)
- `STUDENT/Frontend/src/features/subscription/services/subscriptionService.ts`
- `STUDENT/Frontend/src/lib/api.ts` (`apiFetch`)
- Commit `8ddcf132` (2026-05-31) — introduced `SubscriptionView` and the
  Payments proxy, well before the current production promotion range

---

**Resolved By:** Claude Sonnet 5 (investigation only — not resolved)
**Time to Resolution:** N/A — root cause identified same session; fix pending
