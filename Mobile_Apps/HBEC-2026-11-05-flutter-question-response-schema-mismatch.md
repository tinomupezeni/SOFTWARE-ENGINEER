# Flutter parser rejected valid paper detail questions

**Date:** 2026-11-05
**Project:** HBEC
**Environment:** Development working tree
**Severity:** High
**Status:** Resolved

## Summary
Django returns numeric questionNumber, printed questionLabel and marks; generated Flutter parsing expected string questionNumber and totalMarks. A valid 200 response became an empty cache fallback.

## Symptoms
- Django returns numeric questionNumber, printed questionLabel and marks; generated Flutter parsing expected string questionNumber and totalMarks. A valid 200 response became an empty cache fallback.

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
- Django returns numeric questionNumber, printed questionLabel and marks; generated Flutter parsing expected string questionNumber and totalMarks. A valid 200 response became an empty cache fallback.

## Root Cause
Django returns numeric questionNumber, printed questionLabel and marks; generated Flutter parsing expected string questionNumber and totalMarks. A valid 200 response became an empty cache fallback.

## Prevention / Rule
**Guardrail:** Keep a focused contract or state test for this failure in the Flutter validation path. It checks the affected boundary before release.

## Solution
### Immediate Fix
Mapped backend fields, options, parts, metadata, and paper instructions; added parser tests and retained fetched questions if cache writes fail.
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
