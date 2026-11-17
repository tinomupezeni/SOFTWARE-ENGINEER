# Flutter showed a network failure as an empty paper

**Date:** 2026-11-05
**Project:** HBEC
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
When question fetch failed and the local cache was empty, ExamRepository returned an empty list. The practice page told the learner the paper had no questions, although the paper content had not loaded.

## Symptoms
- A network error appeared as a content-empty state.

## Environment Details
- **Server/Host:** Flutter client
- **Services Affected:** Exam Practice opening
- **Related Components:** exam_repository_impl.dart, practice_bloc.dart
- **Time First Observed:** 2026-11-05

## Investigation Steps
### 1. Initial Diagnosis
Compared repository fallback behavior with the web fetchQuestions failure path.
### 2. Root Cause Analysis
Tested a failing remote call with zero cached rows.
### 3. Key Findings
- Web throws load errors; Flutter previously returned [].

## Root Cause
The fallback collapsed network failure and genuine empty content into the same value.

## Prevention / Rule
**Guardrail:** Keep separate tests for successful empty content and failed fetch with empty cache. This preserves the error distinction.

## Solution
### Immediate Fix
The repository now throws a load error when remote fetch fails and no cache exists.
### Long-term Fix
Verify recovery on a device against a live API.

## Prevention
- [x] Code changes required
- [x] Documentation to update
- [ ] Monitoring/alerts to add

## Related Issues
- HBEC-2026-11-05-flutter-empty-questions-crash.md

## References
- STUDENT/mobile_flutter/test/features/exam/question_opening_test.dart

---

**Resolved By:** Codex
**Time to Resolution:** Same day
