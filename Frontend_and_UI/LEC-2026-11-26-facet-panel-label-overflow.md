# Storefront category filter labels overflow into product grid

**Date:** 2026-11-26
**Project:** LEC Biotec (lec-biotech-ascend)
**Environment:** Development (reported via screenshot, confirmed in source)
**Severity:** Medium
**Status:** Resolved

## Summary
On the storefront catalogue page, long category filter labels (e.g.
"Biochemicals & Molecular Reagents") visually overflowed the 14rem filter
sidebar and bled into the adjacent product grid, overlapping product card
text.

## Symptoms
- Screenshot showed category radio-button labels running past the sidebar
  boundary, overlapping the product grid's "MICROBIOLOGY" tag and card
  copy to its right.
- Reported as "admin side" by the user, but the actual component is the
  storefront's catalogue filter sidebar (`apps/storefront`), not
  `apps/admin` — the admin product editor/filters use plain `<select>`
  dropdowns and have no radio-button UI at all.

## Environment Details
- **Related Components:** `apps/storefront/src/features/catalogue/FacetPanel.tsx`,
  `apps/storefront/src/features/catalogue/CataloguePage.tsx`
- **Time First Observed:** 2026-11-26

## Investigation Steps

### 1. Initial Diagnosis
Searched `apps/admin` for any radio-group component per the report; found
none (admin filters are `<select>` elements). Re-scoped to
`apps/storefront` based on the screenshot, which matched `FacetPanel.tsx`'s
category facet list exactly.

### 2. Root Cause Analysis
Read `CataloguePage.tsx:110-123` (grid layout: `md:grid-cols-[14rem_1fr]`,
`<aside>` with no width/overflow constraint) and `FacetPanel.tsx:39-64`
(each facet rendered as `<label className="flex items-center gap-2 text-sm">`
wrapping a `<span className="min-w-0 flex-1 truncate">`).

### 3. Key Findings
- The truncating `<span>` was correctly configured (`min-w-0 flex-1
  truncate`), but its parent `<label>` flex container had no `min-w-0` of
  its own. In CSS flexbox, a flex item's default `min-width` is `auto`, so
  the label row's intrinsic content width could force it wider than its
  grid track regardless of the child's truncation.
- The `<aside>` sidebar container in `CataloguePage.tsx` had no
  `min-w-0`/`overflow-hidden`, so once a row exceeded the 14rem track,
  nothing clipped it — the text rendered past the sidebar into the gap and
  the product grid beyond.

## Root Cause
A flex child's `min-width: auto` default was never overridden on the
`<label>` row in `FacetPanel.tsx`, which silently defeated the correctly
configured `truncate` on its own child `<span>`; the sidebar container had
no overflow containment as a backstop.

## Prevention / Rule
**Guardrail:** Any flex row that wraps a `truncate`d text node must itself
carry `min-w-0` — truncation only works through an unbroken chain of
`min-w-0` ancestors up to the constrained container. No automated gate
covers this; it is a code-review checklist item for storefront/admin PRs
touching flex layouts with truncated text.

This closes the gap because the bug wasn't the truncation class being
missing — it was present and correct — the issue was a sibling-level flex
default one layer up that nothing in the existing component touched or
tested.

## Solution

### Immediate Fix
- `apps/storefront/src/features/catalogue/FacetPanel.tsx:50` — added
  `min-w-0` to the facet `<label>` flex row.
- `apps/storefront/src/features/catalogue/CataloguePage.tsx:114` — added
  `min-w-0 overflow-hidden` to the `<aside>` sidebar as a second line of
  containment.

### Long-term Fix
None required beyond the fix above; consider widening the `14rem` sidebar
track if more long category names are added later.

## Prevention
- [x] Code changes required (done)
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Related Issues
None.

## References
- `apps/storefront/src/features/catalogue/FacetPanel.tsx`
- `apps/storefront/src/features/catalogue/CataloguePage.tsx`

---

**Resolved By:** Claude (session with tinomupezeni)
**Time to Resolution:** < 1 hour
