# HBEC Pull Requests #168–#176 — Code Review Batch

**Date:** 2026-11-23
**Project:** HBEC
**Type:** Audit (code review, no merges)
**Status:** Completed

## Summary
Reviewed all nine open HBEC pull requests (#168–#176, all opened by `winstonjthinker` 2 days prior, none with any existing PR review or CI check — CI is blocked repo-wide since 2026-10-05 per Project Memory, not a defect of these PRs specifically) using the `code-review` skill at medium effort. Found and fixed 6 real correctness bugs across 5 PRs, pushed each fix directly to its PR branch, and posted PR comments flagging 6 architecture/owner-decision items without fixing them. No PR was merged — merging was out of scope for this pass.

## Context / Trigger
User asked to go through all nine open PRs using the code-review skill, fix bugs directly, leave architecture-affecting decisions for owner review via PR comment, and check existing PR messages (there were effectively none beyond author self-notes).

## Scope
**In scope:** the full diff of each of the nine PRs, read against the real source (not just PR descriptions), using isolated git worktrees per PR to allow parallel review without collision.
**Out of scope:** merging any PR, CI (blocked repo-wide, unrelated to this review), rebasing #176 onto #175 (branches currently overlap on the files #175 already converted; left as a known merge-order item for whoever merges them).

## Method
Grouped the nine PRs into five parallel review agents by theme (closely related PRs reviewed together so the overlap in context wasn't wasted):
1. #175 + #176 — PyMuPDF removal (harness half, admin half).
2. #174 — dead-code audit.
3. #168 + #169 — visual-sources survey + whiteboard hand-drawn sketching.
4. #170 + #171 + #172 — new diagram kinds (statistics, constructions, Zimbabwe map).
5. #173 — picture-kit additions.

Each agent set up its own git worktree(s) off the PR's remote branch, loaded the `code-review` skill, read the actual diff and the surrounding source it touches (not just the PR body), classified every finding as either a correctness bug (fixed directly, committed, and pushed to the PR's own branch) or an architecture/owner-decision matter (left as a single consolidated `gh pr comment`, not fixed). Findings were reported back to the coordinating session rather than logged directly, so bug-log entries and the Project Memory update could be written centrally and consistently.

## Decisions & Findings

### Bugs found and fixed (6, across 5 PRs)
1. **PR #174** — dead-code audit removed `AGENTIC_HARNESS/app/shared/guardrails/hallucination.py` as unreferenced; it's actually called by `technology/audit_probes.py`, invisible to the audit's in-package import graph. Restored. See `Backend_and_API/HBEC-2026-11-23-dead-code-audit-removed-still-used-module.md`.
2. **PR #175** — two seed scripts (`export_syllabi.py`, `extract_syllabus_topics.py`) still imported `fitz` after PyMuPDF was removed from the harness's dependencies; would `ModuleNotFoundError` on next run. Converted to `pdfplumber`. See `Backend_and_API/HBEC-2026-11-23-pymupdf-removal-left-fitz-imports-in-seed-scripts.md`.
3. **PR #173** — the girl/boy/child exclusion from the question-generation catalogue was an unenforced accident (no test), **and** the generation system prompt was already leaking those names to the LLM via the wrong source tuple (`PICTURE_ITEMS` instead of `PICTURE_NAMES`), defeating the whole point of the exclusion. Both fixed; a regression test added. See `Backend_and_API/HBEC-2026-11-23-picture-kit-exclusion-leaks-into-llm-prompt.md`.
4. **PR #170** — pie-chart's 4-tone fill cycle repeats at sector counts that wrap the cycle (e.g. 5 sectors), making the first and last (circularly adjacent) sectors share a tone — defeats the diagram's own "neighbours part even in greyscale" guarantee. Fixed. See `Frontend_and_UI/HBEC-2026-11-23-pie-chart-adjacent-sector-tone-collision.md`.
5. **PR #171** — triangle angle-label default position collides with an `angle_bisector` construction targeting the same vertex (both derive from the identical direction vector); the PR had already fixed the analogous side-label/perpendicular-bisector case but missed this one. Fixed. See `Frontend_and_UI/HBEC-2026-11-23-construction-angle-label-collides-with-bisector.md`.

(#168 and #169 had no bugs — both PRs' core claims were independently verified true: the Remotion replacement in #168 is real and wired in, not dead scaffold, and its license-audit claims check out; #169's label/fill/arrowhead-preservation and determinism claims for hand-drawn sketching all held up against the actual code and existing tests.)

### Architecture/owner-decision items left as PR comments (not fixed)
- **#168** (https://github.com/Rest-creator/HBEC/pull/168#issuecomment-7094466864): this PR conflates the research survey document with an actual production pipeline swap (clean-room Remotion replacement); asked for the timing/scope of adoption to be confirmed separately from the survey itself.
- **#169** (https://github.com/Rest-creator/HBEC/pull/169#issuecomment-7094469611): rough.js wobble constants (`roughness`/`bowing`/`maxRandomnessOffset`) are hardcoded; flagged as a future per-diagram-tuning question, not a defect.
- **#173** (https://github.com/Rest-creator/HBEC/pull/173#issuecomment-7059219541, `#issuecomment-7094479616`, `#issuecomment-7094505412`): scope/granularity of batching 13 unrelated items plus the first skin-tone figures into one PR; whether skin-tone variants should extend to other existing catalogue person-figures; and a follow-up documenting bug #3 above once found.
- **#174** (https://github.com/Rest-creator/HBEC/pull/174#issuecomment-7094501286): the admin "Guardrails" settings UI's docstring claims config is "reloaded via `get_settings()`" but it actually only logs — a user-facing correctness gap recommended for higher-priority owner attention than the audit's other five flagged items; also suggested deciding `content_filter.py` + `hallucination.py` wiring together now that the latter is confirmed still in use.
- **#175** (https://github.com/Rest-creator/HBEC/pull/175#issuecomment-7094570764): `pdf_reader.py`'s `get_text("dict")` always returns one flattened text block, unlike PyMuPDF's real multi-block/paragraph grouping — currently a no-op (no consumer uses block boundaries yet) but flagged for a future multi-column syllabus case.
- **#176** (no comment needed — the PR's own description already discloses its two blocking gaps precisely, correctly left as draft/not-ready; restating them would have been redundant).

### Nothing requiring a comment or fix on #172
The Zimbabwe-map diagram's fixed-list safety guarantee was verified enforced server-side in both Python validator copies (ADMIN serializer, harness whiteboard script, AI-generation quality gate), independent of the TS type — no gap found.

## Changes Made
6 commits across 5 branches, all pushed to their respective PR branches on `Rest-creator/HBEC` (no merges):
- `feat/drop-pymupdf` — `e5d907bb6`
- `chore/dead-code-audit` — `d7155ef44`
- `feat/picture-kit-heritage` — `4f9aecf60`, `14da7b8e2`, `97b13cd2c`
- `feat/diagram-statistics` — `2078d8748`
- `feat/diagram-constructions` — `6424d73e9`

5 new dev-log entries in `SOFTWARE-ENGINEER` (3 under `Backend_and_API/`, 2 under `Frontend_and_UI/`, listed above).

## Verification
Each reviewing agent verified its own fix against the existing test suite where one existed and was runnable in the review worktree (pie-chart's own vitest suite could not be run — `node_modules` not installed in that worktree; flagged as a follow-up, not a blocker, since the fix itself is a one-line tone-index change verified by hand-tracing the cycle). No fix was merged to `master`/`experimental`; all live only on their PR's own branch pending the PR author/owner's normal merge process.

## Follow-ups / Deferred
- Run the frontend test suites for real (`diagrams.test.tsx` etc.) in the actual HBEC dev environment, not a throwaway worktree, to confirm the pie-chart and construction fixes pass the project's real CI-equivalent checks once CI is unblocked.
- PR #176 still needs rebasing onto #175 before merge (currently touches files #175 already converted) — a normal merge-order item, not a defect.
- The six architecture/owner-decision PR comments above are all awaiting the PR author's or project owner's response — no further action from this review pass.
- Consider whether the `dead-code-audit` skill/tooling should be hardened to whole-repo-grep every removal candidate by default, per the guardrail recorded in the #174 bug-log entry.

## References
- `Backend_and_API/HBEC-2026-11-23-dead-code-audit-removed-still-used-module.md`
- `Backend_and_API/HBEC-2026-11-23-pymupdf-removal-left-fitz-imports-in-seed-scripts.md`
- `Backend_and_API/HBEC-2026-11-23-picture-kit-exclusion-leaks-into-llm-prompt.md`
- `Frontend_and_UI/HBEC-2026-11-23-pie-chart-adjacent-sector-tone-collision.md`
- `Frontend_and_UI/HBEC-2026-11-23-construction-angle-label-collides-with-bisector.md`
- `Project_Memory/HBEC/MAIN.md`

---

**Completed By:** Claude Sonnet 5 (5 parallel code-review subagents + coordinator)
**Duration:** ~35 minutes wall-clock (parallel), ~455k subagent tokens total
