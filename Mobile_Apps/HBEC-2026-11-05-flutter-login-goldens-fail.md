# Flutter login golden baselines fail

**Date:** 2026-11-05
**Project:** HBEC
**Environment:** Development working tree
**Severity:** Low
**Status:** Investigating

## Summary
Full flutter test --no-pub fails both login golden variants by about 11.7 percent. Login UI and baselines were already modified before this session.

## Symptoms
- Full flutter test --no-pub fails both login golden variants by about 11.7 percent. Login UI and baselines were already modified before this session.

## Environment Details
- **Server/Host:** Flutter client and local test environment
- **Services Affected:** Visual regression gate
- **Related Components:** STUDENT/mobile_flutter; STUDENT/hbec_backend/apps/practice
- **Time First Observed:** 2026-11-05

## Investigation Steps
### 1. Initial Diagnosis
Traced the Flutter question-opening flow and compared it with the web client.
### 2. Root Cause Analysis
Read Django routes/views, Flutter models/bloc/page, and ran focused tests.
### 3. Key Findings
- Full flutter test --no-pub fails both login golden variants by about 11.7 percent. Login UI and baselines were already modified before this session.

## Root Cause
Full flutter test --no-pub fails both login golden variants by about 11.7 percent. Login UI and baselines were already modified before this session.

## Prevention / Rule
**Guardrail:** Keep a focused contract or state test for this failure in the Flutter validation path. It checks the affected boundary before release.

## Solution
### Immediate Fix
No fix in the question-opening slice; review failure images against intended design, then reconcile UI and baselines.
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
