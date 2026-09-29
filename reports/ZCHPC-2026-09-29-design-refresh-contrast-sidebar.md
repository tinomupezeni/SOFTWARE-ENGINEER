# Design refresh pass 1: contrast, dark-mode removal, sidebar grouping

**Date:** 2026-09-29
**Project:** ZCHPC-ERP
**Type:** Refactor (frontend design foundations)
**Status:** Completed

## Summary

Apple-design-lens audit of both ERP frontends found measurable contrast
failures, a dead dark-mode system, no keyboard-focus story, and sidebar
sprawl. Fixed the tokens (4.93/5.19/5.18:1), removed dark mode by
decision, added focus + reduced-motion handling, grouped the portal
sidebar, and made paper tables scroll on phones. Merged via PR #33 and
deployed to prod (test phase, no real users) by promoting rebuilt
frontend images.

## Context / Trigger

Follow-up to the day's deploy work: with prod freshly promoted, audit
the ERP's visual foundations using `Lessons/apple-design/SKILL.md`
(lenses + craft review) and `Lessons/planning/procedural/` workflow
(phase-gated initiative, pre-deploy verification).

## Scope

- Included: `employee-portal` + `zchpc-erp-synergy-main` token/contrast
  fixes, `.dark` removal, `:focus-visible`, reduced-motion, portal
  sidebar sections, mobile paper-table scroll.
- Explicitly excluded: print/paper visual language (deliberate A4
  replicas, documented in code), backend, empty/loading/error-state
  audit, signature-element craft pass (deferred to pass 2).

## Method

1. Read real tokens/components (no recall); computed contrast ratios
   from token values with Python instead of estimating.
2. Clarified three forks with the requester first (keep blue hue / delete
   dark mode / group sidebar) — all answered before code.
3. Matched existing conventions (shadcn tokens, `cn()` patterns, `<p>`
   section headers like the old "Menu" label).
4. Gates: `tsc -b`, `eslint` (stash-compared: 9 pre-existing errors
   unchanged), Sidebar/Header 31/31 vitest, both `vite build`s, tokens +
   focus rule grepped in dist bundles.

## Decisions & Findings

- Measured (old → new): primary button text 3.66 → 4.93:1, destructive
  3.61 → 5.19:1, muted 4.29 → 5.18:1 (4.5:1 minimum, 14px text).
- Same failures existed in both frontends (shared token values).
- `.dark` dead in both (portal: zero appliers; admin: `next-themes`
  dependency with no `ThemeProvider`, `useTheme()` only in unrendered
  `sonner.tsx`). Deleted rather than wired, by decision.
- Sidebar active gradient (white on blue-500) also failed 4.5:1 — moved
  to primary tokens, which fixed it to 4.93:1.
- shadcn primitives already had focus rings; only native elements needed
  the global rule. `--ring` (near-black) kept — visible on light-only UI.
- `dark:` leftovers in admin `chart.tsx`/`alert.tsx` are inert without
  `.dark` (v4 `dark:` falls back to OS preference but only tweaks chart
  theming/border opacity) — left alone, noted.

## Changes Made

- PR #33 (`design/token-contrast-focus-sidebar` → `main`, `4404ace`):
  `employee-portal/src/index.css`, `zchpc-erp-synergy-main/src/index.css`,
  `employee-portal/src/components/layout/Sidebar.tsx` (+115/−101).
- VM: rebuilt staging `frontend`/`portal`, verified tokens in served
  bundles, retagged to `tinotenda762/*:latest`, recreated prod
  `zchpc_frontend`/`zchpc_portal`. API/DB untouched.

## Verification

- Staging then prod: `:3000`/`:3010`, `:3001`/`:3011` `/health` → 200;
  `:8000` API healthy; `210 100% 42%` present in served CSS on all four
  containers; all 8 host containers healthy.
- Real-browser visual click-through NOT done by agent — flagged to
  requester as the remaining `pre_deploy_verification.md` step; safe to
  do live since prod is in test phase with no real users.

## Follow-ups / Deferred

- Pass 2 candidates: empty/loading/error-state audit, signature element
  (proposed: status/queue visual language matching the existing copy
  voice), type-scale documentation, `glass-effect`/`hover-scale` usage
  audit, removal of inert `dark:`/`next-themes` leftovers.
- Decide staging/prod `VITE_API_URL` bake (carried over, unchanged).

## References

- PR: https://github.com/tinomupezeni/ZCHPC-ERP/pull/32 (prior, unrelated)
- PR: https://github.com/tinomupezeni/ZCHPC-ERP/pull/33
- Skill: `Lessons/apple-design/SKILL.md`, `references/cross-platform.md`
- Workflow: `Lessons/planning/procedural/{index,feature_request_to_delivery,pre_deploy_verification}.md`
  (note: index is `index.md` — no `index.html` exists)

---

**Completed By:** Muse Spark (opencode)
**Duration:** ~1.5h (audit, clarify, implement, verify, deploy)
