# Products Hero: Category Chips Overlapped the Subtitle When They Wrapped

**Date:** 2026-09-11
**Project:** chemglee-concept-site
**Environment:** Production + Development
**Severity:** Low
**Status:** Resolved

## Summary
On `/products`, the category-count chip row (`household`, `industrial`,
`carcarerange`, etc.) was absolutely positioned (`absolute bottom-6 left-0
right-0`) to sit pinned over the bottom of the hero art, independent of the
hero's other content. Once the row wrapped to a second line — more
categories, or a narrower viewport — the second line rendered directly on top
of the "N certified bulk-available products" subtitle text above it, making
both illegible where they overlapped.

## Symptoms
- Category chips visually overlapping/obscuring the product-count subtitle on
  the products hero, worse on narrower screens or with more categories.

## Root Cause
The chip row was taken out of normal document flow (`absolute`) so it could
sit "on top of" the hero artwork, but nothing accounted for its own height
once its content wrapped — a sibling in normal flow would have pushed
content down; an absolutely positioned one just overlaps whatever is
underneath it.

## Solution
Moved the chip row into normal flow, directly under the subtitle
(`frontend/src/routes/products.tsx`), using `mt-7 flex gap-2.5 flex-wrap
justify-center` instead of absolute positioning. The hero's bottom padding
was reduced (`pb-16` → `pb-8`) since the chips now occupy that space in flow
rather than floating over it.

## Prevention
- Not applicable — straightforward layout fix, low risk of recurrence.

## References
- `frontend/src/routes/products.tsx`
- Merged via PR #3 (`feat/admin-ux-postgres` → `main`), commit `ec3400c`

---

**Resolved By:** winstonjthinker (PR #3), merged by tinomupezeni
**Time to Resolution:** Same session as discovery
