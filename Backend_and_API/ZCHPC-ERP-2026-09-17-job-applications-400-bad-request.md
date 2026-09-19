# Recruitment Applications Endpoint 400 Bad Request Fix

**Date:** 2026-09-17
**Project:** ZCHPC-ERP
**Environment:** Production (erp-vm)
**Severity:** Medium (API Crashing)
**Status:** Resolved

## Summary
When navigating to the Job Applications view in the frontend, the API endpoint `/recruitment/jobs/{id}/applications/` returned a `400 Bad Request`, causing the `fetchApplications` method to fail and log `Failed to load resource: the server responded with a status of 400`.

## Symptoms
- Job Applicants could not be listed.
- API returned an error `{"error":"Invalid application status: Reviewed"}`.

## Root Cause
- During earlier test data seeding via raw SQL, arbitrary application statuses (`Reviewed`, `Interview Scheduled`) were manually inserted into the `JobApplication` table.
- The Django ORM SQLite driver did not enforce the `STATUS_CHOICES` validation at the database level.
- When the Domain-Driven Design components (`ApplicationStatus.from_string`) attempted to deserialize the SQL records, the unrecognized string statuses caused a strict `ValueError`, which the API correctly caught and wrapped in a `400 Bad Request` generic error container.

## Solution
1. Connected to the production container's Django shell.
2. Ran an ORM cleanup script targeting the corrupted `JobApplication` rows:
   - `Reviewed` was normalized to `Shortlisted`.
   - `Interview Scheduled` was normalized to `Interview`.
3. Verified the endpoint now successfully returns `200 OK` and correctly serializes the domain objects.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code/Data changes required (Data sanitization against DDD value objects)

---

**Resolved By:** Antigravity
**Time to Resolution:** 5 minutes
