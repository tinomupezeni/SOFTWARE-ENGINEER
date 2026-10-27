# Admin Student/Parent API Missing phone_number Field

**Date:** 2026-10-27
**Project:** HBEC
**Environment:** Production
**Severity:** Medium (UI Missing Data)
**Status:** Resolved

## Summary
Parents/students can add a phone number via the app's phone-number prompt, but
the admin frontend had no way to see it — reported by Mutsa in the HBCA
ProjectFlow channel: "I see the pop up and I can add my number but there is
nowhere to access it in the admin side."

## Symptoms
- `User.phone_number` is populated on the student backend (collected via the
  phone-number prompt on student/parent accounts), but the admin's student/
  parent detail page showed no phone field at all.
- The internal `GET /api/internal/users/` and `/users/<id>/` endpoints (used
  by `StudentUserListView`/`StudentUserDetailView`) never serialized
  `phone_number`, so the Admin Backend's proxy and the Admin Frontend had
  nothing to display even though the field exists on the model.

## Root Cause
`StudentUserListSerializer.Meta.fields` (and `StudentUserDetailSerializer`,
which inherits from it) in
`STUDENT/hbec_backend/apps/internal/serializers.py` never listed
`phone_number`, even though the `User` model has carried that column since
migration `0013_add_phone_number`. The admin frontend's `StudentUser` type
and `normalizeStudent()` had no corresponding field to read either.

## Solution
1. Added `"phone_number"` to `StudentUserListSerializer.Meta.fields` in
   `STUDENT/hbec_backend/apps/internal/serializers.py` (inherited by the
   detail serializer, and applies to both student and parent role filters
   since both go through the same `User` model/endpoint).
2. Added `phoneNumber` to the `StudentUser` type and `normalizeStudent()` in
   `ADMIN/adminFrontend/src/features/student-management/{types,api}/`.
3. Rendered it on `StudentDetailPage.tsx`'s profile card, next to email
   ("Not provided" when empty).
4. Verified with `tsc --noEmit` and the existing `student-management` vitest
   suite (13 tests passing); backend serializer change has no test asserting
   an exact field list, so no test needed updating.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (internal serializer + admin frontend type/API/page)

---

**Resolved By:** Tinotenda Mupezeni (with Claude Code)
**Time to Resolution:** ~20 minutes
