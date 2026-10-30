# Phase 4: unified navigation and useful abstraction

**Date:** 2026-10-30
**Project:** Archi (source-backed VS Code architecture diagrams)
**Type:** Feature implementation (phased plan milestone)
**Status:** Completed

## Summary

Implemented Phase 4 of Archi's implementation plan: linking the previously
separate system map (Compose services) and data map (Django/SQLAlchemy
models) into one navigable journey, with user view preferences (hidden
nodes, renamed labels, pinned positions, active filters/view mode)
persisted outside the generated fact graph, a node-budget warning instead
of silent truncation, and a coverage/diagnostic summary line. Validated on
the HBEC read-only pilot workspace; all 17 unit/webview tests and the
extension-host HBEC integration test pass.

## Context / Trigger

Archi's own `IMPLEMENTATION_PLAN.md` phases the build 0→6, each with an
exit gate validated against the HBEC pilot workspace. Phases 0–3 (tool
comparison, graph foundation, system map, data map) were already complete
and reviewed (`PHASE2_REVIEW.md`, `PHASE3_REVIEW.md`). The user asked to
proceed to Phase 4, whose own exit gate is explicit: "A fresh HBEC user
can complete the system-to-table journey without manually matching names
across two diagrams. Reanalysis preserves presentation choices; changing
source updates facts without overwriting those choices."

## Scope

**Included:** cross-view navigation (system service ↔ its owned data,
breadcrumb + Back), view-preference persistence (`.archi/views/default.json`,
hidden nodes, renamed labels, pinned/dragged positions, active
relation/data-mode/owner/app/zoom/view-mode filters), a node-budget warning
banner for the default system view, and a coverage summary line
(node/edge/unresolved/skipped counts) derived from existing diagnostics.

**Excluded:** a dedicated multi-section diagnostics *panel* beyond the
existing list plus a coverage line, and multi-root workspace ownership
disambiguation. HBEC — the only available validation target — does not
exercise multiple workspace folders with colliding service names, so
building that disambiguation UI now would be speculative; it's recorded as
a deferred follow-up rather than built against an assumed shape.

## Method

Read the full existing codebase (`src/*.ts`, `media/main.js`, `media/style.css`,
all tests) before changing anything, to keep the new work consistent with
the established patterns: typed evidence graph, confidence levels, stable
IDs, and a vanilla-SVG webview with no framework. Split the new
view-state logic into a pure, unit-testable module (`src/viewState.ts`:
types + `sanitizeViewState`, no `vscode` import) and a thin I/O module
(`src/viewStateStore.ts`: `loadViewState`/`saveViewState`, imports `vscode`)
so the pure logic could be tested with plain `node --test` without pulling
in the extension host — this split was necessary after an initial
single-file version broke the plain-Node test run (`vscode` module not
resolvable outside the extension host).

Treated the webview's incoming `saveView` message as untrusted input and
re-sanitized it server-side before writing to disk, mirroring the existing
`openSource` message validation pattern already in `extension.ts`.

## Decisions & Findings

- Cross-navigation is driven by an existing, already-reliable join key:
  `dataGraph` nodes' `owner` field already equals the owning system-map
  service's `label` (set in `modelWorkspace.ts`'s `ownerFor`). No new
  extraction or ID scheme was needed — the "Explore data" / "Open in
  system map" actions are pure client-side lookups against graphs already
  sent to the webview.
- View state is sanitized on both read and write boundaries (file content
  is attacker-adjacent only in the sense that it's user-writable JSON; the
  webview message is the more important boundary since it's attacker-model
  equivalent to the existing `openSource` message handling) and capped
  (2000 entries per map, 80-char label cap, ±5000 coordinate clamp) to
  bound storage/message size.
- Facts vs. presentation stayed strictly separated: `ViewState` never
  contains a node or edge, only IDs, labels, and numbers referencing the
  always-regenerated graph. Reanalysis loads the same file before
  rendering, so source changes update facts without discarding the user's
  hidden/renamed/pinned choices (an orphaned ID is simply inert, see
  Follow-ups).
- A hard 60-node budget was added only as a warning banner, not a filter,
  per the plan's explicit "offer expansion instead of silently hiding
  facts" requirement — the existing grouping already keeps HBEC's default
  view under this budget, so the banner is an honest guard against a future
  large or ungrouped workspace rather than a response to a current problem.

## Changes Made

- `src/viewState.ts` (new): `ViewState` type, `defaultViewState`,
  `sanitizeViewState`.
- `src/viewStateStore.ts` (new): `loadViewState`/`saveViewState` against
  `.archi/views/default.json`.
- `src/extension.ts`: load/pass/save view state; `coverage()` helper for
  the summary line; new `back`/`breadcrumbs`/`coverage`/`unhide`/
  `budget-warning` elements in the webview HTML; `saveView` message
  handling with a larger, separate size cap (`MAX_VIEW_MESSAGE_BYTES`).
- `media/main.js`: breadcrumb stack and `navigateToData`/`navigateToSystem`/
  `goBack`; hide/rename/pin controls wired into `inspectNode`; pointer-based
  drag-to-pin; debounced `saveView` posting; node-budget banner; coverage
  text rendering; view-state restoration on the `graph` message (including
  `mode` to restore the last-active view).
- `media/style.css`: styling for the new coverage line, breadcrumb nav,
  budget warning, and pinned-node indicator.
- `test/viewState.test.ts` (new, 3 tests): `sanitizeViewState` well-formed
  input, malformed/malicious input, and pinned-map clamping/capping.
- `test/webview.test.cjs`: updated the two existing tests' HTML fixtures
  for the new elements; added 3 tests covering the full Explore-data →
  Open-in-system-map → Back round trip, hide/unhide with a verified
  `saveView` post, and `ViewState` restoration from an incoming `graph`
  message.
- `package.json`: added `dist/test/viewState.test.js` to the `test` script.
- `.gitignore`: added `.archi/` so dev-time use of the extension against
  its own repo doesn't stage personal view state.
- `README.md`, `IMPLEMENTATION_PLAN.md`: status updated to reflect Phase 4
  completion.
- `PHASE4_REVIEW.md` (new, in the Archi repo): phase exit-gate review,
  mirroring the existing `PHASE2_REVIEW.md`/`PHASE3_REVIEW.md` format.

## Verification

`npm run build`, `npm run lint`, and `npm test` (17/17 passing, up from 11)
all pass. `ARCHI_TEST_WORKSPACE=/home/shadowe/Projects/HBEC npm run
test:extension` passes and reproduces Phase 3's unchanged HBEC extraction
counts (79 model files, 138 data nodes, 148 graph edges), confirming this
phase changed presentation/navigation only. Confirmed no `.archi/`
directory was left behind in the read-only HBEC workspace after the
integration run (it only writes on an interactive `saveView` message,
which the headless integration test doesn't send).

## Follow-ups / Deferred

- A dedicated multi-section diagnostics panel (separate unresolved/
  skipped/coverage sub-lists, vs. today's single list plus a summary line)
  if a future workspace's diagnostic volume makes the flat list hard to
  scan.
- Multi-root ownership disambiguation (prefixing an owner/service label
  with its workspace-folder name) once a real multi-root target surfaces
  colliding service names — not built speculatively against HBEC, which is
  single-root.
- Pruning orphaned `ViewState` entries (hidden/renamed/pinned IDs for
  nodes no longer produced by extraction) is not implemented; they are
  inert but accumulate in `.archi/views/default.json` over time.
- `PLAN.md`'s open decision #3 (commit `.archi/views/` per-project vs.
  user-storage-only) remains open; Phase 4 implements the plan's stated
  default (workspace file) without resolving the broader policy question.

## References

- `Archi/IMPLEMENTATION_PLAN.md` — phase definitions and exit gates.
- `Archi/PHASE2_REVIEW.md`, `Archi/PHASE3_REVIEW.md` — prior phase reviews,
  same format followed here.
- `Archi/PHASE4_REVIEW.md` — this phase's own review, Archi-repo-local.

---

**Completed By:** Tinotendamupezeni (tinotendamupezeni@thuthuka.tech), with Claude Code
**Duration:** Single session
