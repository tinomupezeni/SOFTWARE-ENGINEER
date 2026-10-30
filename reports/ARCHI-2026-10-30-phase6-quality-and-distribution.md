# Phase 6: quality and distribution

**Date:** 2026-10-30
**Project:** Archi (source-backed VS Code architecture diagrams)
**Type:** Feature implementation (phased plan milestone)
**Status:** Mostly completed — one decision explicitly left to the user

## Summary

Implemented Phase 6 of Archi's implementation plan: a cold/warm HBEC benchmark with a stated release budget, an accessibility review that found and fixed a real ARIA-role defect, Mermaid/SVG/PNG diagram export with verified secret-safe labels, and a small self-contained example workspace that doesn't require HBEC. Two real, if minor, bugs were found and fixed during the work (logged separately). The phase's packaging/licensing/Marketplace decision was deliberately left open rather than decided unilaterally, since it's a business/legal choice, not an engineering one.

## Context / Trigger

The user asked to proceed through "next phase" twice this session, landing on Phase 6 (the last phase in `IMPLEMENTATION_PLAN.md` before the MVP release gate's manual confirmation), with the explicit instruction to do Phase 6 now and the manual VS Code desktop click-through afterward.

## Scope

**Included:** all four of Phase 6's "Work" items from the plan — benchmark, accessibility/theme/trust checks, export, and the licensing/packaging decision (surfaced, not resolved) — plus the example workspace named in the export bullet.

**Explicitly not decided here:** whether to add a LICENSE file, and whether Archi moves toward Marketplace publication or stays a private, workspace-local tool. `package.json`'s existing `"publisher": "archi-local"` / `"private": true` already signal the latter, and nothing in this session changed that signal; the decision itself belongs to the user per this repo's own standing rule ("pause execution and verify with the user" before an architecture-scale deviation or choice with real downstream consequences like a license).

## Method

Built the benchmark and the example workspace as real, run-and-measure artifacts rather than documentation-only estimates — the plan explicitly says "optimize only measured bottlenecks," which requires an actual measurement to exist first. For the accessibility review, read through the existing interactive-element markup against the ARIA spec's actual role definitions rather than pattern-matching against a generic accessibility checklist, which is what surfaced the `role="img"` defect (a role chosen by visual analogy, not by checking what that specific role means for a subtree with interactive descendants).

For PNG export — the one capability that is inherently unverifiable in jsdom (no `Image`/`canvas` decoding without a native add-on this project deliberately avoids) — reused the same headless-Chrome visual-testing technique built for Phase 5, extending the harness to poll the webview's own `postMessage` queue and surface the result through the DOM so it could be captured via `--dump-dom`, then actually decoded the resulting base64 PNG and looked at it, rather than trusting a byte count alone.

## Decisions & Findings

- **Benchmark via the real extractors, not a reimplementation.** `test/benchmark.ts` calls `analyzeComposeWorkspaces`/`analyzeModelWorkspaces`/`analyzeComponentWorkspaces` directly inside the extension-host test harness, so the measurement reflects the actual `vscode.workspace.findFiles`/`vscode.workspace.fs` code paths users hit, not an approximation built on Node's own `fs` module (which was good enough for throwaway visual-testing harnesses but would understate real VS Code file-search overhead for a release budget).
- **No optimization work was done**, because none was warranted: 3.8 s cold / 1.6 s warm / ~230 MB RSS for a 164-file, ~600-node workspace is a reasonable baseline, not a measured bottleneck.
- **`role="img"` → `role="group"`** for the canvas SVG root — see the linked bug entry. This is the kind of defect that passes every existing manual click-through (a sighted keyboard user sees nothing wrong) and only surfaces by checking the actual ARIA semantics against the content, which is why it survived five prior phases of otherwise-careful UI work.
- **Secret-safe export verified, not just assumed.** Rather than adding new redaction logic for exports, confirmed the existing Phase 2 `SECRET_KEY` filter in `compose.ts` already guarantees nothing sensitive reaches any node/edge label — and therefore nothing sensitive reaches any export, since every export format is built from exactly what's already rendered on screen. Verified this is still true by tracing the data flow rather than taking it on faith.
- **PNG export needed one CSP relaxation** (`img-src` gains `data:`) to let the webview rasterize its own SVG via an `Image` element — a minimal, scoped change with no network/remote implications, confirmed necessary (not just convenient) by testing the unmodified CSP first and observing the load failure.
- **The example workspace surfaced a test-fixture assumption**, not an extension bug: the shared (non-HBEC-specific) half of `test/extension.test.ts` assumes any `ARCHI_TEST_WORKSPACE` has a `package.json`, true for the only two workspaces this suite had ever been pointed at before. Fixed by giving the example workspace a `package.json`, since that's what a real project would have anyway, rather than weakening the test.

## Changes Made

- `test/benchmark.ts`, `scripts/benchmark.cjs` (new), `package.json` (`benchmark` script): cold/warm HBEC benchmark.
- `src/componentWorkspace.ts`: `resolveRoutes`/`resolveTasks` now return real file counts; `ComponentAnalysis.files` fixed (see linked bug entry); `src/extension.ts`'s subtitle now surfaces the Flows route/task count.
- `media/main.js`: canvas SVG `role="img"` → `role="group"` (see linked bug entry); `aria-live="polite"`/`role="status"` added to the budget-warning banner (`src/extension.ts`'s HTML template, mirrored in the test fixture).
- `media/main.js`, `src/extension.ts`: Mermaid/SVG/PNG export — a new toolbar control, `buildExportSvg`/`buildMermaid`/`svgToPngBase64` in the webview, a new `export` message type handled via `vscode.window.showSaveDialog` + `vscode.workspace.fs.writeFile` in the extension host, with its own message-size cap; one CSP change (`img-src` gains `data:`).
- `examples/sample-workspace/` (new): a minimal Django-shaped Compose + models + routes + Celery-task project, plus its own `README.md`; referenced from the main `README.md`.
- `test/webview.test.cjs`: new accessibility-role regression test; new Mermaid/SVG export test.
- `test/extension.test.ts`: new `components.files` sanity assertion.
- `README.md`, `IMPLEMENTATION_PLAN.md`: status updated.
- `PHASE6_REVIEW.md` (new, in the Archi repo): phase exit-gate review, same format as `PHASE2_REVIEW.md`–`PHASE5_REVIEW.md`.

## Verification

`npm run build`, `npm run lint`, and `npm test` (29/29, up from 27) all pass. `ARCHI_TEST_WORKSPACE=/home/shadowe/Projects/HBEC npm run test:extension` and `ARCHI_TEST_WORKSPACE=examples/sample-workspace npm run test:extension` both pass. `npm run benchmark` runs cleanly against HBEC and produced the numbers in the linked `PHASE6_REVIEW.md` table. `npm run package` still produces a correctly dependency-pruned VSIX (now also bundling `examples/sample-workspace`). PNG export was independently verified by decoding a real exported file from the headless-Chrome harness and visually confirming it matched the on-screen diagram.

## Follow-ups / Deferred

- The licensing/Marketplace/packaging decision — the user's to make.
- JS/TS frontend-call tracing (carried over from Phase 5).
- Applying the dagre hierarchical layout to the Data view (carried over from the earlier "v0.2" layout work).
- The MVP release gate's manual VS Code desktop click-through — still pending the user's own confirmation; this phase's headless-Chrome visual testing is the closest available substitute from this environment, not a replacement for it.

## References

- `Archi/PHASE6_REVIEW.md` — this phase's own review, Archi-repo-local.
- `Archi/PHASE2_REVIEW.md` – `Archi/PHASE5_REVIEW.md` — prior phase reviews, same format.
- `Backend_and_API/ARCHI-2026-10-30-component-analysis-files-count-wrong.md` — bug found and fixed during this work.
- `Frontend_and_UI/ARCHI-2026-10-30-diagram-canvas-role-img-flattened-children.md` — bug found and fixed during this work.

---

**Completed By:** Tinotendamupezeni (tinotendamupezeni@thuthuka.tech), with Claude Code
**Duration:** Single session
