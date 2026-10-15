# Seed Swap-O-Sell Admin Account

**Date:** 2026-10-15  
**Project:** Swap-O-Sell  
**Type:** Environment setup  
**Status:** Completed

## Summary
Seeded the requested Django staff administrator account for the Swap-O-Sell admin frontend and verified both JWT login and staff-only dashboard authorization.

## Context / Trigger
The new admin frontend needed a staff account so the dashboard could be used locally.

## Scope
Included creating or updating one Django user, enabling active/staff/superuser permissions, assigning the admin role, and verifying the authentication path. Credentials are intentionally not repeated in this record.

## Method
Used the running backend container's Django shell to idempotently find the requested email, set the account's password and staff flags, then exercised `/api/signin/` and `/api/admin/summary/`.

## Decisions & Findings
- The account uses the existing custom `swapapp.User` model.
- The operation is idempotent: rerunning it updates the same account rather than creating duplicates.
- The admin API correctly accepts the resulting JWT and returns dashboard metrics.

## Changes Made
- Created or updated the local database user with email `admin@swap.com`.
- Set `is_active`, `is_staff`, and `is_superuser` to enabled.
- Assigned the `admin` role.

## Verification
- Django shell reported the account was created.
- Login returned `success: true` with both access and refresh tokens.
- Authenticated `GET /api/admin/summary/` returned HTTP 200 and all expected summary keys.

## Follow-ups / Deferred
- Replace the development password before any shared or production deployment.
- Add an environment-specific bootstrap command or fixture if repeatable team setup is needed.

## References
- `backend/modules/auth/views.py`
- `backend/modules/admin_api/permissions.py`
- `admin/src/api.ts`

---

**Completed By:** Copilot  
**Duration:** One setup session
