# Massala Account Scope Investigation

**Date:** 2026-10-18
**Project:** TESC (ScalarEye)
**Type:** Audit / Bug Investigation / Tenant Scope
**Status:** Completed

## Summary

Investigated why staging rejected `massala.care@gmail.com` as an already-used
username even though the account was not visible in the main TESC user list.
The account exists as an institution-scoped ZCHPC user, not as a global/main
user. No data was modified.

## Context / Trigger

The main TESC user-management flow reported a duplicate username while the
administrator could not find the account in the main list.

## Scope

Included staging database identity, tenant scope, account metadata, serializer
validation, and the main user queryset. Excluded deletion, reassignment,
promotion, password reset, and production inspection.

## Method

Ran read-only Django ORM queries inside the staging backend container, checked
both email and username case-insensitively, inspected related institution/role/
department records, and reproduced serializer validation with the same
identifiers.

## Decisions & Findings

- User ID `224` owns both identifiers.
- The account belongs to institution `ZCHPC` (ID `21`).
- It is active but not staff or superuser and has no recorded login.
- The main list intentionally returns only users with `institution IS NULL` for
  a system administrator.
- Username and email uniqueness is global, so the hidden institution account
  still prevents a new main account.
- No mutation is safe until the intended outcome is clarified: use the
  existing institution account, change its email, or create a different main
  email.

## Changes Made

No TESC application files or staging data were changed. The finding and
prevention recommendation were recorded in the engineering repository.

## Verification

- Staging query found exactly one case-insensitive email match and one username
  match.
- Direct serializer validation reproduced both duplicate errors.
- Main queryset and model uniqueness behavior were confirmed from source.

## Follow-ups / Deferred

- Decide whether this user should remain institution-scoped or be promoted to a
  global/main account.
- Improve duplicate errors to identify an authorized owning scope.
- Add regression coverage for hidden cross-scope duplicates.

## References

- `Integrations_and_Auth/TESC-2026-10-18-institution-user-hidden-from-main-list.md`
- `backend/users/models.py`
- `backend/users/views/settings_views.py`

---

**Completed By:** Copilot
**Duration:** One investigation session
