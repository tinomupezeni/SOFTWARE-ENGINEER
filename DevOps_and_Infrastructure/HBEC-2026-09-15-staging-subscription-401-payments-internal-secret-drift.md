# Staging `/api/subscription/` 401s for Every Student — a Stray `.env` File Silently Wins Over `.env.staging` on Any `docker compose` Command That Omits `--env-file`

**Date:** 2026-09-15
**Project:** HBEC
**Environment:** Staging (`hbca-vps`, `/home/winstontino/HBEC`)
**Severity:** High (subscription page unusable for every staging user; masquerades as a student auth bug; the same mechanism silently drifted at least two other cross-service secrets)
**Status:** Resolved

**Update after the initial investigation-only pass:** the true root cause is
one level deeper than "the two secrets disagree" — see Root Cause below. The
actual fix has now been applied and verified live.

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

## Root Cause (deeper pass, after the fix)

The proximate cause is what the first pass found: `PAYMENTS_INTERNAL_SECRET`
disagreed between `hbec-student-backend-staging` and `hbec-payments-staging`.
But *why* it disagreed is the actual bug, and it's a live landmine, not a
one-off typo:

`/home/winstontino/HBEC/` has **two** env files that both look plausible:
`.env.staging` (the one `HBEC/CLAUDE.md` documents as staging's real
config — hand-maintained, correct) and a plain `.env` (last modified
2026-09-14, apparently accumulated from pasting together `docker exec ...
printenv`-style dumps from several unrelated running containers — it
contains base-image variables like `PG_VERSION`/`NGINX_VERSION`/
`GOSU_VERSION`, GPU/CUDA settings, and even **the same key defined twice
with two different values** in places, e.g. `PAYMENTS_INTERNAL_SECRET`
appears on two separate lines). `docker compose`, when invoked without an
explicit `--env-file`, **always loads `./.env` from the current directory
by default** — it has no awareness that `.env.staging` is the file this
project actually intends.

Every staging deploy command run earlier in this session used
`docker compose -f docker-compose.staging.yml build/up ...` **without**
`--env-file .env.staging`. That silently pulled every "unset in the shell,
required by compose" variable from the wrong file for any service
recreated by those commands — `hbec-student-backend-staging`,
`hbec-admin-backend-staging`, `hbec-notifications-backend-staging` +
worker + beat, and both frontends. Services *not* recreated during this
session (`hbec-payments-staging`, `hbec-harness-staging`,
`hbec-student-worker-staging`, `hbec-student-beat-staging`, etc.) kept
whatever they'd loaded from a previous, correct deploy. The 401 only
became visible where one side of a cross-service secret got silently
swapped out from under it while the other side didn't move — exactly the
same shape of bug as the harness stale-JWT-public-key incident logged
earlier today (`HBEC-2026-09-15-harness-jwt-public-key-stale-after-partial-promotion-restart.md`),
except here it's a compose env-file precedence gap instead of a
bind-mounted file's inode staying pinned.

**Confirmed blast radius was wider than just payments.** Before the fix,
comparing every shared secret across the fleet:
- `PAYMENTS_INTERNAL_SECRET`: `student-backend` (wrong file) vs `payments`
  (correct) — **mismatched**, this is the reported bug.
- `HARNESS_WEBHOOK_SECRET` (the one `apps/ai_gateway/services.py`'s
  `HarnessClient` actually signs student→harness calls with):
  `student-backend` (wrong file) vs `harness`'s own `WEBHOOK_SECRET`
  (correct) — **mismatched**, meaning the Friday AI companion / exam
  marking harness-gateway calls were also silently broken on staging,
  just not yet reported by anyone.
- `REPLICATION_HMAC_KEY`: `admin-backend` and `student-backend` were both
  recreated together in the same session from the same wrong file, so
  they happened to still agree *with each other* — not currently broken,
  but drifted from the documented value and one restart away from
  breaking replication the same way, the next time only one side moves.

Production is unaffected: `/opt/hbec`'s convention is a single `.env` file
(no separate `.env.production`/`.env.staging` split), so there is no
second, wrong file for `docker compose` to prefer there, and this
session's production promotion always passed `--env-file .env` explicitly
regardless.

## Prevention / Rule
**Guardrail:** Every staging `docker compose` invocation must pass
`--env-file .env.staging` explicitly — never rely on compose's default
`./.env` lookup in this directory, because a second, incorrect `.env` file
exists there and compose has no way to know it isn't the intended one. The
durable fix is to remove the ambiguity structurally: either delete/rename
the stray `.env` (once whatever produced it is identified and confirmed
unneeded) so there is only one file compose could possibly load, or add a
`COMPOSE_ENV_FILE=.env.staging` (or a project-level `docker-compose.staging.override.yml`
pattern) so the correct file is picked even when someone forgets the flag.
Until one of those lands, this is a standing personal rule for any future
session touching this VPS: **staging compose commands always need
`--env-file .env.staging`; production's `/opt/hbec` has no such ambiguity
since it only has one `.env`.**

Secondarily, the same guardrail from the first investigation pass still
applies: a service-to-service proxy view that forwards a downstream non-2xx
status/body verbatim (as `SubscriptionView` does) should at minimum log
which upstream produced the failure, so a downstream signature mismatch
doesn't read as "this request's own auth failed" in the student-backend log.

This closes the gap because the actual failure wasn't "two secrets need to
match" (they're supposed to, and normally do) — it was that a routine
redeploy command silently read configuration from the wrong file with no
error, no warning, and no indication anything was different until a student
hit a 401. Making the correct file explicit on every invocation removes the
ambiguity that let that happen at all.

## Solution

### Immediate Fix
Recreated every staging service this session had touched via the
env-file-ambiguous command, this time with the correct file:
```bash
cd /home/winstontino/HBEC
docker compose -f docker-compose.staging.yml --env-file .env.staging \
  up -d --wait --force-recreate \
  student-backend admin-backend notifications notifications-worker \
  notifications-beat admin-frontend student-frontend
```
Verified afterward that every previously-mismatched shared secret now
agrees across the fleet (`PAYMENTS_INTERNAL_SECRET`, `HARNESS_WEBHOOK_SECRET`,
`REPLICATION_HMAC_KEY` — checked via `docker exec <container> printenv <var>`
against each service's counterpart). Re-tested the original symptom with a
freshly minted, guaranteed-valid student JWT:
```
GET https://staging-student.hbca.tech/api/subscription/
→ HTTP 200 {"success":true,"data":{"status":"trial", ...}}
```

### Long-term Fix
Remove the structural ambiguity per the guardrail above (delete the stray
`.env` once confirmed safe, or pin `COMPOSE_ENV_FILE`), and add the
per-hop error logging to the payment proxy views as a secondary
improvement.

## Prevention
- [x] Configuration changes needed — done: all affected staging services
      recreated with the correct env file; secrets reconciled and verified
- [ ] Monitoring/alerts to add — alert on Payments-microservice 401 rate
      from internal callers; consider a deploy-time canary check that
      signs a payload with each shared secret and confirms the paired
      service accepts it
- [ ] Documentation to update — note in `docs/DEPLOYMENT.md` that every
      staging compose command must pass `--env-file .env.staging`
      explicitly, and that a stray `.env` exists in that directory that
      must not be relied upon or allowed to silently win
- [ ] Code changes required — per-hop error logging in the payment proxy
      views (see guardrail); structurally remove the stray `.env` or pin
      `COMPOSE_ENV_FILE`

## Related Issues
- `HBEC-2026-09-15-harness-jwt-public-key-stale-after-partial-promotion-restart.md`
  — same shape of bug (a partial restart exposes a pre-existing drift
  between two services that hadn't moved together in a while), different
  mechanism (bind-mounted file inode vs. compose env-file precedence).

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

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — diagnosed, root-caused to the actual
mechanism, and fixed within about 20 minutes of the user's report
