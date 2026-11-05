# "Add Subjects" sheet pulled an empty subject list (and would have corrupted the saved grade)

**Date:** 2026-11-05
**Project:** HBEC (STUDENT/mobile_flutter)
**Environment:** Staging (reported by a live user testing the Flutter app against `staging-student.hbca.tech`)
**Severity:** High
**Status:** Resolved

## Summary
The Flutter app's "Add Subjects" bottom sheet (profile → add subjects)
showed no subjects to select, so a student could not add a subject to
their dashboard. Root cause: it sent the wrong field as the `grade` query
parameter to the personalization-options endpoint. The same wrong field
was also about to be saved back as the student's grade on every "Update
Subjects" tap — a silent data-corruption bug that happened to share one
root cause with the visible symptom.

## Symptoms
- User report: "failing to add subjects, users can't see subjects to be
  able to add new subjects... it's more like it's failing to pull the
  subjects."
- The sheet's subject checklist renders empty (or whatever a mismatched
  `grade` filter happens to return server-side) every time it's opened.

## Environment Details
- **Server/Host:** `staging-student.hbca.tech` (Flutter app, staging backend)
- **Services Affected:** Flutter mobile app only — the endpoint itself
  (`GET /auth/personalization-options/`) is shared with web and unaffected.
- **Related Components:**
  `STUDENT/mobile_flutter/lib/features/auth/presentation/widgets/add_subject_sheet.dart`,
  `STUDENT/mobile_flutter/lib/features/auth/domain/entities/user.dart`
- **Time First Observed:** 2026-11-05, live-tested by the user over wireless
  ADB against staging.

## Investigation Steps

### 1. Initial Diagnosis
Read `add_subject_sheet.dart`'s `initState`, which calls
`PersonalizationCubit.loadOptions(examBoard: board, grade: user?.level)`.

### 2. Root Cause Analysis
`User` (`lib/features/auth/domain/entities/user.dart`) documents its own
two grade-shaped fields explicitly:
```dart
final String? level;   // the broader phase bucket (e.g. "primary")
final String? grade;   // grade code (e.g. "grade-7") — distinct from `level`
```
In practice `level` actually holds the academic-level bucket (observed
live: `"zimsec_olevel"`), while `grade` holds the real grade code (observed
live: `"form-4"`). `getPersonalizationOptions(..., grade: grade)` sends
that value straight through as the `grade` query parameter with no
validation or correction — confirmed by reading
`auth_remote_datasource.dart`'s `getPersonalizationOptions`. The onboarding
flow (`personalization_page.dart`) calls the same `loadOptions` correctly,
passing the actual grade-option value the student picked
(`_answers['grade']`, e.g. `"form-4"`) — proving the API itself works fine
with a real grade code, and the bug was purely in which field
`add_subject_sheet.dart` read off `User`.

### 3. Key Findings
- The backend's subjects list for `grade=zimsec_olevel` almost certainly
  returns empty or wrong, since every real grade value seen from the live
  API (`grades: [...{"value":"form-4",...}]`) is a grade CODE, never an
  academic-level bucket.
- The exact same `user.level`/`user.grade` mix-up was *also* present in
  `_updateProfile`'s call to `savePersonalization(grade: user.level, ...)`
  — every "Update Subjects" save would have silently overwritten the
  student's real grade with the academic-level string. Caught by reading
  the whole file for the reported bug, not reported separately by the
  user — it shares the same root cause and fix.
- `examBoardId` (a UUID) being passed as `examBoard` is **not** a bug:
  `PersonalizationCubit.loadOptions` already resolves a UUID against the
  fetched `curricula` list's `id` field before using it, so that path was
  already correct.

## Root Cause
Two call sites read `User.level` where they meant `User.grade` — fields
the entity's own doc comments distinguish, but whose names are close
enough (`level` vs `grade`) that the wrong one compiles and type-checks
without any error.

## Prevention / Rule
**Guardrail:** None added this session — a lint/type-level guardrail for
"these two same-typed fields are easy to swap" is hard to express
mechanically (a distinct wrapper type per field would ripple through the
whole `User` model for two call sites). Recommending the practical
mitigation instead: when touching personalization-options or
save-personalization calls elsewhere in the app, grep for `user.level` and
`user.grade` together and check which one Each call site actually means
before trusting it compiles.

[No automated guardrail added — flagged as a recurring risk shape (two
same-typed, similarly-named fields on one entity) rather than a prevented
recurrence.]

## Solution

### Immediate Fix
Not applicable — client-side bug, no service was down.

### Long-term Fix
`add_subject_sheet.dart`: both call sites changed from `user.level` to
`user.grade`, with a comment at each explaining why (one broke the pull,
the other would have corrupted the save).

## Prevention
- [ ] Configuration changes needed — N/A
- [ ] Monitoring/alerts to add — N/A
- [x] Documentation to update — inline comments added at both fixed call
      sites naming the field mix-up explicitly, so a future edit doesn't
      reintroduce it without at least reading past the comment.
- [x] Code changes required — done, see Solution above.

## Related Issues
- Same root cause touches two symptoms (empty subject list on load, silent
  grade corruption on save) — both fixed in the same change, not two
  separate entries, since they share one root cause and one fix.

## References
- `STUDENT/mobile_flutter/lib/features/auth/presentation/widgets/add_subject_sheet.dart`
- `STUDENT/mobile_flutter/lib/features/auth/domain/entities/user.dart`
- `STUDENT/mobile_flutter/lib/features/auth/presentation/pages/personalization_page.dart`
  (the correct-usage reference that confirmed the API itself was fine)

---

**Resolved By:** tinomupezeni (with Claude Code)
**Time to Resolution:** <30 minutes
