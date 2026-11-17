# Backend paper-detail tests cannot migrate local SQLite test database

**Date:** 2026-11-05
**Project:** HBEC
**Environment:** Local Django test environment
**Severity:** Medium
**Status:** Investigating

## Summary
The focused Django PracticeSetDetailViewTests cannot reach the view. Test database setup fails while applying a migration with sqlite3.OperationalError near ALTER.

## Symptoms
- manage.py test stops during migrations before running either paper-detail test.

## Environment Details
- **Server/Host:** Local workspace
- **Services Affected:** Backend contract verification
- **Related Components:** STUDENT/hbec_backend migrations and test database settings
- **Time First Observed:** 2026-11-05

## Investigation Steps
### 1. Initial Diagnosis
Ran the focused paper-detail Django test class using the project virtual environment.
### 2. Root Cause Analysis
Observed migration SQL failure in SQLite test database setup.
### 3. Key Findings
- The failure occurs before either test executes.

## Root Cause
The selected local SQLite test database cannot apply a migration containing ALTER syntax. The exact migration and intended PostgreSQL test configuration remain to be identified.

## Prevention / Rule
**Guardrail:** Run the focused paper-detail contract suite on the supported database engine in CI. This avoids treating an incompatible local test setup as backend proof.

## Solution
### Immediate Fix
None in this Flutter question-opening slice.
### Long-term Fix
Identify the migration, align the test database with the supported engine or make the migration portable, and rerun the focused tests.

## Prevention
- [ ] Configuration changes needed
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- HBEC-2026-11-05-flutter-question-response-schema-mismatch.md

## References
- STUDENT/hbec_backend/apps/practice/tests/test_paper_views.py

---

**Resolved By:** Pending
**Time to Resolution:** Pending
