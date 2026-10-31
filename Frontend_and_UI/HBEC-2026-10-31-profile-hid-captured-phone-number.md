# Student profile did not show or edit captured phone number

**Date:** 2026-10-31
**Project:** HBEC
**Environment:** Production (`student.hbca.tech`) and local development
**Severity:** Medium
**Status:** Investigating

## Summary
The student web app could capture a phone number through a global prompt, but `/profile` did not show the saved number or provide a direct way to add or edit it. A user who dismissed the prompt had no visible contact-number action on the profile page.

## Symptoms
- `/profile` displayed subscription, name, password, and learning-profile cards, but no phone field.
- The existing phone capture prompt could open over `/profile`, covering any profile content until dismissed.
- A saved number was present in the auth user payload but not displayed there.

## Environment Details
- **Server/Host:** `student.hbca.tech`
- **Services Affected:** Student web frontend profile; parent and student phone capture flows.
- **Related Components:** `SettingsPage`, `PhoneNumberPrompt`, auth and parent profile APIs.
- **Time First Observed:** User request on 2026-10-31.

## Investigation Steps

### 1. Initial Diagnosis
Traced `/profile` to `SettingsPage` and located the existing phone prompt and phone-save API.

### 2. Root Cause Analysis
`SettingsPage` rendered no phone component, although `useAuth().user.phoneNumber` and the parent profile API exposed stored numbers. The global prompt was mounted for every route.

```bash
rg -n 'path="/profile"|SubscriptionCard|PhoneNumberPrompt' STUDENT/Frontend/src/App.tsx STUDENT/Frontend/src/features/settings/pages/SettingsPage.tsx
```

### 3. Key Findings
- Students save through `PUT /api/auth/phone-number/`.
- Parents save through `PUT /api/parent/profile/`.
- The existing backend validation and auth state update can be reused.

## Root Cause
Phone collection was implemented only as a global modal, without a persistent profile surface that shows the saved value or guides someone who skipped the modal.

## Prevention / Rule
**Guardrail:** Every user contact field collected by a global prompt must also have a visible view and edit path on `/profile`, covered by a UI test for missing and saved values.

This prevents a captured value from becoming invisible or impossible to update after the prompt closes.

## Solution

### Immediate Fix
A prominent phone card has been added directly below Subscription on `/profile`; it uses the existing student and parent save actions. The global prompt yields on `/profile` so it cannot cover the card. Local tests and typecheck pass; production deployment is in progress.

```bash
cd STUDENT/Frontend
npm run test -- src/features/settings/components/PhoneNumberCard.test.tsx src/shared/components/__tests__/PhoneNumberPrompt.test.tsx
npm run typecheck
```

### Long-term Fix
Keep the card's missing, saved, edit, and parent states covered by focused UI tests.

## Prevention
- [x] Add profile view and edit path for the stored phone number.
- [x] Add focused UI coverage for student and parent behavior.
- [ ] Verify the deployed `/profile` path.

## Related Issues
- None recorded.

## References
- `STUDENT/Frontend/src/features/settings/components/PhoneNumberCard.tsx`
- `STUDENT/Frontend/src/features/settings/pages/SettingsPage.tsx`

---

**Resolved By:** Pending production verification
**Time to Resolution:** Ongoing
