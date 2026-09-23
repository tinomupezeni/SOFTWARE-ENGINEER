# Convert Student to Parent Feature Implementation

**Date:** 2026-09-23
**Project:** HBEC
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
The system needed the ability for administrators to convert a student account into a parent account. The main challenge was orchestrating the transition across different microservices (Student Backend, Payments Backend, and Admin Backend) while ensuring that no orphaned artifacts break the frontend.

## Symptoms
- Previously, there was no administrative action to handle this case; a student who wanted to become a parent had to either create a new account with a different email or have an admin manually edit the database rows directly.

## Environment Details
- **Server/Host:** HBEC Dev Environment
- **Services Affected:** `STUDENT/hbec_backend`, `ADMIN/adminBackend`, `ADMIN/adminFrontend`
- **Related Components:** User Profiles, PaymentsClient, StudentBackendClient
- **Time First Observed:** 2026-09-23

## Investigation Steps

### 1. Initial Diagnosis
- Used a subagent to map out the roles and database rows affected by switching a role.
- Determined that `StudentProfile` needs to be deleted, `ParentProfile` needs to be created, and `FamilyMembership` entries where the user is a child must be cleared.

### 2. Root Cause Analysis
- The legacy internal API (`StudentUserDetailView`) was strictly filtering `role=User.Role.STUDENT`, preventing an in-place edit of the role field.

### 3. Key Findings
- Changing a role triggers a billing implication: a parent with 0 children must be placed onto the base Individual plan in the Payments service.
- The `_resize_family_plan` utility exists in `apps/accounts/parent_views.py` and handles the safe synchronous notification to the Payments service.

## Root Cause
N/A - Feature Implementation.

## Prevention / Rule
**Guardrail:** Use explicit `RoleConversionService` layers for cross-domain role swaps rather than raw Django `update()` queries.

Using a service layer ensures that side-effects like syncing with external APIs (Payments) are never bypassed when mutating an identity.

## Solution

### Immediate Fix
Implemented the full stack pipeline for the feature:
1. Created `RoleConversionService` in the Student Backend to handle the DB transaction and trigger `_resize_family_plan(user, 0)`.
2. Created `ConvertStudentToParentView` exposed internally at `/api/internal/users/<id>/convert-to-parent/`.
3. Created `StudentConvertToParentView` proxy on the Admin Backend at `/api/students/<id>/convert-to-parent/`.
4. Extended the Admin Frontend UI with a `useConvertStudentToParent` hook and integrated a confirmation dialog to safely drop the student profile and remove the user from the active student-management table.

## Prevention
- [x] Code changes required

## Related Issues
- None

## References
- Internal discussions.

---

**Resolved By:** Antigravity
**Time to Resolution:** 30 minutes
