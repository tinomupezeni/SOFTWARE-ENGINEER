# Admin Design Source Drift

**Date:** 2026-10-18
**Project:** TESC (ScalarEye)
**Environment:** Staging
**Severity:** Low
**Status:** Investigating

## Summary

The current staging admin shell differs from the exact Chemglee pill-navigation
implementation previously verified. Staging now serves a newer Scalareye-
branded sidebar shell while retaining Chemglee-derived dashboard component
classes and styling.

## Symptoms

- The live authenticated response contains `sc-sidebar` navigation rather than
  the previously verified `cg-nav` pill navigation.
- The branding and dashboard copy use “Scalareye” rather than “TESC”.
- The live stylesheet contains both `sc-sidebar` and Chemglee `cg-*` dashboard
  markers.

## Environment Details

- **Server/Host:** Staging VM `10.50.1.37`
- **Services Affected:** Django admin presentation
- **Related Components:** Admin base template, operations dashboard template,
  admin stylesheet
- **Time First Observed:** 2026-10-18 08:44 CAT

## Investigation Steps

### 1. Initial Diagnosis

Checked staging service health, public routes, static CSS markers, and the
authenticated operations dashboard response.

### 2. Root Cause Analysis

The staging-mounted source files currently contain a newer Scalareye sidebar
implementation than the exact Chemglee pill-navigation version previously
deployed. The current source is also ahead of the local worktree snapshot,
indicating source/deployment drift that must be reconciled before another
promotion.

### 3. Key Findings

- Admin login, main portal, and institution portal return HTTP 200.
- Authenticated operations dashboard returns HTTP 200.
- Database migrations are fully applied.
- Backend and worker restart counts are zero.
- The live dashboard uses Chemglee-derived `cg-dashboard-wrapper`,
  `cg-metrics-grid`, and `cg-manage-grid` classes.
- The live shell currently uses `sc-sidebar` navigation and Scalareye
  branding.

## Root Cause

The deployed staging admin files and the local repository files are not the
same revision. This creates design-source drift and makes the visible staging
experience differ from the last locally verified implementation.

## Prevention / Rule

**Guardrail:** Before any admin UI promotion, compare SHA-256 fingerprints for
the template, dashboard template, source stylesheet, and collected stylesheet
between local source and staging, and fail the promotion on any mismatch.

This prevents a stale or independently modified staging checkout from being
reported as the locally verified design.

## Solution

### Immediate Fix

No files were changed during this inspection. The current staging state was
verified and reported.

### Long-term Fix

Reconcile the newer Scalareye sidebar implementation with the requested
reference design, then promote one committed source revision and retain the
artifact fingerprints as deployment evidence.

## Prevention

- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [ ] Code changes required

## References

- `/home/user/TESC/backend/templates/admin/base_site.html` on staging
- `/home/user/TESC/backend/users/templates/admin/operations_dashboard.html` on staging
- `/home/user/TESC/backend/users/static/admin/tesc_admin.css` on staging
- `backend/templates/admin/base_site.html`
- `backend/users/templates/admin/operations_dashboard.html`
- `backend/users/static/admin/tesc_admin.css`

---

**Resolved By:** Copilot
**Time to Resolution:** Inspection only
