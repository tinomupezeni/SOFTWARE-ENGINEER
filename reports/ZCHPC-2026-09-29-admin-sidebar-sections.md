# Admin sidebar sections (design refresh follow-up)

**Date:** 2026-09-29
**Project:** ZCHPC-ERP
**Type:** Refactor (frontend nav structure)
**Status:** Completed

## Summary

Grouped the admin frontend's flat 9-module sidebar into five labeled
sections (Overview, People & Pay, Money, Operations, System), moved the
active state onto primary tokens, and removed stray render logs. Merged
via PR #36 and deployed to prod. Also resolved a monitoring puzzle: the
staging portal container was simply never recreated after the staging
DB wipe (`down` + scoped `up`s) — no crash, recreated healthy.

## Context / Trigger

Requester feedback on pass 1: the portal regrouping was visible, but the
admin sidebar (the screen in their screenshot) was untouched.

## Scope

- Included: `navConfig.tsx` section labels + `NAV_SECTIONS`, `MainLayout`
  grouped render, `SidebarItem` token colors, log removal.
- Excluded: portal (done in pass 1), sub-item hierarchy changes
  (Training's 3rd nesting level left as-is).

## Method

Same as pass 1: read real components, annotate config (not markup),
group at render so permission/module filtering keeps working, eslint +
`vite build`, diff reviewed line by line (one bad edit caught and
repaired before commit).

## Decisions & Findings

- Sections assigned by module affinity; unannotated items fall back to
  "System" rather than disappearing.
- Headers hidden in collapsed icon mode; empty filtered groups skipped.
- `bg-primary/10 text-primary` active state (≈5:1 on near-white).
- Pre-existing `tsc` App.tsx `setOpenTab` errors left untouched.

## Changes Made

- PR #36 (`design/admin-sidebar-sections` → `main`, `cde9eff`):
  3 files, +55/−22.
- VM: rebuilt staging `frontend` (prod origin arg), bundle-grepped
  ("People & Pay" present, no localhost), retagged, recreated prod
  `zchpc_frontend`; recreated long-missing `zchpc_staging_portal`.

## Verification

- Staging then prod `:3000` 200 with section labels in served bundle;
  all 8 host containers healthy; API + data paths untouched (backend
  unchanged this deploy).

## Follow-ups / Deferred

- Pass 2 (empty/error states, signature element, type scale) still open.

## References

- PR: https://github.com/tinomupezeni/ZCHPC-ERP/pull/36
- Pass 1: `reports/ZCHPC-2026-09-29-design-refresh-contrast-sidebar.md`

---

**Completed By:** Muse Spark (opencode)
**Duration:** ~45 min
