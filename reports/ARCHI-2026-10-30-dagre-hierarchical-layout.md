# Hierarchical layout for the System map, via a vendored dagre, plus a render perf fix

**Date:** 2026-10-30
**Project:** Archi (source-backed VS Code architecture diagrams)
**Type:** Architecture decision + feature implementation
**Status:** Completed

## Summary

The user reported the System map's default view as "jumbled" and asked, separately, for my own unprompted assessment of where the extension should go next. I identified the System map's layout as a hardcoded alphabetical/fixed-order grid with no concept of edge direction as the root cause, and scoped a plan (approved by the user via Claude Code's plan mode) to fix it with `@dagrejs/dagre` as a vendored, position-only layout engine — explicitly rejecting a larger React Flow migration as unjustified for this specific problem. Implemented, tested (27/27 passing, up from 25), validated against real HBEC data with before/after screenshots showing a genuine hierarchical result (service cluster flowing down into shared infrastructure), and repackaged the VSIX.

## Context / Trigger

Earlier the same session, the user reported the extension "freeze[s] my pc" when opened against HBEC. While investigating that (inconclusive — likely the user's machine, per their own follow-up), I read through `media/main.js`'s render path closely enough to notice the System map's layout logic was a hardcoded 3-column grid sorted by a fixed area-name array, with no awareness of dependency direction — and separately found real `O(n²)` hot spots in the same render path. The user then reported the diagram as "jumbled" and explicitly asked for my own unconstrained opinion on the extension's direction, not just a literal fix to what they described.

## Scope

**Included:** diagnosing why the System map looks jumbled (no real layout algorithm); researching and selecting a layout library; scoping and implementing a narrowly-targeted fix (top-level System view only); fixing the `O(n²)` render hot spots found during the freeze investigation (applies to all views); visual validation against real HBEC data.

**Explicitly excluded, with reasoning:** a React Flow migration (the obvious "modernize the whole renderer" move) was considered and rejected for this change — it would mean a new build step, a full rewrite of ~470 lines of hand-rolled interaction/drag/hide/rename/cross-nav logic, and reworking every webview test, none of which is justified by the specific, narrow complaint. Applying the new layout to the Data view, the Flows view, or the focused System drill-down was also excluded — the drill-down specifically would have gotten *worse* (siblings are mostly edge-less, so a layered layout would stack them into one wide row instead of the current clean grid), confirmed by reasoning through the algorithm's behavior before writing any code, not discovered after the fact.

## Method

Used Claude Code's plan mode for this one, since it met the tool's own stated bar (architectural decision, multiple valid approaches, multi-file change) — unlike the phase work earlier in the session, which followed the project's own `IMPLEMENTATION_PLAN.md` so closely that there was no real decision to align on.

Before committing to a library, verified the specific integration constraint that mattered here: Archi's webview has no bundler and a strict CSP (`script-src 'nonce-...'`), so any layout library had to be usable as a plain `<script>` tag. Checked `@dagrejs/dagre`'s published package directly (`npm pack --dry-run`, then extracting and grepping the actual minified file) rather than assuming from documentation — confirmed `dist/dagre.min.js` is a genuinely dependency-free global-variable IIFE (zero `require()` calls), not a UMD wrapper that would still need a module system. This read-only verification happened *inside* plan mode, before any approval was requested, so the plan presented to the user was grounded in a checked fact, not an assumption.

## Decisions & Findings

- **`@dagrejs/dagre` as a devDependency, not a dependency.** Only its prebuilt `dist/dagre.min.js` is consumed, by the webview (a browser context), not by the extension host's Node/TypeScript code — so it must not ship inside the VSIX's `node_modules` (confirmed via the packaged VSIX listing: only `@lezer/*` and `yaml`, both genuine runtime dependencies, appear there; `@dagrejs/dagre`'s own `node_modules` entry is correctly absent).
- **Position-only integration, zero rendering-framework change.** Dagre computes node centers and edge waypoints and has no DOM opinion; the existing SVG box/edge-drawing code was reused unchanged by converting dagre's center-point convention to the file's existing top-left-corner convention in one spot (`x: info.x - width/2, y: info.y - height/2`). This is why the diff ended up as one new function plus one new `if` branch in `layout()`, not a rewrite.
- **Scope boundary held under real data.** The screenshot of the focused "Harness" drill-down confirmed the prediction: that view's own-group services have few edges between them, so it was correctly left on the existing grid rather than being swept into the same change.
- **A genuine, non-obvious test-infrastructure gotcha, caught and fixed, not shipped as a bug**: the new webview tests initially failed in a way that looked like dagre wasn't producing a hierarchical layout at all. Root cause: jsdom's `window.eval()` on a `"use strict"` UMD bundle does not leak a top-level `var` to `window` — strict-mode eval (direct or indirect) gets its own variable scope per spec — whereas a real `<script src="...">` tag always executes in the global scope regardless of its own internal strict-mode pragma. This is purely a test-harness mechanic; the production `<script>`-tag approach was never affected. Fixed by having the test harness wrap the vendored script in its own IIFE that explicitly assigns `window.dagre = dagre` from within the same scope, and by polyfilling jsdom's missing `structuredClone` (a real browser global dagre uses internally, absent from jsdom but present in any real Chromium-based webview). Verified the second fact by grepping the vendored bundle for `window.` references (there are none — dagre has zero direct DOM/browser-API coupling beyond the bare `structuredClone` global) before concluding it was test-only.
- **Perf fix scoped to apply everywhere, not just the System view**, since the `O(n²)` pattern (an `Array.find()`/`Array.filter()`/`Array.some()` call inside a per-node or per-edge render loop) existed in the Data view's `project()` too, and the fix (precompute a `Map`/`Set` once per render, O(1) lookups inside the loop) carries zero behavioral risk.

## Changes Made

- `package.json`: `@dagrejs/dagre` devDependency; `build` script extended to run a vendoring step.
- `scripts/copy-vendor.cjs` (new): copies `node_modules/@dagrejs/dagre/dist/dagre.min.js` → `media/vendor/dagre.min.js`, failing loudly if missing.
- `.gitignore`: added `media/vendor/` (generated artifact, same treatment as `dist/`).
- `src/extension.ts`: added a webview-URI-resolved `<script nonce="...">` tag for the vendored dagre file, loaded before `main.js`.
- `media/main.js`: new `dagreLayout(nodes, edges)` helper; `layout()` gains an `edges` parameter and a new `viewMode === 'system' && !focus` branch using it, with a graceful fallback to the old grid if `dagre` isn't defined for any reason; canvas width now derived from actual layout extent instead of a hardcoded `980`; `O(n²)` hot spots fixed in `render()` (edge-label lookups, group member counts) and the Data view's `project()` (join-table exclusion checks) via precomputed `Map`/`Set` lookups.
- `test/webview.test.cjs`: `mount()` now loads the vendored dagre bundle (IIFE-wrapped, with the `structuredClone` polyfill) before `main.js`; two new tests — one asserting the top-level System view ranks a dependent above its dependency (behaviorally distinguishes the new layout from the old fixed-order grid), one asserting the focused drill-down view is unchanged (locks in the deliberate scope boundary).
- `README.md`: status updated.

## Verification

`npm run build` (regenerates `media/vendor/dagre.min.js`), `npm run lint`, and `npm test` (27/27, up from 25) all pass. `ARCHI_TEST_WORKSPACE=/home/shadowe/Projects/HBEC npm run test:extension` passes with unchanged extraction counts (this change touches only `media/` and `extension.ts`'s HTML template, no extractor). `npm run package` produces a VSIX with `media/vendor/dagre.min.js` correctly bundled (48 KB) and `@dagrejs/dagre`'s own `node_modules` correctly absent (devDependency pruning confirmed working as designed). Re-ran the same headless-Chrome visual-testing harness from the Phase 5 work against real HBEC data, before and after: the default System view went from a grid with services and their shared `Infrastructure` database scattered with crossing diagonal edges, to a clear layered diagram — the six service areas cluster at the top, with all their dependency edges flowing down into `Infrastructure` at the bottom — while the focused "Harness" drill-down screenshot confirmed byte-for-byte-equivalent grid behavior (unchanged).

## Follow-ups / Deferred

- Same `dagreLayout` helper applied to the Data view (real FK-direction edges would likely benefit) — separate decision once this is confirmed to hold up in normal use.
- Using dagre's routed multi-point edge waypoints instead of the existing single-quadratic-curve-between-box-edges approach, for better-looking long edges.
- React Flow (or any rendering-framework migration) remains explicitly deferred, not rejected outright — revisit only if a real workspace's graph size makes the hand-rolled SVG renderer itself, not just its layout, the bottleneck.

## References

- `Archi/PHASE5_REVIEW.md` — the immediately preceding work this builds on.
- The approved plan is recorded in this session's Claude Code plan-mode artifact; this report is the durable record of it for future reference.

---

**Completed By:** Tinotendamupezeni (tinotendamupezeni@thuthuka.tech), with Claude Code
**Duration:** Single session
