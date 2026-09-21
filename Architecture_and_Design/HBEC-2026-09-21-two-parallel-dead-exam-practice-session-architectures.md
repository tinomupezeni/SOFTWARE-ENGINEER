# Two Parallel Exam-Practice Session Architectures — One Is Entirely Dead

**Date:** 2026-09-21
**Project:** HBEC
**Environment:** Production
**Severity:** Medium (no student-facing breakage — the dead path is simply
never reached — but it explains a real, misleading analytics gap and
represents meaningful undetected architectural drift)
**Status:** Investigating — found and root-caused, not fixed (logged and
deferred; see Prevention / Rule)

## Summary
While investigating why 252 production signups showed almost no return
usage, found that `Paper.attempt_count` (a field surfaced to both the
admin and student frontends as "how many times has this paper been
attempted") is **always 0**, across all 767 papers, despite 28 real,
harness-marked attempts genuinely existing. Tracing why led to a bigger
finding: the student backend has **two separate, complete implementations
of "start a practice session," and only one of them is ever actually
used**. The other — `CreateSessionView`, the `Artifact` content model,
the local `PracticeSession`/`QuestionAttempt` models, and the
`MarkingResultView` internal callback — is fully wired, fully coded, and
completely disconnected from the live student experience.

## Symptoms
- Both admin and student UIs show "0 attempts" on every paper's stats,
  even ones students have genuinely completed and been marked on.
- No error, crash, or student-visible symptom — the dead path is never
  invoked by the current frontend at all, so nothing fails.

## Environment Details
- **Services Affected:** Student Backend (`apps/practice`, `apps/artifacts`,
  `apps/internal`)
- **Related Components:**
  - Live path (actually used): `GET /practice/papers/{id}/` (direct fetch)
    → harness `POST /api/v1/exam-practice/papers/{paper_id}/questions/{question_id}/submit`
    → result lands in the **harness's own** `attempts` table, never in
    anything on the student backend.
  - Dead path (fully built, never called by the frontend):
    `POST /api/practice/sessions/` (`CreateSessionView`) → looks up
    content via `ArtifactLookupService` against the `artifacts.Artifact`
    table → creates a `practice.PracticeSession` row → answers would land
    in `practice.QuestionAttempt` via `MarkingResultView`
    (`apps/internal/views.py`), an internal callback the harness would
    call with a `session_id` — but no `PracticeSession` a real student
    creates ever exists, because nothing in the live flow creates one.
- **Time First Observed:** 2026-09-21, while investigating the
  250-signups-low-retention issue

## Investigation Steps

### 1. Initial Diagnosis
`Paper.attempt_count`/`view_count` summed to 0/165 respectively across
every paper (`sum(Paper.objects.values_list('attempt_count', flat=True))`
== 0), despite the harness's own `attempts` table independently showing 28
real rows. The counter and the real activity live in two different places
that never talk to each other.

### 2. Root Cause Analysis
Grepped for every write site of `Paper.attempt_count` — none exist,
anywhere, only three read sites (`apps/practice/views.py`, all three
serializing it out to a frontend that never gets a non-zero value).
Traced the only plausible writer, `MarkingResultView`
(`apps/internal/views.py:333`), and found it requires a `PracticeSession`
row looked up by `session_id` — which is only ever created by
`CreateSessionView`. Confirmed via `grep` that the live frontend
(`STUDENT/Frontend/src/features/exam-practice/`) never calls
`POST /api/practice/sessions/` or references `artifactKey` in any code
path outside `src/features/offline/` — the offline-download feature is
the only real consumer of the `Artifact` system, and
`artifacts.Artifact.objects.count()` is 0 in production (see the
2026-09-21 dev-log entry on the marking `TypeError` investigation),
meaning even offline mode has never actually produced a downloadable
artifact.

### 3. Key Findings
- This is not a "forgot to increment a counter" bug — it's two complete,
  independently-coded implementations of the same feature, one of which
  the frontend stopped calling (or never started calling) at some point,
  with nothing removed and nothing that would have surfaced the drift —
  no error, no dead-code warning, both compile and run fine in isolation.
- `_execute_marking` (`app/exam_practice/router.py`, the harness) is the
  actual, live, working marking entry point students hit. Its result is
  written to the harness's own `attempts` table and never synced back to
  the student backend's `Paper.attempt_count` or `PracticeSession` at all
  — there may be no live callback wiring `attempt_count` even in
  principle right now, independent of the dead-`CreateSessionView`
  question.

## Root Cause
Two parallel "start a session" implementations exist in the student
backend. One (`CreateSessionView` → `Artifact` → `PracticeSession` →
`MarkingResultView`) was built for a precompute/artifact-based content
model that was apparently never fully wired up on the generation side
either (see the `apps/artifacts/tasks.py` placeholder content noted in
the same-day marking-crash investigation). The other (direct paper fetch
+ harness submit) is what actually ships. Nothing marks the first one as
deprecated, removes it, or wires its counters to the second, so
`attempt_count` silently reports "never used" forever regardless of real
activity.

## Prevention / Rule
**Guardrail:** none applied yet — this is a "found, not fixed" entry.
The right fix is a scoping decision, not a quick patch, and belongs to a
dedicated pass:
1. Decide whether `CreateSessionView`/`Artifact`/`PracticeSession`/
   `QuestionAttempt`/`MarkingResultView` are being kept for a real reason
   (the offline-download feature, which does use `Artifact` — see the
   2026-09-21 dev-log on `apps/artifacts/tasks.py`) or should be removed
   entirely if offline mode itself is also abandoned.
2. If kept: wire `Paper.attempt_count` to increment from the path that's
   actually live (the harness's marking completion, calling back to a
   student-backend endpoint keyed by `paper_id`/`question_id`, not
   `session_id`) — since `MarkingResultView` as it stands can never fire
   for a real student's session.
3. Either way, a dead-code detection pass (or simply grepping the live
   frontend for every backend route it actually calls, the technique
   used here) would have caught this without needing three months of
   silent drift to surface it.

## Solution

### Immediate Fix
None applied — this needs the scoping decision above before any code
changes, and is out of scope for the session this was found in (a
retention investigation). Flagged here rather than patched blind.

### Long-term Fix
See Prevention / Rule above.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a
- [ ] Documentation to update — `HBEC/CLAUDE.md`'s exam-practice section
      already documents the live marking path in detail; worth a note
      that `CreateSessionView`/`Artifact` is a *separate*, currently-dead
      (or offline-only) system, so a future reader doesn't assume it's
      the live one
- [ ] Code changes required — deferred pending the scoping decision above

## Related Issues
- Same-day dev-log entry on the `MarkingContext.grade` `TypeError` and the
  `apps/artifacts/tasks.py` placeholder-content finding — discovered in
  the same investigation, both point at the same underlying
  precompute/artifact system never having been finished.

## References
- `STUDENT/hbec_backend/apps/practice/views.py` (`CreateSessionView`,
  `attempt_count` read sites)
- `STUDENT/hbec_backend/apps/practice/models.py` (`Paper.attempt_count`,
  `PracticeSession`, `QuestionAttempt`)
- `STUDENT/hbec_backend/apps/artifacts/models.py`,
  `STUDENT/hbec_backend/apps/artifacts/tasks.py` (`Artifact`, the
  placeholder-content precompute pipeline)
- `STUDENT/hbec_backend/apps/internal/views.py` (`MarkingResultView`)
- `AGENTIC_HARNESS/app/exam_practice/router.py` (`_execute_marking`, the
  actual live marking path)
- `STUDENT/Frontend/src/features/exam-practice/` (confirmed: never calls
  `CreateSessionView`), `STUDENT/Frontend/src/features/offline/`
  (confirmed: the only real caller of `artifactKey`)

---

**Resolved By:** Claude Sonnet 5 (found only, not fixed)
**Time to Resolution:** N/A — deferred, needs a scoping decision first
