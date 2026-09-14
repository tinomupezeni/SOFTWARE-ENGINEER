# New content-gap-reports endpoints returned 404 through both frontends' nginx

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Staging (production intentionally untouched)
**Severity:** High (new feature completely unreachable from either frontend, no error surfaced in the build)
**Status:** Resolved — verified live on staging

## Summary
The new `/api/v1/content-gap-reports` routes on the `NOTIFICATIONS`
service (student POST, admin GET summary/outstanding-count) were built,
tested, and deployed correctly, but were unreachable through either
frontend's nginx — every request 404'd — because nginx had no location
block matching that path at all.

## Symptoms
- `curl -X POST http://127.0.0.1/api/v1/content-gap-reports ...` from
  inside `hbec-student-frontend-staging` returned `404`, not the expected
  `401` (unauthenticated but correctly routed).
- Same `404` for `GET /api/v1/content-gap-reports/summary` and
  `/outstanding-count` from inside `hbec-admin-frontend-staging`.
- No error anywhere in the build/test pipeline — typecheck, lint, and the
  full test suites on both frontends and the backend all passed, because
  none of them exercise the real nginx routing layer.

## Environment Details
- **Services Affected:** `hbec-student-frontend-staging`,
  `hbec-admin-frontend-staging` (nginx routing only — the backend service
  itself, `hbec-notifications-backend-staging`, was working correctly the
  whole time)
- **Related Components:** `STUDENT/Frontend/nginx.conf`,
  `ADMIN/adminFrontend/nginx.conf`,
  `NOTIFICATIONS/app/notifications/router_content_gap.py`
- **Time First Observed:** immediately after deploying the content-gap-
  reports feature to staging, during manual endpoint verification
  (2026-09-14)

## Investigation Steps

### 1. Initial Diagnosis
Ran the same style of direct `curl` check used earlier in the session to
verify the original notifications routing — expected `401` (auth
rejection, proving the request reached the FastAPI service), got `404`
instead from all three new endpoints.

### 2. Root Cause Analysis
Both frontends' nginx configs had exactly one location block for the
notifications microservice: `location /api/v1/notifications { ... }`.
The new content-gap-reports router (`router_content_gap.py`) was
deliberately mounted in `app/main.py` as a **sibling** top-level path,
`/api/v1/content-gap-reports` — not nested under `/api/v1/notifications/`
— matching the build plan's own explicit scoping ("a genuinely separate
concern from `router_student.py`/`router_admin.py`"). nginx's prefix
matching only matches paths that literally start with
`/api/v1/notifications`, so `/api/v1/content-gap-reports` never matched
that block, fell through to the broader `/api/` block (the Django
backend), and 404'd there since Django has no such route either.

### 3. Key Findings
- This is the same underlying class of gap as the earlier
  trailing-slash redirect-loop bug found the same day (also nginx routing
  for this same service) — every time a new top-level path is added to
  the `NOTIFICATIONS` service, the two frontends' nginx configs need a
  matching new location block. Nothing enforces that pairing
  automatically.
- Every automated check in the build (backend pytest suite, both
  frontends' typecheck/lint/vitest) passed cleanly — none of them run
  against the real nginx layer, so this class of bug is invisible until
  an actual routed request is tested against a real deploy.

## Root Cause
A new backend route was added as a new top-level URL prefix without a
corresponding new nginx `location` block on either frontend — nginx has
no route for `/api/v1/content-gap-reports` at all, so it silently falls
through to an unrelated backend that correctly 404s it.

## Prevention / Rule
**Guardrail:** Whenever a new top-level route prefix is added to a
service that sits behind one of these frontends' nginx configs (i.e. a
prefix that isn't a sub-path of an already-routed prefix), the PR/change
must also add or extend a matching `location` block in both
`STUDENT/Frontend/nginx.conf` and `ADMIN/adminFrontend/nginx.conf`
(whichever ones actually call it). A lightweight version of this could
be enforced by `scripts/check_config_parity.py` (already checks
cross-service secret/hostname wiring) — extend it to parse each backend's
declared route prefixes (or a small manifest file) against both nginx
configs' `location` blocks and fail if a prefix has no match. Not
implemented here — flagged as the concrete mechanism that would catch
this automatically next time, since "add a new nginx block" is easy to
forget when the feature's own tests all pass.

## Solution

### Immediate Fix
Added a second `location /api/v1/content-gap-reports { ... }` block to
both `STUDENT/Frontend/nginx.conf` and `ADMIN/adminFrontend/nginx.conf`,
proxying to the same `notifications` service, matching the existing
block's exact style/timeouts/rate-limit convention. Rebuilt and
force-recreated `student-frontend`/`admin-frontend` on staging; confirmed
via `curl` from inside each container that all three endpoints now
return `401` (correct auth rejection) instead of `404`.

### Long-term Fix
The config-parity guardrail described above, whenever it's worth the
investment — not done in this session.

## Prevention
- [ ] Configuration changes needed — n/a (fixed directly)
- [ ] Monitoring/alerts to add — n/a
- [ ] Documentation to update — n/a
- [x] Code changes required — done
- [ ] `check_config_parity.py` extension for route-prefix coverage — not
      implemented, flagged as the real long-term fix

## Related Issues
- Same-day, same service: `HBEC-2026-09-14-notifications-stream-consumer-timeout.md`
  and the trailing-slash redirect loop fixed earlier the same session
  (both also nginx/infra gaps in this same new service's rollout).

## References
- `STUDENT/Frontend/nginx.conf`
- `ADMIN/adminFrontend/nginx.conf`
- `NOTIFICATIONS/app/notifications/router_content_gap.py`
- `NOTIFICATIONS/app/main.py`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session as discovery — caught during
post-deploy staging verification, fixed and redeployed within minutes.
