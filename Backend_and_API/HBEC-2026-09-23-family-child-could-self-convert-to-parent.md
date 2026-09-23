# A Family Child Could Self-Convert Into an Independent Parent Account

**Date:** 2026-09-23 (found and fixed, same session)
**Project:** HBEC
**Environment:** Staging — reported live by the user, who noticed "Convert
to Parent Account" was still present in Settings for a child account
**Severity:** Critical — would have silently detached a managed child from
their family, destroyed or forked their real data, and very likely locked
them out entirely with no way back
**Status:** Resolved

## Summary
`StudentSelfConversionView` (`POST /api/auth/convert-to-parent/`) and the
admin-initiated `ConvertStudentToParentView` both only checked
`user.role != User.Role.STUDENT` before proceeding. A family child is also
`role=STUDENT` (the only thing distinguishing them is a `FamilyMembership`
row where they're the child) — so nothing stopped a child from calling
either endpoint on themselves.

Both conversion paths in `RoleConversionService` unconditionally run
`FamilyMembership.objects.filter(user=user).delete()`, written on the
assumption that row (if it exists at all) is stale leftover state. For a
real family child it is their live link to the parent managing them.
Running either path against a child would have:
- **"Discard" action:** deleted their `StudentProfile` (real grade/mastery
  history), silently removed them from their family
  (`FamilyMembership.delete()`), and promoted them to an independent
  `PARENT` role.
- **"Transfer" action:** forked their real history onto a brand-new child
  user they now solely control, while the original account (them) became
  an independent parent.
- **Either way:** a family child's `User.password` is deliberately
  unusable — they authenticate via `FamilyMembership.child_password_hash`,
  never `User.password` at all (see the child-login architecture research
  earlier this session). After becoming "PARENT", there is no usable
  password on the account and no more `FamilyMembership` row to child-log
  back in through. The account would very likely have become permanently
  inaccessible.

## Symptoms
Not yet triggered — the user noticed the option was present on a child
account's Settings page ("Convert to Parent Account... Convert Account...")
and flagged it before clicking through, rather than reporting a broken
account after the fact.

## Investigation Steps

### 1. Initial Diagnosis
Read `StudentSelfConversionView.post()` — its only guard is `user.role !=
User.Role.STUDENT`, which a family child passes (children are `STUDENT`
role, not a distinct role).

### 2. Root Cause Analysis
Traced both `RoleConversionService` methods. Both already contain:
```python
# 3. Drop FamilyMembership where this user was a child
FamilyMembership.objects.filter(user=user).delete()
```
This line exists so a *stale* membership row doesn't linger after
conversion — it was never written with "what if the caller is currently a
*live*, parent-managed child" in mind, and nothing above it checked for
that case.

### 3. Key Findings
- Neither the self-service view nor the admin-initiated view distinguish
  "an independent student" from "a family child" — both are simply
  `role=STUDENT`. The only reliable signal is `FamilyMembership.objects
  .filter(user=user).exists()`.
- The frontend `ConvertAccountCard.tsx` on the Settings page has no
  awareness of this either — it renders unconditionally for any
  `role=STUDENT` user, child or not.
- A family child's unusable `User.password` (confirmed via the earlier
  child-login architecture research this session) means this bug had no
  safe failure mode — there was no path back into the account once
  converted.

## Root Cause
Both conversion entry points authorized on role alone (`STUDENT` vs
`PARENT`), when the real precondition for "may this account promote
itself" is "is this account independently owned" — which a family child,
despite being `role=STUDENT`, is not.

## Prevention / Rule
**Guardrail:** `RoleConversionService` now has a single shared check,
`_reject_if_family_child()`, called at the top of both public methods —
one place, so neither the self-service view nor the admin-initiated view
(nor any future caller) can bypass it by skipping a view-level check. Any
future write path that promotes or otherwise materially changes a
family-managed account should route through this service rather than
re-deriving the "is this account independently owned" condition itself.

## Solution

### Immediate Fix
`STUDENT/hbec_backend/apps/accounts/role_conversion_service.py`:
```python
def _reject_if_family_child(user: User) -> None:
    if FamilyMembership.objects.filter(user=user).exists():
        raise ValueError(
            "This account is managed by a parent and can't be converted "
            "independently. Ask the parent to remove it from the family "
            "first if it needs to become its own account."
        )
```
Called at the start of both `convert_student_to_parent` and
`convert_student_to_parent_and_transfer`, before either touches any state.

Also fixed a related false-alarm bug this surfaced: both
`StudentSelfConversionView` and `ConvertStudentToParentView` caught this
(and every other) `ValueError` with a bare `except Exception`, returning
500 — a legitimate, expected validation rejection would have paged
monitoring as a server fault. Both now catch `ValueError` first and return
400.

### Long-term Fix
None planned beyond the guardrail above — the frontend `ConvertAccountCard`
still renders unconditionally for a family child today; it will now
surface the backend's clear 400 message on attempt rather than crash or
succeed destructively, which is enough to prevent damage. Proactively
hiding the card for a family child (would need a new "is this account a
family child" flag threaded through login/profile responses) is a
nice-to-have, not filed as a follow-up here since nothing is broken without
it.

## Verification
- New tests: `FamilyChildCannotSelfConvertTests` (3 tests, self-service
  path — discard, transfer, and the real HTTP endpoint returning 400) and
  `ConvertStudentToParentViewFamilyChildRejectionTests` (1 test,
  admin-initiated path). All pass against a throwaway Postgres+Redis.
- Full Student backend suite: 818 passed, same 5 pre-existing unrelated
  `test_dropped_messages.py` failures as the rest of this session,
  unchanged.
- `ruff check` clean.
- Confirmed on staging beforehand that the reported account (a real
  transferred child) was still intact and had not yet been converted —
  the user flagged this before attempting it, not after.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a
- [x] Documentation to update — this entry
- [x] Code changes required — done, see Immediate Fix

## Related Issues
Surfaced in the same "Convert to Parent Account" feature thread as
`HBEC-2026-09-23-convert-to-parent-broken-by-wrong-familymembership-fields.md`
and
`HBEC-2026-09-23-admin-convert-to-parent-403-wrong-hmac-scheme.md` — the
third distinct bug found in this feature this session, and the only one of
the three that would have caused real, likely-unrecoverable damage to a
live account rather than just blocking the action.

## References
- `STUDENT/hbec_backend/apps/accounts/role_conversion_service.py`
- `STUDENT/hbec_backend/apps/accounts/conversion_views.py`
- `STUDENT/hbec_backend/apps/internal/views.py` (`ConvertStudentToParentView`)
- `STUDENT/hbec_backend/apps/accounts/tests/test_role_conversion_logging.py`
- `STUDENT/hbec_backend/apps/internal/tests/test_convert_student_to_parent_view.py`
- `STUDENT/Frontend/src/features/settings/components/ConvertAccountCard.tsx`
  (still unconditional — see Long-term Fix)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Found and fixed same session, 2026-09-23.
