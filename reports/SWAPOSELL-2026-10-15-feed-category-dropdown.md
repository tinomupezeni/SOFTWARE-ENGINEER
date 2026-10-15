# Feed category dropdown

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** UX Correction
**Status:** Completed

## Summary
Applied the compact category-dropdown design to the Feed page as well as Search. The Feed now keeps `Near you` as a primary location action and exposes category selection through a single compact native dropdown.

## Context / Trigger
The user reported that the category dropdown was not visible. Investigation found that the visible Feed route had a separate horizontal chip implementation that had not been updated during the Search refinement.

## Scope
Included Feed category controls and deployment of the frontend bundle. Search controls, backend search behavior, and location ranking were preserved.

## Method
Traced the visible labels to the route-specific component, removed the duplicate chip group, added a native accessible select, rebuilt the frontend container, and verified the proxied health endpoint.

## Decisions & Findings
- `Near you` remains a prominent button because it is an action, not a filter value.
- Categories are progressive-disclosure controls in a native dropdown.
- The Feed now follows the same compact interaction pattern as Search.
- The category list includes all available categories.

## Changes Made
- Updated `swappify-social-hub/src/pages/Feed.tsx`.
- Removed the unused priority-category ordering import from Feed.
- Rebuilt and recreated the frontend container.
- Added issue log `SWAPOSELL-2026-10-15-feed-category-chips.md`.

## Verification
- Frontend `npm run build` passed.
- `git diff --check` passed.
- Frontend container rebuilt successfully.
- `http://localhost:8080/` and proxied `/api/health/` returned successfully.

## Follow-ups / Deferred
- Extract Feed and Search browse controls into a shared component if more shared behavior is added.
- Add Playwright route checks for both Feed and Search category controls.

## References
- `swappify-social-hub/src/pages/Feed.tsx`
- `swappify-social-hub/src/pages/Search.tsx`
- `SWAPOSELL-2026-10-15-feed-category-chips.md`

---

**Completed By:** Copilot
**Duration:** Same development session
