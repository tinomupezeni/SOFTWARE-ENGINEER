# Flutter paper question request used a nonexistent child URL

**Date:** 2026-11-05
**Project:** HBEC
**Environment:** Development working tree
**Severity:** High
**Status:** Resolved

## Summary
The old Flutter request to /practice/papers/{id}/questions/ returned 404. Django and web use /practice/papers/{id}/ with data.questions.

## Symptoms
- The old Flutter request to /practice/papers/{id}/questions/ returned 404. Django and web use /practice/papers/{id}/ with data.questions.

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
- The old Flutter request to /practice/papers/{id}/questions/ returned 404. Django and web use /practice/papers/{id}/ with data.questions.

## Root Cause
The old Flutter request to /practice/papers/{id}/questions/ returned 404. Django and web use /practice/papers/{id}/ with data.questions.

## Prevention / Rule
**Guardrail:** Keep a focused contract or state test for this failure in the Flutter validation path. It checks the affected boundary before release.

## Solution
### Immediate Fix
Claude changed the endpoint in the working tree; Codex verified it against backend routes and added a Flutter datasource contract test.
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
