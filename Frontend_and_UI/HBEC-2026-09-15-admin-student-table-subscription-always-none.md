# Admin Student Table Always Showed "None" for Subscription — Field Was Fully Populated by the Backend but Silently Dropped in Frontend Normalization

**Date:** 2026-09-15
**Project:** HBEC
**Environment:** Development / Staging (`ADMIN/adminFrontend`)
**Severity:** Medium (no data loss, but every student's subscription state was invisible to admins)
**Status:** Resolved

## Summary
The admin's student management table has a "Subscription" column with fully
correct rendering logic — a colored badge for `trial`/`active`/`expired`,
plus a detail line — but it displayed "None" for every single student,
with no exceptions. The backend chain (Student Backend's `Subscription`
model → `StudentUserListSerializer.get_subscription()` → the internal
`/api/internal/users/` endpoint → Admin Backend's pass-through
`StudentListView`) was already fully wired and returning a correctly
populated `subscription` object per student. The break was entirely in the
Admin Frontend: `studentApi.ts`'s `normalizeStudent()` function remaps the
raw API response field-by-field into camelCase, and simply never copied
`raw.subscription` through — so `student.subscription` was `undefined` for
every row, regardless of what the API actually sent, and the table's
`None` fallback fired unconditionally.

## Symptoms
- Every row in the admin student table's Subscription column read "None,"
  including for students known to have an active trial or a genuinely
  expired subscription.
- No error, no console warning — a silent normalization drop, not a
  request failure, so nothing about the symptom pointed at the network
  layer.

## Environment Details
- **Services Affected:** `ADMIN/adminFrontend` only — no backend data was
  wrong or missing
- **Related Components:**
  `ADMIN/adminFrontend/src/features/student-management/api/studentApi.ts`
  (`normalizeStudent`),
  `ADMIN/adminFrontend/src/features/student-management/components/StudentTable.tsx`,
  `STUDENT/hbec_backend/apps/internal/serializers.py`
  (`StudentUserListSerializer.get_subscription`)
- **Time First Observed:** 2026-09-15, reported directly by the user

## Investigation Steps

### 1. Initial Diagnosis
Traced the column's render branch in `StudentTable.tsx`: it already
branches correctly on `student.subscription` (badge colored by `status`,
detail text for days remaining/expired) and only falls to "None" when that
field is falsy — so the rendering logic itself was not the bug.

### 2. Root Cause Analysis
Followed the data backward: `getStudents()` in `studentApi.ts` maps every
raw API item through `normalizeStudent()`. That function builds the
`StudentUser` object key-by-key — id, email, name, isActive, role,
dateJoined, lastLogin, authProvider, profile, username — but never
included `subscription` in the object it returns. Confirmed the backend
side was correct by calling the internal endpoint directly from the
Admin Backend's own `StudentBackendClient` in a Django shell on staging:
every student with a `Subscription` row returned a fully populated object
(`{status, plan_type, trial_ends_at, current_period_end, is_active,
days_remaining}`); only a system account with no `Subscription` row at all
correctly returned `None`.

### 3. Key Findings
- The `StudentSubscription` TypeScript type (in `types/index.ts`) already
  matched the backend payload's field names exactly — this was a pure
  wiring omission, not a schema mismatch.
- A second, independent inconsistency was found in `StudentCard.tsx` (the
  card-view equivalent of the table): once the `normalizeStudent()` fix
  made `subscription` available, that component's own badge would have
  worked, but it hand-rendered the status label (`Sub: Active`) instead of
  the table's "Free Trial"/"Active"/"Expired" labels, and had no
  days-remaining/days-ago detail text at all — extracted both components'
  logic into a shared `utils/subscriptionDisplay.ts` so they render
  identically.
- While implementing the requested "Expired N days ago" display, found
  that the existing `days_remaining` model property floors to `0` for an
  expired subscription and therefore cannot express "how long ago" —
  added a new `days_since_expired` property alongside it (None unless
  `status == EXPIRED`, counts from whichever date last governed access:
  `current_period_end` if the subscription had gone active, otherwise
  `trial_ends_at` for a trial that lapsed without ever activating).

## Root Cause
`normalizeStudent()` in `ADMIN/adminFrontend/src/features/student-management/api/studentApi.ts`
remapped every field from the raw API response except `subscription`,
which was omitted from the object it constructs — an omission, not a
transformation bug, so the already-correct backend data and the
already-correct table rendering logic never actually connected.

## Prevention / Rule
**Guardrail:** Any "normalize raw API response" function that builds its
return object key-by-key (rather than spreading unknown fields through) is
a place a field can be silently dropped with no type error, because
`StudentUser`'s optional `subscription?` field made the omission
type-valid. Prefer a normalization pattern that starts from `{ ...raw }`
and only overrides the fields that actually need remapping, so a new or
forgotten field surfaces as extra (harmless) data rather than silently
vanishing — or, short of restructuring the existing pattern, add a
component test asserting the full shape of `normalizeStudent()`'s output
against a realistic raw fixture, so a missing field fails a test instead
of only being visible by eyeballing production data.

## Solution

### Immediate Fix
```ts
// studentApi.ts, normalizeStudent()
subscription: (raw.subscription || null) as StudentUser['subscription'],
```
Plus the new `days_since_expired` model property
(`STUDENT/hbec_backend/apps/accounts/models.py`) and its serializer
exposure (`apps/internal/serializers.py`), and the shared
`subscriptionDisplay.ts` util consumed by both `StudentTable.tsx` and
`StudentCard.tsx`.

### Long-term Fix
None needed beyond the guardrail above — this was a single omitted field,
not a structural problem in the proxy chain.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a, purely a display bug
- [ ] Documentation to update — n/a
- [x] Code changes required — done

## Related Issues
- None yet filed.

## References
- `ADMIN/adminFrontend/src/features/student-management/api/studentApi.ts`
- `ADMIN/adminFrontend/src/features/student-management/components/StudentTable.tsx`
- `ADMIN/adminFrontend/src/features/student-management/components/StudentCard.tsx`
- `ADMIN/adminFrontend/src/features/student-management/utils/subscriptionDisplay.ts`
- `STUDENT/hbec_backend/apps/accounts/models.py` — `Subscription.days_since_expired`
- `STUDENT/hbec_backend/apps/internal/serializers.py` — `StudentUserListSerializer.get_subscription`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session, diagnosed and fixed within the hour
