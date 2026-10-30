# componentWorkspace.ts reported graph node count as "files scanned"

**Date:** 2026-10-30
**Project:** Archi
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary

`ComponentAnalysis.files` (the route/task extractor's "how many files did I read" field, parallel to the Compose and model extractors' own `files` counts) was actually set to `nodes.length` — the number of graph nodes produced, not files read. It was unused in the shipped UI (a dead field), so no user-visible impact, but it would have misled a new benchmark script built in the same session, and any future code trusting it.

## Symptoms

- `components.files` returned 423 for HBEC when the actual number of `urls.py`/`tasks.py`/`views.py` files read was 84.
- Caught while writing `test/benchmark.ts`, when the reported "files examined" total for HBEC (598, nodes-inflated) looked implausibly high next to the Compose (1) and data-map (79, correct) counts for the same run.

## Environment Details

- **Server/Host:** N/A — local static analysis, VS Code extension host.
- **Services Affected:** `src/componentWorkspace.ts`'s `ComponentAnalysis.files` field; nothing downstream consumed it before this session.
- **Related Components:** `resolveRoutes`/`resolveTasks` (both returned only `{ nodes, edges }` with no file count of their own).
- **Time First Observed:** While building the Phase 6 benchmark script.

## Investigation Steps

### 1. Initial Diagnosis

The benchmark's HBEC totals didn't add up: 164 files expected (1 Compose + 79 model + ~84 route/task), but the raw `files` sum from the three analyzers came to 598 — exactly matching the *node* count, not a file count.

### 2. Root Cause Analysis

```bash
grep -n "files:" src/componentWorkspace.ts
# return { graph: { version: 1, nodes, edges }, diagnostics, files: nodes.length };
```

A direct copy-paste/placeholder value from early development that was never replaced once routes and tasks were separated into their own resolver functions, each of which already tracked (internally, but didn't expose) how many files it touched.

### 3. Key Findings

- `resolveRoutes` already maintains a `visited` `Set` of module file paths internally (for include-cycle prevention) — its size is exactly the files-read count, just never returned.
- `resolveTasks` already builds a `found` `Map` of task/view file URIs — its size is exactly the files-scanned count, just never returned.
- Both had everything needed to report an accurate count; the bug was only in not surfacing it.

## Root Cause

A placeholder (`nodes.length`) was never replaced with a real measurement once the actual per-resolver file-tracking data existed, and nothing downstream exercised the field enough to surface the mismatch until a benchmark was built that actually summed and printed it.

## Prevention / Rule

**Guardrail:** A field whose name describes a measurement (`files`, `count`, `duration`, etc.) must have a unit test asserting a *plausible relationship* to other known-correct numbers from the same run (e.g., `files < nodes` when a extractor produces multiple nodes per file, or `files <= filesOnDisk`), not just that it's a non-negative number. A bound like "this count must be less than that other count" catches a nodes-instead-of-files swap that a bare `assert.ok(x > 0)` would not.

## Solution

### Immediate Fix

`resolveRoutes` and `resolveTasks` now return `{ nodes, edges, files }` / `{ nodes, files }` respectively (`files` = `visited.size` / `found.size`), and `analyzeComponentWorkspaces` sums both into the real `ComponentAnalysis.files`. The previously-dead field is now also surfaced in the diagram's subtitle bar (`N routes/tasks`), so it has a real consumer.

### Long-term Fix

None needed; a regression test (`test/extension.test.ts`) now asserts `components.files > 0 && components.files < components.graph.nodes.length` against real HBEC data — a relationship that is false under the old `nodes.length` placeholder and true under the fix.

## Prevention

- [x] Code changes required (done, see above)
- [x] Documentation to update — `Archi/PHASE6_REVIEW.md` records this
- [ ] Configuration changes needed — N/A
- [ ] Monitoring/alerts to add — N/A

## Related Issues

- Found while building the benchmark described in `reports/ARCHI-2026-10-30-phase6-quality-and-distribution.md`.

## References

- `src/componentWorkspace.ts` — the fix.
- `test/extension.test.ts`, `test/benchmark.ts` — the regression guard and the tool that caught it.

---

**Resolved By:** Tinotendamupezeni (tinotendamupezeni@thuthuka.tech), with Claude Code
**Time to Resolution:** Same session, caught before any release.
