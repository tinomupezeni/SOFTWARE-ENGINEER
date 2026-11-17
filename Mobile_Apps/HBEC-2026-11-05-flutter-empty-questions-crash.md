# Empty question list crashed Flutter practice screen

**Date:** 2026-11-05
**Project:** HBEC
**Environment:** Development working tree
**Severity:** High
**Status:** Resolved

## Summary
PracticeBloc emitted PracticeInProgress for zero questions and the page accessed questions[0], yielding RangeError and a black error surface.

## Symptoms
- PracticeBloc emitted PracticeInProgress for zero questions and the page accessed questions[0], yielding RangeError and a black error surface.

## Environment Details
- **Server/Host:** Flutter client and local test environment
- **Services Affected:** Exam Practice
- **Related Components:** STUDENT/mobile_flutter; STUDENT/hbec_backend/apps/practice
- **Time First Observed:** 2026-11-05

## Investigation Steps
### 1. Initial Diagnosis
Traced the Flutter question-opening flow and compared it with the web client.
### 2. Root Cause Analysis
Read Django routes/views, Flutter models/bloc/page, and ran focused tests.
### 3. Key Findings
- PracticeBloc emitted PracticeInProgress for zero questions and the page accessed questions[0], yielding RangeError and a black error surface.

## Root Cause
PracticeBloc emitted PracticeInProgress for zero questions and the page accessed questions[0], yielding RangeError and a black error surface.

## Prevention / Rule
**Guardrail:** Keep a focused contract or state test for this failure in the Flutter validation path. It checks the affected boundary before release.

## Solution
### Immediate Fix
Bloc now emits a visible no-questions error with a back action; added state and widget tests.
### Long-term Fix
Verify the affected user journey on a device with a live backend.

## Prevention
- [x] Code changes required
- [x] Documentation to update
- [ ] Monitoring/alerts to add

## Related Issues
- Other 2026-11-05 Flutter practice issue entries in this directory.

## References
- STUDENT/mobile_flutter/test/features/exam/question_opening_test.dart
- STUDENT/Frontend/src/features/exam-practice/api/examApi.ts
- STUDENT/hbec_backend/apps/practice/views.py

---

**Resolved By:** Codex / Claude as noted above
**Time to Resolution:** Same day
