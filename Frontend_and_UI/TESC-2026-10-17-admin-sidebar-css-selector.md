# Admin Sidebar CSS Selector Mismatch

**Date:** 2026-10-17
**Project:** TESC (ScalarEye)
**Environment:** Staging
**Severity:** Medium
**Status:** Resolved

## Summary

The authenticated admin navigation was intended to render as a persistent
Chemglee-inspired sidebar, but staging displayed the navigation as plain links
in the header. The sidebar template used `id="tesc-sidebar"` while the
stylesheet targeted `#nav-global`, so the layout and visual rules never
applied.

## Symptoms

- The operations page showed the links `Overview`, `Manage data`, and
  `Activity` as a plain top navigation.
- The expected blue left navigation panel was not visible.
- Additional sidebar links were not presented as a grouped navigation shell.

## Environment Details

- **Server/Host:** Staging VM `10.50.1.37`
- **Services Affected:** `tesc-backend-1`, nginx-served admin static assets
- **Related Components:** Django admin base template and TESC admin CSS
- **Time First Observed:** 2026-10-17 21:07 CAT

## Investigation Steps

### 1. Initial Diagnosis

Compared the live admin shell request with the deployed template and static
asset fingerprints, then inspected Django's `admin/base.html` inheritance.

### 2. Root Cause Analysis

The custom template emits:

```html
<aside id="tesc-sidebar">
```

The stylesheet instead defined the layout on:

```css
#nav-global { ... }
```

Django does not wrap the `nav-global` block in an element with that ID. The
selector therefore matched nothing, leaving the sidebar unstyled in the
header area.

### 3. Key Findings

- The template file was present and had the expected sidebar markup.
- The CSS file was served successfully but contained rules for the wrong
  selector.
- Django checks and functional admin tests did not detect the visual selector
  mismatch.

## Root Cause

The template element ID and CSS layout selector drifted during the sidebar
implementation. This was a cross-file UI contract failure: the template
producer named `tesc-sidebar`, while the stylesheet consumer expected
`nav-global`.

## Prevention / Rule

**Guardrail:** The admin shell regression test must assert the rendered
sidebar ID and the deployed stylesheet must contain a matching
`#tesc-sidebar` selector.

This guardrail links the template and stylesheet contract directly and catches
the exact failure before deployment instead of relying on visual discovery.

## Solution

### Immediate Fix

Changed the admin CSS selectors from `#nav-global` to `#tesc-sidebar`, added
sidebar link border normalization, and updated login/mobile selectors.

### Long-term Fix

Keep the sidebar root ID and its primary layout selector adjacent in the
template/CSS contract. Add browser-level visual verification for desktop and
mobile widths during future admin-shell changes.

## Prevention

- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues

- `reports/TESC-2026-10-17-admin-sidebar-navigation-redesign.md`

## References

- `backend/templates/admin/base_site.html`
- `backend/users/static/admin/tesc_admin.css`
- `backend/users/tests.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same implementation session
