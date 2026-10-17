# Admin Shell Did Not Reuse Chemglee Design

**Date:** 2026-10-17
**Project:** TESC (ScalarEye)
**Environment:** Staging
**Severity:** Medium
**Status:** Resolved

## Summary

The first TESC admin redesign was presented as Chemglee-inspired but did not
reuse Chemglee's actual admin shell. It introduced a custom TESC sidebar and
custom dashboard styling instead of carrying over Chemglee's real base
template, inline design tokens, pill navigation, typography, card layout, and
dashboard component classes.

## Symptoms

- The authenticated admin continued to look unlike the referenced Chemglee
  admin.
- The user saw a custom top-link/sidebar treatment instead of the Chemglee
  header and pill navigation.
- The dashboard used TESC-specific metric/module classes rather than
  Chemglee's `cg-*` component system.

## Environment Details

- **Server/Host:** Staging VM `10.50.1.37`
- **Services Affected:** Django admin presentation
- **Related Components:** `base_site.html`, operations dashboard template,
  admin stylesheet
- **Time First Observed:** 2026-10-17 21:19 CAT

## Investigation Steps

### 1. Initial Diagnosis

Compared the requested design against the Chemglee reference files and the
rendered TESC admin response.

### 2. Root Cause Analysis

The prior implementation treated Chemglee as visual prior art and recreated
the shell instead of reusing the actual source design. Chemglee's design was
split across:

- `backend/templates/admin/base_site_old.html`
- `backend/templates/admin/index.html`
- `backend/static/css/admin_custom.css`

The first TESC implementation used a different base template and custom
sidebar selectors, so it could not produce the same design.

### 3. Key Findings

- Chemglee's actual authenticated shell uses a dark branded header, pill
  navigation, light-only design tokens, and no persistent left sidebar.
- Chemglee's dashboard uses `cg-dashboard-wrapper`, `cg-metrics-grid`,
  `cg-metric-card`, `cg-lists-grid`, and `cg-manage-grid`.
- The TESC operations data could be mapped into those components without
  changing backend authorization or operational data sources.

## Root Cause

The implementation scope was interpreted as “inspired by Chemglee” rather
than “reuse the exact Chemglee admin design.” This caused a design-system
contract failure between the requested reference and the delivered shell.

## Prevention / Rule

**Guardrail:** Any admin redesign explicitly requesting reuse of a reference
application must include a reference-marker test that asserts the source
shell's defining template and component markers (for this design:
`cg-nav`, `cg-dashboard-wrapper`, `cg-metrics-grid`, and `cg-manage-grid`)
and rejects the superseded shell markers.

This prevents a custom approximation from being described or deployed as the
reference design.

## Solution

### Immediate Fix

- Replaced the TESC authenticated base shell with Chemglee's actual
  `base_site_old.html` structure.
- Adapted only the TESC branding and route targets.
- Reused Chemglee's `admin_custom.css` as the TESC admin stylesheet.
- Rebuilt the operations dashboard with Chemglee's `cg-*` dashboard
  components while preserving TESC metrics, backups, health, and audit data.

### Long-term Fix

Keep the reference shell and component markers as a contract in focused
tests, and perform live authenticated staging verification before declaring
reference-design work complete.

## Prevention

- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues

- `Frontend_and_UI/TESC-2026-10-17-admin-sidebar-css-selector.md`
- `reports/TESC-2026-10-17-admin-sidebar-navigation-redesign.md`

## References

- `/home/shadowe/Projects/chemglee-concept-site/backend/templates/admin/base_site_old.html`
- `/home/shadowe/Projects/chemglee-concept-site/backend/templates/admin/index.html`
- `/home/shadowe/Projects/chemglee-concept-site/backend/static/css/admin_custom.css`
- `backend/templates/admin/base_site.html`
- `backend/users/templates/admin/operations_dashboard.html`
- `backend/users/static/admin/tesc_admin.css`

---

**Resolved By:** Copilot
**Time to Resolution:** Same implementation session
