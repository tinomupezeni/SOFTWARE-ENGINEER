# Adding last-login visibility to admin users

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** Admin UI Enhancement
**Status:** Completed

## Summary
The admin Users page now shows when each marketplace client or staff member last logged in. The value is sourced from Django's authoritative `last_login` field and displays `Never` when an account has not authenticated.

## Context / Trigger
The Marketplace clients table showed identity, role, location, trust, and joined date, but did not provide account-activity visibility. The requested enhancement was to add a last-logged-in value.

## Scope
Included the admin API serializer, TypeScript contract, and shared users table for both marketplace clients and admin staff. No authentication behavior or last-login mutation logic was changed.

## Method
Inspected the custom Django user model inheritance and admin API response, then wired the existing Django `last_login` field through the serializer and rendered it in the existing reusable table.

## Decisions & Findings
- Django's `last_login` is nullable and is the correct source for authentication activity.
- Dates are formatted with the browser locale to match the existing Joined column.
- Accounts with no successful login display `Never`.
- The same column appears in both Marketplace clients and Admin staff sections for consistent account visibility.

## Changes Made
- Added `last_login` to `AdminUserSerializer`.
- Added `last_login: string | null` to the admin frontend type.
- Added the `Last logged in` table column and fallback label.

## Verification
- Admin TypeScript typecheck passed.
- Admin production build passed.
- Django system check passed inside the backend container.
- Git diff whitespace validation passed.

## Follow-ups / Deferred
Time-of-day display and activity filters are deferred; the current table uses locale-formatted dates consistent with Joined.

## References
- `backend/modules/admin_api/serializers.py`
- `admin/src/api.ts`
- `admin/src/main.tsx`

---

**Completed By:** Copilot
**Duration:** Same session
