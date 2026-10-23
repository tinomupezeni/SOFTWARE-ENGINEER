# Institution Student Summary Served a Stale Frontend

**Date:** 2026-10-23
**Project:** TESC
**Environment:** Staging
**Severity:** Medium
**Status:** Resolved

## Summary
The staging institution database and API correctly contained 14 passed and 2
failed ZCHPC outcomes, but the public institution portal still served an older
frontend bundle that did not use the updated all-student summary contract.
Consequently the Student Statistics page continued to show zero for PASSED and
FAILED.

## Symptoms
- `/dashboard/graduates` showed 14 passed and 2 failed.
- `/dashboard/students` showed PASSED 0 and FAILED 0.
- The live institution bundle did not contain the `all-light` summary request.

## Environment Details
- **Server/Host:** `10.50.1.37`
- **Services Affected:** `frontend_admin` / institution portal
- **Related Components:** Vite institution bundle, Docker Compose image deployment
- **Time First Observed:** 2026-10-23

## Investigation Steps

### 1. Initial Diagnosis
Queried the staging ZCHPC records and invoked the live backend endpoint. The
database had 14 passing grades and 2 Fail grades, and `/all-light/` returned
both `graduation_year` and `final_grade`.

### 2. Root Cause Analysis
The running institution frontend image was older than the pulled staging
source. Its JavaScript bundle had no `all-light` reference, so the browser was
not executing the current summary implementation.

### 3. Key Findings
- ZCHPC total regular students: 190.
- ZCHPC passed outcomes: 14.
- ZCHPC failed outcomes: 2.
- Live backend response and business classification were correct.
- Rebuilding the institution image produced a bundle containing `all-light`.

## Root Cause
The image-only institution frontend was not rebuilt/recreated after staging
source updates, leaving the public portal on a stale artifact.

## Prevention / Rule
**Guardrail:** After every frontend promotion, verify the served asset hash and
required behavior marker against the intended source artifact before closing
the deployment.

This catches stale image/container routing before users see outdated metrics.

## Solution

### Immediate Fix
Built and recreated the Compose `frontend_admin` service from the current
staging source. The live institution asset now contains the `all-light`
summary path and the route returns HTTP 200.

### Long-term Fix
Use immutable frontend image tags and include served-bundle identity plus a
read-only user journey in deployment verification.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code/deployment changes required

## References
- `inst/src/pages/Students.tsx`
- `inst/src/services/students.services.ts`
- `backend/academic/app_views/student_views.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same session
