# Flutter answer payload does not match Django submit contract

**Date:** 2026-11-05
**Project:** HBEC
**Environment:** Development working tree
**Severity:** High
**Status:** Investigating

## Summary
Flutter posts questionId and answerText without a session. Django requires sessionId, questionId and answer at /practice/attempts/submit/.

## Symptoms
- Flutter posts questionId and answerText without a session. Django requires sessionId, questionId and answer at /practice/attempts/submit/.

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
- Flutter posts questionId and answerText without a session. Django requires sessionId, questionId and answer at /practice/attempts/submit/.

## Root Cause
Flutter posts questionId and answerText without a session. Django requires sessionId, questionId and answer at /practice/attempts/submit/.

## Prevention / Rule
**Guardrail:** Keep a focused contract or state test for this failure in the Flutter validation path. It checks the affected boundary before release.

## Solution
### Immediate Fix
No fix in the question-opening slice; implement the chosen marking/session contract and test submission end to end.
### Long-term Fix
Verify the affected user journey on a device with a live backend.

## Prevention
- [ ] Code changes required
- [x] Documentation to update
- [ ] Monitoring/alerts to add

## Related Issues
- Other 2026-11-05 Flutter practice issue entries in this directory.

## References
- STUDENT/mobile_flutter/test/features/exam/question_opening_test.dart
- STUDENT/Frontend/src/features/exam-practice/api/examApi.ts
- STUDENT/hbec_backend/apps/practice/views.py

---

**Resolved By:** Pending
**Time to Resolution:** Pending
