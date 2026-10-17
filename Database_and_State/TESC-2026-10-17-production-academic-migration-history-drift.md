# Production academic migration history drift

**Date:** 2026-10-17
**Project:** TESC
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
Deploying the exact currently running staging backend image exposed a
production Django migration-history mismatch. Production had recorded the old
`academic.0021` index migration, while staging had reorganized the same five
student-index operations into a second `academic.0019` branch merged by
`academic.0020`.

## Symptoms
- The promoted backend repeatedly restarted.
- Django raised:
  `InconsistentMigrationHistory: Migration academic.0020_merge_staging_student_migrations is applied before its dependency academic.0019_student_academic_st_status_f931b2_idx_and_more`.
- Nginx temporarily returned HTTP 502 for API requests while the backend was
  restarting.

## Environment Details
- **Server/Host:** Production VM `10.50.200.35`
- **Services Affected:** Backend and nginx-proxied API
- **Related Components:** Django migration recorder, academic migrations,
  promoted backend image
- **Time First Observed:** 2026-10-17

## Investigation Steps

### 1. Initial Diagnosis
Inspected backend crash logs, the production `django_migrations` records, and
the migration files in both the promoted staging image and the rollback image.

### 2. Root Cause Analysis
The old production image applied:
`academic.0019_student_gender_unspecified`,
`academic.0020_merge_staging_student_migrations`, and
`academic.0021_student_academic_st_status_f931b2_idx_and_more`.

The staging image instead contains both
`academic.0019_student_gender_unspecified` and
`academic.0019_student_academic_st_status_f931b2_idx_and_more`, with `0020`
depending on both. The old `0021` and the new `0019` contain the same five
student index operations.

### 3. Key Findings
- A fresh custom-format production backup was created before the repair.
- The required five indexes already existed from the old `0021` migration.
- No index operation needed to be rerun.
- The mismatch was migration metadata drift, not missing schema data.

## Root Cause
Production had been migrated with an earlier migration graph and then received
an image containing a later rebased/branched migration graph. The database
history was not reconciled as part of the earlier selective image promotion.

## Prevention / Rule
**Guardrail:** Require a migration-graph compatibility check against the
target database before promoting an image, including detection of applied
migrations whose declared dependencies are absent or reordered in the
candidate image.

This prevents a container startup crash after an otherwise successful image
transfer and forces migration-history reconciliation before traffic is moved.

## Solution

### Immediate Fix
Recorded the staging image's equivalent
`academic.0019_student_academic_st_status_f931b2_idx_and_more` migration as
applied because its five index operations were already present from production
`0021`. The backend and worker were recreated, and Django then reported no
pending migrations.

### Long-term Fix
Avoid divergent migration numbering across staging and production branches.
Run migration-plan and dependency-history checks against a production
database clone before artifact promotion.

## Prevention
- [x] Database migration checks needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [ ] Code changes required

## References
- Production backup:
  `/home/user/backups/tesc_predeploy_20261017T071358Z.dump`
- Promoted `academic` migration files
- TESC production image promotion report

---

**Resolved By:** Copilot
**Time to Resolution:** Same deployment session
