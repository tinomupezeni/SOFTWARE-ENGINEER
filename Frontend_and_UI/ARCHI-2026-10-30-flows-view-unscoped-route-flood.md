# Flows view rendered all of a service's routes as one unscoped, cluttered grid

**Date:** 2026-10-30
**Project:** Archi
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary

Archi's new Flows view (Phase 5, request-flow tracing) let a user pick a service but had no further scoping, unlike the already-shipped Data view which scopes by service *and* app. Against real HBEC data, `student-backend` alone declares 129 routes across many Django apps, so selecting it rendered all 129+ route/task nodes as one flat, alphabetically-sorted grid with a "serves" edge fanning out from an off-screen service node to every one — unreadable, and a direct violation of this phase's own design instruction ("build focused route and event views, not a full-workspace call graph"). Caught only because the work was visually screenshotted against real data rather than judged from code alone.

## Symptoms

- Selecting `student-backend` in the Flows view produced a grid of 148 cards (129 routes + 19 tasks) with dozens of near-parallel edge lines running through it, caused by many "serves" edges from one off-screen node coincidentally crossing a regular grid layout.
- No way to narrow the view by app, even though the Data view already had exactly this control for the equivalent problem (a service can own many models across apps).

## Environment Details

- **Server/Host:** N/A — local static-analysis VS Code extension, webview UI.
- **Services Affected:** Archi's Flows view (`media/main.js`'s `components` view mode).
- **Related Components:** `src/componentWorkspace.ts` (task nodes lacked an `app` field), `media/main.js` (`populateApps`, `project()`, `changeView()`).
- **Time First Observed:** During a dedicated visual-testing pass after Phase 5 implementation, using a headless-Chrome harness fed the real HBEC-extracted graph (not a hand-picked small fixture) — the kind of defect that a 2-3-node unit-test fixture cannot surface, because it only shows up at real-world node counts.

## Investigation Steps

### 1. Initial Diagnosis

A screenshot of the Flows view scoped to `student-backend` showed a dense, hard-to-read grid with many overlapping edge lines.

### 2. Root Cause Analysis

```bash
node -e "
const g = require('./components.json');
console.log(g.nodes.filter(n => n.owner === 'student-backend').length);
"
# -> 148
```

Confirmed `student-backend` genuinely owns 129 routes + 19 tasks — not a bug in the extractor, a real property of that service's API surface. The Flows view's `project()` only filtered by `owner`, with no second filter dimension, unlike the Data view's `owner` + `app` pair.

### 3. Key Findings

- The Data view already solved this exact shape of problem (one service owning many entities across apps) with an app-select control; the Flows view was simply missing the equivalent, not a novel problem needing a novel solution.
- Task nodes (`src/componentWorkspace.ts`) never had an `app` field set, unlike route nodes and model nodes — an oversight from building the task extractor without checking it against the app-scoping pattern the route extractor and the pre-existing model extractor both already followed.
- A secondary, related finding from the same screenshot: drawing a "serves" edge from the owning service to every one of its routes added visual noise without informational value, since the owner is already named in the toolbar — the edges existed because the data model has them (correctly, for evidence/provenance), but rendering all of them in this particular view added nothing a viewer didn't already know.

## Root Cause

The Flows view was built as a new, independent view rather than being checked against the Data view's already-established scoping pattern for "one owner, many entities across apps" — and the defect was invisible to unit tests built around small, hand-picked fixtures (2-3 nodes), only surfacing at the real node counts a live HBEC service actually has.

## Prevention / Rule

**Guardrail:** Any new graph-backed view that scopes by owner/service must be checked against existing views for the same "one owner, many children" shape (here: the Data view's owner+app pattern) before being considered complete, not designed as if it were the first such view. Pair that with testing the view's *rendered* output against realistic, real-data node counts — not only a 2-3-node fixture — before calling a new view done; a hand-picked small fixture structurally validates the code path but cannot surface a density/readability problem that only exists at real scale.

This closes the gap because the Data view's app-scoping was reusable, working precedent sitting in the same file; the miss was not checking for it, not a missing capability.

## Solution

### Immediate Fix

- `src/componentWorkspace.ts`: task nodes now carry an `app` field, derived via the existing `appFromPath` helper (already used for model nodes), from the task's defining file's path.
- `media/main.js`: `populateApps()` now reads from whichever graph (`dataGraph` or `componentGraph`) is active instead of being hardcoded to `dataGraph`; the Flows view's `project()` filters by the selected app; `changeView()` shows the app selector for both Data and Flows modes.
- `media/main.js`: the Flows view no longer renders the owning-service hub node or its "serves" edges — only route/task nodes, since the owner is already shown in the toolbar and the edges added no new information in this view.

### Long-term Fix

None needed beyond the guardrail above; a regression test (`test/webview.test.cjs`) now builds a fixture with two apps on one service and asserts the app filter actually narrows the rendered node set.

## Prevention

- [x] Code changes required (done, see above)
- [x] Documentation to update — `Archi/PHASE5_REVIEW.md` records this as a visual-testing finding
- [ ] Configuration changes needed — N/A
- [ ] Monitoring/alerts to add — N/A (static analysis tool, no runtime to monitor)

## Related Issues

- Found during the same visual-testing pass that is cross-referenced in `reports/ARCHI-2026-10-30-phase5-component-flow-tracing.md` (Phase 5 completion report), alongside the separately-logged `Backend_and_API/ARCHI-2026-10-30-route-path-trailing-slash-dropped.md`.

## References

- `src/componentWorkspace.ts`, `media/main.js` — the fix.
- `test/webview.test.cjs` — the regression test ("the Flows view shows a service's routes and tasks...").
- `Archi/PHASE5_REVIEW.md` — "Visual testing and a scoping fix found by it" section.

---

**Resolved By:** Tinotendamupezeni (tinotendamupezeni@thuthuka.tech), with Claude Code
**Time to Resolution:** Same session, caught before any release.
