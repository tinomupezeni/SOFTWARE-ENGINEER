# Personalization grade-change 500s when a grade code collides across exam boards

**Date:** 2026-09-10
**Project:** HBEC
**Environment:** Production
**Severity:** Critical
**Status:** Resolved

## Summary
`POST /api/auth/personalization/` on the student backend returned a 500
Internal Server Error whenever a student's chosen grade `code` existed under
more than one exam board (e.g. "form-4" under both ZIMSEC and a Cambridge
board) — an unscoped `Grade.objects.get(code=...)` raised
`MultipleObjectsReturned`, which nothing caught. Reported live in production
via a browser console error during pre-demo testing (PersonalizationPage
"grade change confirmation failed").

## Symptoms
- Frontend console: `POST https://student.hbca.tech/api/auth/personalization/
  500 (Internal Server Error)`, surfaced to the user as "Server error. Please
  try again later."
- Any real grade-change save on the student app was affected, not an edge
  case — this is the endpoint's default path (see Root Cause).

## Environment Details
- **Server/Host:** hbca-vps, `/opt/hbec` (production)
- **Services Affected:** `hbec-student-backend` (`apps.accounts`)
- **Related Components:** `apps.curriculum.Grade` (student-side replica),
  `apps.accounts.personalization_service.apply_personalization`
- **Time First Observed:** 2026-09-10, ~10:32 UTC, during investor-demo prep

## Investigation Steps

### 1. Initial Diagnosis
User pasted the browser console error showing a 500 on
`/api/auth/personalization/`.

### 2. Root Cause Analysis
Pulled the real traceback straight from production logs:
```bash
ssh hbca-vps "sudo docker logs hbec-student-backend --since 2h | grep -A 40 personalization"
```
Found:
```
apps.curriculum.models.Grade.MultipleObjectsReturned: get() returned more than one Grade -- it returned 2!
  File ".../apps/accounts/views.py", line 728, in post
    apply_personalization(...)
  File ".../apps/accounts/personalization_service.py", line 62, in apply_personalization
    grade_obj = Grade.objects.get(code=grade_code, is_active=True)
```

### 3. Key Findings
- `Grade.Meta.unique_together = [("exam_board", "code")]` — `code` alone
  (e.g. `"form-4"`) is only unique **per exam board**, by design (grades are
  scoped per board on both admin and student sides).
- `apply_personalization()`'s auto-derive-level-from-grade branch
  (`if not raw_level:`) did an **unscoped** `Grade.objects.get(code=...)`.
  This branch is not an edge case — the real frontend payload never sends
  `level` at all, so every genuine personalization save hits it.
- Every other Grade-by-code lookup in the codebase (e.g. the replication
  stream consumer, `apps/replication/stream_consumer.py`) already correctly
  scopes by `exam_board` — this one call site didn't.
- This is the same underlying data shape (multiple Grade rows sharing a
  `code` across different exam boards) investigated earlier this session for
  the admin dashboard's duplicate "Form 4" display — there it was correctly
  judged not a data bug (grades are legitimately scoped per board). This
  bug was a *consumer* of that same data failing to account for it.

## Root Cause
`apply_personalization()` in
`STUDENT/hbec_backend/apps/accounts/personalization_service.py` looked up
`Grade` by `code` alone, with no exam-board scope, so it raised
`Grade.MultipleObjectsReturned` (uncaught — only `Grade.DoesNotExist` was
handled) the moment two exam boards shared a grade code, which is the normal
case for this platform, not a rare one.

## Solution

### Immediate Fix
Scoped the lookup by `examBoardId` from the request payload, falling back to
the student profile's existing `exam_board`, and switched from `.get()` to
`.filter(...).first()` so an unresolved/ambiguous case degrades to "no level
change requested" (matching existing intentional behavior for a missing
Grade) instead of raising:
```python
exam_board_id = validated_data.get("examBoardId") or profile.exam_board_id
grade_qs = Grade.objects.filter(code=grade_code, is_active=True)
if exam_board_id:
    grade_qs = grade_qs.filter(exam_board_id=exam_board_id)
grade_obj = grade_qs.first()
raw_level = phase_to_level.get(grade_obj.phase, "zimsec_olevel") if grade_obj else ""
```
Added a regression test file,
`apps/accounts/tests/test_personalization_grade_code_collision.py`, with two
exam boards sharing a `"form-4"` grade code, covering: the exact crash
payload shape (no `level` field), correct disambiguation via `examBoardId`,
and the no-context fallback not crashing. Full `apps/accounts/` suite run
(191 passed, 1 pre-existing unrelated failure — see Related Issues).
Committed `3f7d1e21`, pushed to `master` (auto-deploys staging).

### Long-term Fix
None needed beyond the fix above — the scoping now matches the pattern
already used elsewhere in the codebase.

## Prevention
- [x] Code changes required — done
- [x] Test coverage added — done (3 new tests)
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — worth considering a Sentry/log alert on any
      unhandled `MultipleObjectsReturned` in production, since this class of
      bug (unscoped lookup against a per-board-unique field) could recur
      elsewhere.

## Related Issues
- Same root data shape as the earlier admin-dashboard "two Form 4s" display
  investigation this session (correctly judged not a data bug there).
- Full `apps/accounts/` suite run surfaced one unrelated pre-existing
  failure, `test_parent_signup_reports_which_child_failed`, already logged
  separately as
  `2026-09-10-parent-signup-error-flattening-keyerror.md` — not caused by
  this change.

## References
- `STUDENT/hbec_backend/apps/accounts/personalization_service.py`
- `STUDENT/hbec_backend/apps/accounts/views.py:728`
- `STUDENT/hbec_backend/apps/curriculum/models.py` (`Grade.Meta.unique_together`)

---

**Resolved By:** Claude (session with tinomupezeni)
**Time to Resolution:** ~20 minutes
