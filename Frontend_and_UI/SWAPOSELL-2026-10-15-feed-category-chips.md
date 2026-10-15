# Feed retained the old category chips

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
The category-chip change was initially applied only to the Search page, while the visible Feed page had a separate category-control implementation. Users visiting the Feed continued to see the crowded horizontal category row.

## Symptoms
- Search used the new category dropdown.
- Feed still displayed `Near you`, `All`, and the horizontal category chips.
- The requested UI change appeared not to have taken effect on the visible route.

## Environment Details
- **Server/Host:** Local Docker Compose
- **Services Affected:** Feed page
- **Related Components:** `Feed.tsx`, `Search.tsx`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Inspected the served frontend bundle and searched all page components for the visible category labels and chip rendering.

### 2. Root Cause Analysis
The Feed and Search pages each owned separate category controls. Only Search had been updated.

```bash
rg "Near you|categories|All" swappify-social-hub/src/pages
```

### 3. Key Findings
- The visible `Near you` row was rendered by `Feed.tsx`.
- `Search.tsx` already contained the dropdown.
- The frontend container was rebuilt, so this was a route-coverage issue rather than a stale-bundle issue.

## Root Cause
The category UI was duplicated across routes and the first change covered only one implementation.

## Prevention / Rule
**Guardrail:** Shared marketplace controls must be updated or extracted across every route that renders the same user-facing behavior, followed by route-specific UI verification.

This prevents a route from retaining an outdated interaction after a cross-page UX decision.

## Solution

### Immediate Fix
Replaced Feed's horizontal category chips with the same compact category dropdown while retaining the `Near you` control.

### Long-term Fix
Consider extracting the category/location control row into a shared component if Feed and Search continue to evolve in parallel.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- Related to the Search category dropdown initiative.

## References
- `swappify-social-hub/src/pages/Feed.tsx`
- `swappify-social-hub/src/pages/Search.tsx`

---

**Resolved By:** Copilot
**Time to Resolution:** Same development session
