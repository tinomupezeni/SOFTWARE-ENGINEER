# Swap-O-Sell Navigation Layout Refactor

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** UX Refactor
**Status:** Completed

## Summary
Removed the six-destination navigation cluster from the top header and moved
it into navigation surfaces better suited to each viewport. Desktop users now
get a persistent side rail while mobile users get a bottom navigation bar.
The top bar is reserved for the logo, product search, and account actions,
reducing competition for attention and preserving direct access to every
destination.

## Context / Trigger
The user reported that placing Feed, Messages, Orders, Insights, Saved, and
Notifications together at the top did not work well. The existing header was
simultaneously responsible for brand identity, search, profile controls, and
six text-heavy destination buttons.

## Scope
Included the shared `Navbar` component and the application shell spacing
needed to accommodate the new navigation surfaces. Existing routes and
destination names were preserved. No page-level workflow or backend changes
were included.

## Method

1. Reviewed the current navigation component and route definitions.
2. Preserved the existing destination model and active-route behavior.
3. Reduced the top bar to brand, search, and account controls.
4. Added a labeled desktop rail and a compact mobile bottom bar.
5. Added responsive shell padding so content is not obscured.
6. Built the frontend and rebuilt the local Docker frontend image.

## Decisions & Findings

- Desktop navigation benefits from persistent vertical access because it
  avoids compressing six destinations into a horizontal header.
- Mobile navigation benefits from a bottom bar because it is reachable by
  thumb and remains separate from search and account controls.
- The route set was not changed, so deep links and active-state behavior
  remain compatible with the existing application.
- Profile remains an account action rather than a peer destination in the
  primary navigation.

## Changes Made

- `swappify-social-hub/src/components/Navbar.tsx`
  - Removed the desktop top-row destination buttons.
  - Added a fixed desktop destination rail.
  - Added a fixed mobile bottom navigation bar.
  - Kept profile and search controls in the top bar.
- `swappify-social-hub/src/App.tsx`
  - Added responsive left and bottom shell padding for the new navigation.

## Verification

- `npm run build` passed.
- `docker compose up --build -d frontend` passed.
- `http://localhost:8080/` returned HTTP 200 after the container settled.
- `http://localhost:8080/api/health/` returned
  `{"ok": true, "service": "swap-o-sell"}`.
- `git diff --check` passed for the navigation changes.

## Follow-ups / Deferred

- Perform browser-based visual review at mobile, tablet, and desktop widths.
- Add unread-count badges to Messages and Notifications if those counts are
  exposed consistently by the API.
- Consider collapsing the desktop rail to icon-only mode at intermediate
  widths based on measured content density.

## References

- `/home/shadowe/Projects/swap-o-sell/swappify-social-hub/src/components/Navbar.tsx`
- `/home/shadowe/Projects/swap-o-sell/swappify-social-hub/src/App.tsx`
- `Principal_Engineer/engineering-guides/12. HCI.md`

---

**Completed By:** Copilot
**Duration:** One implementation session
