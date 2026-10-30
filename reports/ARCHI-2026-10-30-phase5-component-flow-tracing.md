# Phase 5: component and request-flow tracing

**Date:** 2026-10-30
**Project:** Archi (source-backed VS Code architecture diagrams)
**Type:** Feature implementation (phased plan milestone)
**Status:** Completed

## Summary

Implemented Phase 5 of Archi's implementation plan: a new **Flows** view that statically resolves each Django service's declared HTTP routes (composing the central `urls.py` router with each `include()`d app module) and Celery tasks (linking `@shared_task`/`@app.task` definitions to their `.delay()`/`.apply_async()` trigger sites), scoped per service and fully source-linked. Validated end-to-end against the real HBEC pilot workspace — 423 component nodes, 363 edges, only 3 honest diagnostics (all genuine static-analysis limits, not bugs). A real correctness bug was found and fixed during the work (see the linked bug-log entry) before any release.

## Context / Trigger

Archi's `IMPLEMENTATION_PLAN.md` phases the build 0→6 against HBEC exit gates. Phase 4 (unified system/data navigation) was complete and reviewed. The user asked to proceed to "next phase" / "proceed," which is Phase 5 per the plan's own dependency order (`P4 → MVP → P5`). The MVP VSIX-packaging gate was attempted first in the same session (see Changes Made) but the manual GUI click-through could not be completed from this environment and was handed back to the user as pending, rather than blocking Phase 5 work.

## Scope

**Included:** Django route resolution (two-pass `urls.py` composition with recursive `include()` following, depth-limited), Celery task/trigger linking (both task-decorator forms, both call methods), a new Flows view in the webview generalizing the existing cross-navigation (Explore/Open-in-system-map/Back) to a third mode, and a reproducible `npm run package` script plus `.vscodeignore` for the VSIX step.

**Excluded, with reasoning:** JS/TS client-call extraction (resolving a frontend `fetch`/`axios` call to a specific backend path) was investigated against a real HBEC example (`STUDENT/Frontend/src/features/auth/services/authService.ts` calling `/auth/login/`) and found real and traceable, but was deferred rather than built with regex, since doing it properly — consistent with the project's "prefer AST/parser to broad regex" rule — needs a JS/TS parser dependency the project doesn't yet have (`@lezer/javascript`), which is a larger addition than this phase's scope. The phase's exit gate (one HTTP path, one event/queue path, through supported layers, with honest gaps) is still met without it, because the pre-existing Compose-level service-to-service HTTP edges from Phase 2 already carry the frontend-to-backend hop at the system-map level; the new route list adds the specific endpoint detail. A full cross-workspace call graph was also explicitly not built, per the plan's own instruction to build "focused route and event views, not a full-workspace call graph."

## Method

Before writing any parser code, delegated a research pass (a subagent reading HBEC read-only) to find concrete, real examples of each pattern to be extracted: a Django `urls.py` central-router + per-app composition, a frontend API call and its base-URL configuration, and a Celery task definition plus its call site — with exact file:line citations. This grounded every parser design decision in real syntax rather than assumed syntax, and surfaced a genuine edge case up front (HBEC's `accounts` app splits its URLs across four separately-included modules at different prefixes, and some Celery tasks use an explicit `name=` kwarg instead of relying on the decorated function's symbol name) that shaped the parser's design from the start rather than being discovered as a late bug.

Before writing the actual Python-tree-walking logic, probed `@lezer/python`'s concrete parse-tree shapes for both URL-pattern calls and decorated-function/call-site syntax with small throwaway Node scripts, rather than guessing node names from the Phase 3 parser's patterns — this caught the exact `DecoratedStatement`/`Decorator`/`FunctionDefinition` shape and the fact that a decorator's own call arguments (e.g. `@shared_task(name=...)`) sit directly on the `Decorator` node, not wrapped in a nested `CallExpression` the way a normal function call's arguments would be.

Split new logic into pure, vscode-independent parser modules (`pythonRoutes.ts`, `pythonTasks.ts`) plus a vscode-dependent orchestration module (`componentWorkspace.ts`), mirroring the existing `pythonModels.ts`/`modelWorkspace.ts` split — this keeps the parsers unit-testable with plain `node --test` and was a lesson already learned and applied from the Phase 4 `viewState.ts`/`viewStateStore.ts` split (a single-file version there had broken the plain-Node test run by importing `vscode` at module scope).

## Decisions & Findings

- **Graph shape for "who triggers this task."** Rather than modeling a call site as its own graph node with a `triggers` edge to the task (which would need a synthetic node with no real identity of its own), a task node's `evidence` array holds both its definition location and every matched trigger-site location. This keeps every node in the graph a real, named thing, and reuses the existing generic "open source evidence" UI without new graph-edge plumbing.
- **Unresolved call targets are diagnostics, not fabricated edges**, following the same precedent Phase 3 set for unresolved Django/SQLAlchemy relationship targets (e.g. `ContentGapReport.subject_id`). A `.delay()` call whose object symbol doesn't match any known task becomes a diagnostic string, never a phantom edge to a non-existent node.
- **Route composition depth-limited to 4** to bound recursion against a pathological or cyclic `include()` chain, with a `visited` set per service to prevent infinite loops on an actual cycle.
- **Shared Python-AST helpers exported, not duplicated.** `pythonModels.ts`'s tree-walking primitives (`slice`, `children`, `callName`, `literal`, `firstArgument`, `keyword`, `findCalls`, `appFromPath`, `lineOf`) were exported and reused by both new parsers rather than re-implemented, since they're the same `@lezer/python`-tree operations already built and tested in Phase 3.
- **MVP VSIX packaging attempted but not completed end-to-end.** `@vscode/vsce` was added as a devDependency, a `.vscodeignore` was written (trims the package from 340 files/536 KB including devDependencies to 300 files/480 KB of only runtime code + the three production dependencies), and `npm run package` now reproduces this. Installing the VSIX and opening a visible VS Code desktop window to do the plan's required manual click-through failed in this environment — `code --install-extension` silently didn't register the extension, and a GPU-process crash in the sandboxed session blocked an actual GUI window — so this was handed back to the user as a pending manual step rather than claimed as done.

## Changes Made

- `src/pythonRoutes.ts` (new): pure Django `urls.py` parser — `parseUrlModule`, `joinRoutePath`, `appFromModulePath`, `modulePathToRelativeFile`.
- `src/pythonTasks.ts` (new): pure Celery parser — `parseCeleryFile` (task definitions + `.delay()`/`.apply_async()` call sites).
- `src/componentWorkspace.ts` (new): workspace orchestration — `analyzeComponentWorkspaces`, resolving routes (recursive `include()` following) and tasks (file discovery, symbol matching) per service, producing a `route`/`task`/service-stub graph.
- `src/pythonModels.ts`: exported previously-private AST helper functions for reuse (no behavior change).
- `src/graph.ts`: added `route`/`task` to `NodeKind`; added optional `view`/`symbol` fields to `GraphNode`.
- `src/extension.ts`: runs component analysis after model analysis, caches `archi.lastComponentGraph`, threads it through `showGraph`/webview messaging/coverage calculation, adds the "Flows" option to the view-mode selector.
- `media/main.js`: generalized the Phase 4 cross-navigation (`navigateToOwnerView`/`navigateToSystem`/`goBack`/breadcrumbs) from two modes to three; added the Flows `project()`/`layout()` branches, route/task detail rendering, and node styling.
- `media/style.css`: route/task node border colors.
- `.vscodeignore` (new), `package.json` (`package` script, `@vscode/vsce` devDependency, new test files wired into `test`).
- `test/pythonRoutes.test.ts`, `test/pythonTasks.test.ts` (new, 7 tests): pure-parser unit tests grounded in real HBEC syntax shapes.
- `test/webview.test.cjs`: updated HTML fixtures for the third view-mode option; added a Flows-view round-trip test.
- `test/extension.test.ts`: added direct HBEC assertions on the new extractors (the student-login route and the password-reset Celery task, both with working source navigation).
- `README.md`, `IMPLEMENTATION_PLAN.md`: status updated; `IMPLEMENTATION_PLAN.md` also records the MVP packaging gate's partial (automated-only) completion.
- `PHASE5_REVIEW.md` (new, in the Archi repo): phase exit-gate review, mirroring `PHASE2_REVIEW.md`–`PHASE4_REVIEW.md`'s format.

## Verification

`npm run build`, `npm run lint`, and `npm test` (25/25 passing, up from 17) all pass. `ARCHI_TEST_WORKSPACE=/home/shadowe/Projects/HBEC npm run test:extension` passes and prints `HBEC data map: 79 files, 138 data nodes, 148 graph edges` (Phase 3/4 counts unchanged, confirming no regression) and `HBEC components: 423 nodes, 363 edges, 3 diagnostics`; all 3 diagnostics were individually inspected and confirmed to be genuine static-analysis limits (a DRF router's dynamically generated URLs, and two services including the third-party `django_prometheus.urls` package, which is outside the workspace), not bugs.

## Follow-ups / Deferred

- JS/TS client-call extraction (frontend `fetch`/`axios` call → specific backend route), deferred pending a JS/TS parser dependency decision — see Scope above.
- The MVP release gate's manual desktop click-through in a real VS Code GUI window is still pending the user's own confirmation; the automated packaging side is done and reproducible via `npm run package`.
- No app-level scoping or kind (routes-only / tasks-only) filter was added to the Flows view, unlike the Data view's app filter — deferred until a workspace's per-service route/task count makes that filtering useful; HBEC's per-service counts did not demonstrate the need during validation.

## References

- `Archi/IMPLEMENTATION_PLAN.md` — phase definitions and exit gates.
- `Archi/PHASE2_REVIEW.md` – `Archi/PHASE4_REVIEW.md` — prior phase reviews, same format followed here.
- `Archi/PHASE5_REVIEW.md` — this phase's own review, Archi-repo-local.
- `Backend_and_API/ARCHI-2026-10-30-route-path-trailing-slash-dropped.md` — the bug found and fixed during this work.

---

**Completed By:** Tinotendamupezeni (tinotendamupezeni@thuthuka.tech), with Claude Code
**Duration:** Single session
