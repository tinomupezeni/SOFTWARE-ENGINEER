# Search category dropdown

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** UX Refinement
**Status:** Completed

## Summary
Replaced the crowded horizontal category chips in Search with compact category and sort dropdowns. The change reduces visual competition at the top of the page while preserving category filtering, sorting, accessibility, and the existing advanced filters panel.

## Context / Trigger
The Search header displayed many category labels inline, making the control area feel crowded and harder to scan, especially on smaller screens.

## Scope
Included the Search page's top browse controls only. Backend search behavior, advanced filter fields, and the existing nearby-location flow were intentionally preserved.

## Method
Applied the HCI principle of progressive disclosure: keep the primary search field prominent, expose category and sort as recognizable native selects, and leave the full filter set behind the Filters control.

## Decisions & Findings
- Category selection is now a single compact dropdown.
- Sorting remains immediately available beside the category selector.
- The category dropdown includes all categories rather than only the first six.
- Native select controls preserve keyboard and screen-reader behavior.
- The advanced panel retains its category selector for users who prefer the full filter workflow.

## Changes Made
- Updated `swappify-social-hub/src/pages/Search.tsx`.
- Replaced horizontal category chips with compact category and sort selectors.
- Rebuilt the frontend Docker image so the served bundle includes the change.

## Verification
- Frontend `npm run build` passed.
- `git diff --check` passed.
- Frontend container rebuilt successfully.
- `http://localhost:8080/` and proxied `/api/health/` returned successfully.

## Follow-ups / Deferred
- Consider removing the duplicate category selector from the advanced panel after observing user behavior.
- Add browser-level responsive checks for the Search header at mobile and desktop breakpoints.

## References
- `swappify-social-hub/src/pages/Search.tsx`
- `SOFTWARE-ENGINEER/Principal_Engineer/engineering-guides/12. HCI.md`

---

**Completed By:** Copilot
**Duration:** Same development session
