# Separate Admin Staff from Marketplace Clients

**Date:** 2026-10-15  
**Project:** Swap-O-Sell  
**Type:** Admin UX improvement  
**Status:** Completed

## Summary
Separated internal Django staff accounts from marketplace clients in the custom admin Users page. The API now returns explicit `clients` and `staff` groups, and the frontend renders each group with its own heading, description, count, and table.

## Context / Trigger
The Users page mixed the seeded `admin` account with marketplace users such as Tinotenda Mupezeni. This made the client list ambiguous and treated internal operational accounts as marketplace participants.

## Scope
Included the admin Users API response contract and Users page presentation. Authentication, staff authorization, user editing, and marketplace profile behavior were not changed.

## Method
Used Django's `is_staff` flag as the authoritative boundary. Non-staff accounts are returned as marketplace clients; staff accounts are returned as admin staff. The frontend consumes both groups and renders them separately.

## Decisions & Findings
- Staff separation is based on Django authorization state rather than the display `role` field.
- This keeps superusers and staff accounts out of customer-facing operational counts while preserving their admin visibility.
- Empty groups render an explicit empty state rather than disappearing.

## Changes Made
- Updated `GET /api/admin/users/` to return:
  - `clients`
  - `staff`
- Updated admin API typing.
- Replaced the mixed Users table with:
  - Marketplace clients
  - Admin staff
- Added group counts and explanatory subtitles.

## Verification
- Admin frontend typecheck passed.
- Admin frontend production build passed.
- Django system checks passed.
- Authenticated admin users endpoint returned one client (`Tinotenda Mupezeni`) and one staff account (`admin`).
- Admin container served successfully at `http://localhost:5174/`.
- `git diff --check` passed.

## Follow-ups / Deferred
- Add filters for verified sellers, inactive clients, and seller/buyer roles.
- Add staff audit information once admin actions become mutable.

## References
- `backend/modules/admin_api/views.py`
- `backend/modules/admin_api/serializers.py`
- `admin/src/main.tsx`
- `admin/src/api.ts`

---

**Completed By:** Copilot  
**Duration:** One implementation session
