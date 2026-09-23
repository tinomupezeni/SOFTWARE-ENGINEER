# Convert-to-Parent-Account Feature 100% Broken — Wrong FamilyMembership Field Names

**Date:** 2026-09-23 (found and fixed, same session)
**Project:** HBEC
**Environment:** Production/Staging — the feature shipped in commit `acc0e117`
(and the self-service flow in `fb7b0e9c`, both already on `master`/staging)
**Severity:** Critical — every call to either conversion path threw
`FieldError` and returned a 500; the feature had never once succeeded
**Status:** Resolved

## Summary
Both entry points into student-to-parent account conversion —
self-service (`StudentSelfConversionView`) and admin-initiated
(`ConvertStudentToParentView`) — funnel through the single shared
`RoleConversionService`. Every code path through it that touches
`FamilyMembership` used field names that don't exist on that model
(`student`, `relationship`). This wasn't a partial regression: **the
conversion would fail unconditionally**, on the very first
`FamilyMembership.objects.filter(student=user)` call, before any of the
rest of the conversion logic ran.

Found while adding conversion logging (`AccountConversionLog`) — writing
real tests for the existing, already-shipped conversion code was what
surfaced this, not a user report.

## Symptoms
Not yet reported by an end user at time of writing, but guaranteed on
every attempt:
- Self-service "Convert to Parent Account" button → 500, both for
  "discard my data" and "transfer data to my child".
- Admin's "Convert to Parent" action on a student in Student Management →
  same 500, proxied back through `StudentBackendClient`.

## Investigation Steps

### 1. Initial Diagnosis
Writing `apps/accounts/tests/test_role_conversion_logging.py` against the
existing `RoleConversionService.convert_student_to_parent` /
`convert_student_to_parent_and_transfer`. The very first test run failed
before reaching any assertion.

### 2. Root Cause Analysis
```
django.core.exceptions.FieldError: Cannot resolve keyword 'student' into
field. Choices are: account_type, child_password_hash, created_at,
date_of_birth, first_name, id, parent, parent_id, record_version,
updated_at, user, user_id
```
`FamilyMembership` (`apps/accounts/models.py`) has never had a `student`
field or a `relationship` field. The real fields are `user` (the child),
`parent`, and `account_type`. `role_conversion_service.py` used:
```python
FamilyMembership.objects.filter(student=user)                        # x2
FamilyMembership.objects.create(
    parent=user.parent_profile, student=child_user, relationship="child"
)
```
all three calls reference fields that don't exist, so every call site
raises immediately.

### 3. Key Findings
- This is the *only* place in the codebase that used these wrong field
  names — every other `FamilyMembership` call site (`ParentSignupView`,
  `AddChildView`) already uses `user`/`parent`/`account_type` correctly, so
  the mistake didn't spread.
- `CELERY_TASK_ALWAYS_EAGER`-style "it ran in a test once so it must work"
  never applied here — there was no test at all for either conversion path
  until this session added one. A passing `pytest` run for the surrounding
  suite gave no signal, because nothing exercised this code.
- Both the self-service and admin-initiated flows share the one service
  function, so fixing it once fixes both entry points — confirmed by a
  research pass before touching anything, specifically to avoid patching
  one call site and leaving the other broken.

## Root Cause
The service was written against an imagined `FamilyMembership` shape
(`student`/`relationship`) rather than the model as it actually exists,
and shipped with no test that would have caught a `FieldError` on first
use — the discard path and the transfer path both hit it on their very
first `FamilyMembership` access.

## Prevention / Rule
**Guardrail:** any new write path against an existing Django model must
have at least one test that actually executes it against a real (or
in-memory/sqlite) DB before merge — a `FieldError` like this one raises on
first `.filter()`/`.create()` call, so a single smoke-level test per new
service method would have caught 100% of this before it ever reached
`master`. This is a specific instance of a broader gap: this repo doesn't
currently require "every new service method has an executing test" as a
review checklist item, and it should.

## Solution

### Immediate Fix
`STUDENT/hbec_backend/apps/accounts/role_conversion_service.py`:
```python
# before
FamilyMembership.objects.filter(student=user).delete()
...
FamilyMembership.objects.create(
    parent=user.parent_profile, student=child_user, relationship="child"
)

# after
FamilyMembership.objects.filter(user=user).delete()
...
FamilyMembership.objects.create(
    user=child_user,
    parent=user.parent_profile,
    account_type=StudentProfile.AccountType.CHILD,
    first_name=child_first_name,
)
```
`account_type=CHILD` matches every other place a child `FamilyMembership`
row is created (`ParentSignupView`, `AddChildView`) — this conversion path
now produces rows indistinguishable from ones created any other way.

### Long-term Fix
Added `apps/accounts/tests/test_role_conversion_logging.py` (7 tests)
covering both conversion paths end-to-end, including a regression guard
(`test_log_row_stays_attached_to_the_parent_not_reassigned_to_the_child`)
that asserts the created `FamilyMembership` row's real fields
(`user_id`, `account_type`) rather than the wrong ones this bug had.

## Verification
- All 7 new tests pass against a throwaway Postgres container
  (`config.settings.test`).
- Full Student backend suite: 810 passed, same 5 pre-existing unrelated
  failures as before this change (confirmed via `git stash` before/after).
- `ruff check` clean on the touched file.
- Not yet verified via a live click-through on staging — pending staging
  deploy of this fix.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — an admin-facing conversion log
  (`AccountConversionLog`, added in this same session) now makes a future
  silent failure of this kind visible after the fact, though it wouldn't
  by itself have caught this before staging.
- [x] Documentation to update — this entry
- [x] Code changes required — done, see Immediate Fix

## Related Issues
Found while building the "Convert to Parent Account" admin-visibility
feature (self-service conversion stays self-service; admin gets a
conversion log, parent-account count/filter, and a renewals report) —
not yet logged as its own report at time of writing.

## References
- `STUDENT/hbec_backend/apps/accounts/role_conversion_service.py`
- `STUDENT/hbec_backend/apps/accounts/models.py` (`FamilyMembership`)
- `STUDENT/hbec_backend/apps/accounts/tests/test_role_conversion_logging.py`
- Shipped (broken) in `acc0e117` (admin action) and `fb7b0e9c` (self-service)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Found and fixed same session, 2026-09-23.
