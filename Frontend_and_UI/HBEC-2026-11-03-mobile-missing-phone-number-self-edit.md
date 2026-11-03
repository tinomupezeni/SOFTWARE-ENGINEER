# Students couldn't edit their own phone number from the mobile app

**Date:** 2026-11-03
**Project:** HBEC
**Environment:** Production
**Severity:** Low
**Status:** Resolved

## Summary
An admin (Mutsa) requested on 2026-10-29: "I think we also need to allow students to change number from the profile." Investigation found the web app (`STUDENT/Frontend`) already fully supported this — a `PhoneNumberCard` component at `/profile`, backed by the existing `PUT /api/auth/phone-number/` endpoint. The gap was entirely in the mobile app (`STUDENT/Mobile`), whose account-settings screen had no phone-number field at all. No backend change was needed; the endpoint, its validation, and its test coverage already existed.

## Symptoms
- A student using the mobile app had no way to view or edit their phone number anywhere in the app.
- The equivalent feature already worked correctly on web, so this was a platform-parity gap rather than a missing capability end to end.

## Environment Details
- **Server/Host:** HBEC STUDENT mobile app, STUDENT backend
- **Services Affected:** `STUDENT/Mobile`
- **Related Components:** `STUDENT/Mobile/src/screens/AccountSettingsScreen.tsx`, `STUDENT/Mobile/src/store/authStore.ts`, `STUDENT/hbec_backend/apps/accounts/views.py` (`PhoneNumberUpdateView`, unchanged)
- **Time First Observed:** 2026-10-29 (reported); investigated and fixed 2026-11-03

## Investigation Steps

### 1. Initial Diagnosis
Checked the web app first, since the admin's phone-number-in-admin feature (2026-10-27) implied the field itself already existed. Found `STUDENT/Frontend/src/features/settings/components/PhoneNumberCard.tsx` — a fully built, tested component already wired into the web settings page.

### 2. Root Cause Analysis
```bash
grep -n "phone" STUDENT/Mobile/src/screens/AccountSettingsScreen.tsx   # no hits
grep -n "PhoneNumberUpdateView" STUDENT/hbec_backend/apps/accounts/views.py
```
Confirmed the backend endpoint (`PUT /api/auth/phone-number/`, `PhoneNumberUpdateView`) was already generic and client-agnostic — it just needed a caller. The web app had one; the mobile app's `AccountSettingsScreen.tsx` simply never added a card for it.

### 3. Key Findings
- Backend: `phone_number` lives on `User` (`apps/accounts/models.py`), validated by a shared, deliberately loose `validate_phone_number_format()` (7-15 digits, no E.164/country-code enforcement, no uniqueness constraint — can be shared across siblings by design).
- `PhoneNumberUpdateView` is a dedicated endpoint separate from the general `/auth/me/` profile update specifically so callers don't need to also supply `firstName` on every save — already documented in its own docstring.
- Mobile's `MobileUserProfile` type (`authStore.ts`) didn't declare a `phoneNumber` field (though its index signature would have tolerated one at runtime).

## Root Cause
The mobile app's account-settings screen was never updated when the phone-number feature was added — a straightforward platform-parity gap, not a design or backend flaw.

## Prevention / Rule
**Guardrail:** When a profile-editable field is added to the student backend contract, add it to a short checklist in the PR description — "web settings page" and "mobile account-settings screen" both checked or explicitly marked N/A — so a mobile-only gap like this doesn't silently persist until a user or admin notices at a different layer entirely.

This directly targets the actual failure mode here: the backend and web were updated together, and mobile was simply forgotten, with nothing forcing a cross-platform check.

## Solution

### Immediate Fix
N/A — no incident, just a missing capability.

### Long-term Fix
- `STUDENT/Mobile/src/screens/AccountSettingsScreen.tsx`: added a "Phone number" card matching the screen's existing per-field-card convention, calling the same `PUT /auth/phone-number/` endpoint the web app uses (no new backend code).
- `STUDENT/Mobile/src/store/authStore.ts`: added `phoneNumber?: string | null` to `MobileUserProfile`.
- No backend changes — the endpoint, validation, and existing test coverage (`apps/accounts/tests/test_phone_number_prompt.py`) were already correct and untouched.
- Verified: `npm run typecheck` and `eslint` clean on both changed files. No test file was added for this screen, matching the screen's own established convention — no mobile screen in this app currently has component tests.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- None — first report of this platform gap.

## References
- `STUDENT/Mobile/src/screens/AccountSettingsScreen.tsx`
- `STUDENT/Mobile/src/store/authStore.ts`
- `STUDENT/Frontend/src/features/settings/components/PhoneNumberCard.tsx` (the web reference implementation)
- `STUDENT/hbec_backend/apps/accounts/views.py` (`PhoneNumberUpdateView`)

---

**Resolved By:** Claude (session with Tinotenda Mupezeni)
**Time to Resolution:** Same session as investigation
