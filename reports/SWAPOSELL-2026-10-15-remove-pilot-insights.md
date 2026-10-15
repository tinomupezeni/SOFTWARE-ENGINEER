# Remove Pilot Insights Surface

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** Cleanup / Scope Decision
**Status:** Completed

## Summary

Removed the internal pilot-readiness and H1-H10 experiment dashboard from the
customer-facing Swap-O-Sell application. The obsolete page, route, and
navigation entry are no longer shipped or discoverable.

## Context / Trigger

The user requested removal of the page displaying pilot readiness, depot and
payment configuration status, unit economics, field observations, experiment
rates, and day-90 gates. That operational pilot dashboard is not part of the
current marketplace customer journey.

## Scope

Removed the React page, its `/insights` route, and desktop/mobile navigation
links. No backend analytics, order, experiment, or payment data models were
changed.

## Method

Searched the frontend for the page title, route, component references, and
distinct dashboard labels. Removed the page import, route, navigation item,
and page file, then checked for remaining references and built the frontend.

## Decisions & Findings

- The page was isolated in `src/pages/Insights.tsx`.
- The route was registered only in `App.tsx`.
- The only navigation entry was the `Insights` item in `Navbar.tsx`.
- No remaining frontend references to `/insights`, `Pilot insights`, or the
  H1-H10 dashboard labels remain.

## Changes Made

- Deleted `swappify-social-hub/src/pages/Insights.tsx`.
- Removed the `Insights` import and `/insights` route from
  `swappify-social-hub/src/App.tsx`.
- Removed the `Insights` item from desktop and mobile navigation through
  `swappify-social-hub/src/components/Navbar.tsx`.

## Verification

- Frontend search found no remaining pilot-insights references.
- `git diff --check` passed.
- `npm run build` passed successfully.

## Follow-ups / Deferred

The underlying operational metrics remain available in backend code where
needed for future internal tooling. If an operations dashboard is required
again, it should be reintroduced as a protected internal/admin surface rather
than a customer-facing navigation destination.

## References

- `swappify-social-hub/src/App.tsx`
- `swappify-social-hub/src/components/Navbar.tsx`
- `swappify-social-hub/src/pages/Insights.tsx`

---

**Completed By:** Copilot
**Duration:** One implementation session
