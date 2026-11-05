# Exam Practice listed subjects by syllabus code, not name

**Date:** 2026-11-05
**Project:** HBEC (STUDENT/mobile_flutter)
**Environment:** Staging (reported by the user testing against `staging-student.hbca.tech`)
**Severity:** Medium
**Status:** Resolved

## Summary
The Exam Practice screen's subject grid showed raw syllabus codes (e.g.
"4026") instead of subject names (e.g. "Additional Mathematics") for
subjects a student had added. The code→name lookup existed but was keyed
against the wrong source: the full cross-board, cross-level offline
curriculum catalog, instead of the personalization-options subjects list
the student's codes actually came from.

## Symptoms
- User report: "the subjects on the exam practice are being listed with
  subjects code and not the actual subject names."
- `_namesByCode[subjectCode] ?? subjectCode` was falling back to the raw
  code for at least some subjects.

## Environment Details
- **Server/Host:** `staging-student.hbca.tech`
- **Services Affected:** Flutter `ExamPracticePage` subject grid only.
- **Related Components:**
  `STUDENT/mobile_flutter/lib/features/exam/presentation/pages/exam_practice_page.dart`
- **Time First Observed:** 2026-11-05, live wireless-ADB test.

## Investigation Steps

### 1. Initial Diagnosis
Read `_loadSubjectNames()`: it builds `_namesByCode` purely from
`getIt.curriculumRepository.getSubjects()` — the `/offline/catalog/`
endpoint's full subject list, covering every board/level/syllabus-paper
variant in the system.

### 2. Root Cause Analysis
Pulled the live catalog response from the session log:
```
{"id":"01a08ac3-...","code":"0452","name":"Accounting","level":"zimsec_olevel",...}
{"id":"01a09ffe-...","code":"9706-5","name":"Accounting","level":"zimsec_olevel",...}
{"id":"5f6c332e-...","code":"6001","name":"Accounting","level":"zimsec_alevel",...}
```
The same subject name recurs under several different syllabus codes
(different boards/papers/levels all named "Accounting"). This is the full
syllabus catalog, not a per-student list — large, and not guaranteed to be
scoped the same way the student's own subject selection is.
Cross-checked against the personalization-options response (the actual
source of a student's `user.subjects` codes, confirmed by reading
`add_subject_sheet.dart`/`PersonalizationPage`, which both save whatever
`value` that endpoint offers):
```
{"value":"4026","label":"Additional Mathematics",...}
```
Same code *shape*, but a different, student-board/grade-scoped list — not
guaranteed to be a 1:1 match against whichever catalog entries actually
loaded into local storage first.

### 3. Key Findings
- The lookup wasn't wrong in concept (`code -> name` is the right idea) —
  it was keyed against the wrong list for this purpose. The catalog is
  the right source for syllabus/paper browsing; the personalization-options
  list is the right source for "what does the code the student picked
  actually mean," since that's the exact list the code came from.
- `name_sn`/`name_nd` in the catalog response are snake_case while the
  rest of that same object (`id`, `code`, `name`, `level`, `updatedAt`) is
  camelCase-or-bare — a minor backend inconsistency noted but not fixed
  here (out of scope: those fields aren't used by this screen, and this
  session does not touch backend code).

## Root Cause
Subject *names* for a student's own selected subjects were resolved
against the full curriculum catalog instead of the personalization-options
list that is the actual source of truth for what those subject codes mean
to that student.

## Prevention / Rule
**Guardrail:** None added this session — this is a "wrong data source for
the lookup" bug, not a shape a lint rule or schema check would catch.

[No automated guardrail added.]

## Solution

### Immediate Fix
Not applicable — client-only, no service was down.

### Long-term Fix
`_loadSubjectNames()` now also calls
`PersonalizationCubit.loadOptions(examBoard: user.examBoardId, grade:
user.grade)` (the same global cubit `AddSubjectSheet` already uses) and
merges its `subjects` list (`value -> label`) into `_namesByCode`,
layered on top of the existing catalog-based map so either source can
fill a gap the other misses.

## Prevention
- [ ] Configuration changes needed — N/A
- [ ] Monitoring/alerts to add — N/A
- [ ] Documentation to update — N/A
- [x] Code changes required — done, see Solution above.

## Related Issues
- Same session, same root pattern (a student-facing field resolved
  against the wrong source) as
  `HBEC-2026-11-05-flutter-add-subjects-empty-list.md` — both involve
  `PersonalizationCubit`'s options list being the correct source of truth
  that a different screen wasn't using correctly.

## References
- `STUDENT/mobile_flutter/lib/features/exam/presentation/pages/exam_practice_page.dart`
- `STUDENT/mobile_flutter/lib/features/auth/presentation/widgets/add_subject_sheet.dart`
- `STUDENT/mobile_flutter/lib/features/auth/presentation/bloc/personalization_cubit.dart`

---

**Resolved By:** tinomupezeni (with Claude Code)
**Time to Resolution:** <30 minutes
