# Storefront Made Unsupported Claims, Linked to Non-Existent Sections, and Advertised Products It Doesn't Sell

**Date:** 2026-09-18
**Project:** chemglee-concept-site
**Environment:** Production
**Severity:** Medium (false-advertising/legal exposure — no evidence held for claims made to customers)
**Status:** Resolved (merged to `main` via PR #4)

## Summary
A site content audit (surfaced in PR #4, commit `c224bb6`) found the
storefront asserting things the business holds no evidence for and pointing
customers at content that doesn't exist:
- Marketing copy claimed "pathogen kill-rates," "Certified Cleaning
  Chemistry," "certified safety compliance," and a testimonial asserting lab
  certification — none backed by real test data or certification.
- The footer's three range links (`#household`, `#industrial`, `#carcare`)
  were hardcoded anchors. Staff had since renamed the car-care slug to
  `carcarerange` and Industrial was never stocked, so two of three links
  scrolled to an element that isn't on the page.
- A category filter chip for a range with zero products in stock ("Industrial
  (0)") was still shown and clickable, leading to an empty page.
- The homepage ticker was a hardcoded product list naming "Toilet Dip, Auto
  Degreaser, Window Cleaner" — none of which the shop sells.

## Root Cause
Marketing/footer/ticker content was hand-written once and never re-derived
from (or re-checked against) the live catalogue or actual test data, so it
drifted as the real product range and category slugs changed underneath it.

## Solution
- Removed every unsupported claim; replaced with what the business actually
  does (in-house batch checks for viscosity, pH stability, consistency).
- Footer range links now read the live categories, so a link can only point
  at a section the shop actually renders; the scroll now also fires when
  already on `/products` (previously only ran on mount).
- Empty ranges no longer get a filter chip — a range appears once it has
  stock.
- The homepage ticker now reads the catalogue instead of a hardcoded list.

## Prevention
- [ ] Consider a lightweight CI check that greps marketing copy for
      certification/compliance language and requires an explicit sign-off,
      so an unbacked claim can't ship silently again.

## References
- Commit `c224bb6` ("Say only what we can back up, and link where every
  claim leads"), merged to `main` in this session's PR #4 merge (`8bcc3dd`).
- Related, same commit: `chemglee-concept-site-2026-09-18-seed-catalog-mock-data-in-production.md`,
  `chemglee-concept-site-2026-09-18-storefront-missing-security-headers-and-canonical-urls.md`

---

**Resolved By:** winstonjthinker + Claude Opus 5 (1M context), PR #4
**Time to Resolution:** N/A (site audit)
