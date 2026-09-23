# Admin-Initiated Convert-to-Parent Always 403s — Wrong Internal HMAC Scheme

**Date:** 2026-09-23 (found and fixed, same session)
**Project:** HBEC
**Environment:** Staging — reported live by the user while smoke-testing
the admin "Convert to Parent" action right after this session's staging
deploy
**Severity:** Critical — the admin-initiated conversion path had never once
succeeded; every attempt 403'd before any business logic ran
**Status:** Resolved

## Summary
`ConvertStudentToParentView` (`STUDENT/hbec_backend/apps/internal/views.py`,
`POST /api/internal/users/<id>/convert-to-parent/`) required
`InternalAuthMixin`'s `X-Harness-Signature` / `HARNESS_WEBHOOK_SECRET`
scheme — the one used for Agentic Harness → Student Backend calls. But the
caller here is Admin Backend's `StudentBackendClient`
(`ADMIN/adminBackend/apps/student_management/services.py`), which signs
every request with `X-HMAC-Signature` / `REPLICATION_HMAC_KEY` — the scheme
every other admin-facing view in the same file already uses
(`StudentUserListView`, `StudentUserStatsView`,
`AccountConversionLogListView`, all via `IsInternalService`). The two
schemes don't share a header name or a secret, so the check always failed.

Reported by the user as a browser console error while testing the feature
this session had just deployed to staging:
```
POST https://staging-admin.hbca.tech/api/students/<id>/convert-to-parent/
403 (Forbidden)
ApiError: Not permitted (403)
```

## Symptoms
- Admin clicks "Convert to Parent" on a student in Student Management →
  toast/console error, 403.
- This is distinct from the `FamilyMembership` field-name bug found and
  fixed earlier the same session
  (`HBEC-2026-09-23-convert-to-parent-broken-by-wrong-familymembership-fields.md`):
  that bug lived inside `RoleConversionService` and would 500 once the
  request reached it. This one never got that far — the request was
  rejected at the auth layer, before `RoleConversionService` or
  `FamilyMembership` were ever touched. Fixing the first bug alone did not
  fix the admin-initiated path at all.

## Investigation Steps

### 1. Initial Diagnosis
Admin Backend's own logs (`docker logs hbec-admin-backend-staging`) showed
the request reaching Admin Backend fine, passing its own `IsSuperAdmin`
check, then forwarding to Student Backend — which itself returned 403:
```
HTTP Request: POST http://student-backend:8000/api/internal/users/<id>/convert-to-parent/ "HTTP/1.1 403 Forbidden"
Forbidden: /api/students/<id>/convert-to-parent/
```
This ruled out an Admin-side permission problem (`IsSuperAdmin` passed) and
pointed at Student Backend's internal auth check specifically.

### 2. Root Cause Analysis
```python
# before
class ConvertStudentToParentView(InternalAuthMixin, APIView):
    permission_classes = [AllowAny]
    def post(self, request, user_id):
        auth_error = self.check_internal_auth(request)  # checks
        # X-Harness-Signature / HARNESS_WEBHOOK_SECRET
        ...

# StudentBackendClient (Admin Backend) actually sends:
# X-HMAC-Signature, signed with REPLICATION_HMAC_KEY
```
`verify_internal_signature` (the function `check_internal_auth` calls)
looks for `X-Harness-Signature`/`X-Harness-Timestamp` and verifies against
`HARNESS_WEBHOOK_SECRET` — a header pair and secret Admin Backend's client
never sends.

### 3. Key Findings
- Every sibling admin-facing view in the same file
  (`StudentUserListView`, `StudentUserStatsView`,
  `AccountConversionLogListView`) already uses `permission_classes =
  [IsInternalService]` (`apps.replication.permissions`), which checks the
  correct `X-HMAC-Signature`/`REPLICATION_HMAC_KEY` pair —
  `ConvertStudentToParentView` was the one outlier using the Harness scheme.
- No test exercised this view over real HTTP with the headers Admin
  Backend actually sends — the earlier session pass that added
  `AccountConversionLog` tested `RoleConversionService` directly (bypassing
  the view entirely) and the *self-service* HTTP endpoint (which uses
  Django session/JWT auth, not internal HMAC, so it couldn't have caught
  this). The admin-initiated HTTP path had no test at all until this fix.

## Root Cause
`ConvertStudentToParentView` was written against the wrong internal-auth
convention — copied from a Harness-calling view's pattern
(`InternalAuthMixin`) instead of the admin-calling pattern
(`IsInternalService`) every other view beside it in the same file already
established.

## Prevention / Rule
**Guardrail:** when adding a new `apps/internal/views.py` endpoint intended
for Admin Backend, use `permission_classes = [IsInternalService]` — never
`InternalAuthMixin`/`check_internal_auth`, which is reserved for
Harness-originated calls. A grep-based check (or a short comment block like
the one this fix added above the class) is cheaper than a runtime test
here, but the real guardrail is the one already applied to the regression
test added in this fix: **any new internal admin-facing view needs at
least one HTTP-level test signed the way `StudentBackendClient` actually
signs**, not just a test of the service function it calls.

## Solution

### Immediate Fix
`STUDENT/hbec_backend/apps/internal/views.py`:
```python
# before
class ConvertStudentToParentView(InternalAuthMixin, APIView):
    permission_classes = [AllowAny]
    def post(self, request, user_id):
        auth_error = self.check_internal_auth(request)
        if auth_error:
            return auth_error
        ...

# after
class ConvertStudentToParentView(APIView):
    permission_classes = [IsInternalService]
    def post(self, request, user_id):
        ...
```
`IsInternalService` was already imported module-level in this file (used
by the sibling views), so no new import was needed.

### Long-term Fix
Added `apps/internal/tests/test_convert_student_to_parent_view.py` (3
tests): a correctly-signed request succeeds and writes the expected
`AccountConversionLog` row; an unsigned or wrongly-signed request is
rejected (401, DRF's `NotAuthenticated` case for a failed `BasePermission`
with no authenticator — not 403, which is what the old, broken code
returned explicitly).

## Verification
- New test file: 3/3 passing.
- Full `apps/internal/` + `apps/accounts/` suites: 246/246 passing.
- Full Student backend suite: 813 passed, same 5 pre-existing unrelated
  `test_dropped_messages.py` failures as the rest of this session,
  unchanged.
- `ruff check` clean.
- Rebuilt and redeployed `student-backend` to staging; confirmed live via
  a direct signed request from inside the `admin-backend` container using
  the real `PaymentsServiceClient`-adjacent path (see Related Issues) —
  pending a final live click-through from the admin UI to close the loop.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a
- [x] Documentation to update — this entry
- [x] Code changes required — done, see Immediate Fix

## Related Issues
Second bug found in the same "Convert to Parent Account" admin-visibility
feature this session, after
`HBEC-2026-09-23-convert-to-parent-broken-by-wrong-familymembership-fields.md`.
Both bugs together meant the admin-initiated conversion path had never
once worked end-to-end since it shipped (`acc0e117`, `fb7b0e9c`), for two
independent reasons stacked on top of each other.

## References
- `STUDENT/hbec_backend/apps/internal/views.py` (`ConvertStudentToParentView`)
- `STUDENT/hbec_backend/apps/replication/permissions.py` (`IsInternalService`)
- `ADMIN/adminBackend/apps/student_management/services.py` (`StudentBackendClient`)
- `STUDENT/hbec_backend/apps/internal/tests/test_convert_student_to_parent_view.py`
- Shipped (broken) in `acc0e117` / `fb7b0e9c`; reported live 2026-09-23 by
  the user testing this session's staging deploy.

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Found and fixed same session, 2026-09-23.
