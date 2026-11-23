# HBEC Pull Requests #168–#175 — Merged to `experimental`

**Date:** 2026-11-23
**Project:** HBEC
**Type:** Audit (merge follow-through to the 2026-11-23 code review batch)
**Status:** Completed

## Summary
Following the code review of all nine open HBEC PRs (see `reports/HBEC-2026-11-23-pr-168-to-176-review-batch.md`), merged the eight PRs confirmed clean — either no bugs found, or bugs found and already fixed on the branch — into `experimental` (each PR's actual base branch; `master` is the separate deploy branch per `Project_Memory/HBEC/MAIN.md`). PR #176 was excluded: it is an explicit draft with real, author-disclosed regressions, correctly not ready to merge.

## Context / Trigger
User asked to merge the PRs confirmed clean from the prior review batch. Clarified with the user whether "clean" meant zero-finding PRs only or also PRs where a bug had been found and fixed — confirmed the latter (all of #168–#175, excluding draft #176).

## Scope
**In scope:** merging PRs #168, #169, #170, #171, #172, #173, #174, #175 into their common base branch `experimental`, resolving any merge conflicts that arose as each PR branch fell behind `experimental` after the prior merges in the same sequence.
**Out of scope:** PR #176 (left open, draft, not ready — see prior review report); promoting `experimental` to `master` (a separate, later step per this repo's blue/green deploy process, not part of this pass); re-running the frontend test suites for real (flagged as a standing follow-up in the review report, environment-limited during review).

## Method
Checked each PR's `mergeable`/`mergeStateStatus` via `gh pr view` before each merge (not assumed from the pre-review snapshot, since merging earlier PRs in the sequence could and did make later ones conflict against the now-advanced `experimental`). Merged in PR-number order via `gh pr merge <n> --merge`. Where GitHub reported `CONFLICTING`, checked out the PR's own branch locally, merged `origin/experimental` into it, resolved the conflict in the working tree, pushed the resolved merge commit back to the PR's branch (so GitHub's own mergeability check cleared, rather than merging around GitHub), then ran `gh pr merge` again.

## Decisions & Findings

### Merge order and conflicts
Merged in order #168, #169, #170, #171, #172, #173, #174, #175. Every PR from #169 onward conflicted against `experimental` by the time its turn came, in one or both of two always-append-only files that most of these PRs also touch:

- `research/long_term_memory.md` — a dated append-only project changelog. Every conflict was two sides each appending a new dated entry at the same tail position; resolved by keeping both entries, no information lost.
- `contracts/question-diagrams/fixtures.json` — the shared question-diagram contract's test-fixture file. Three of the eight merges (#171, #172, #173) conflicted here because multiple PRs each append new fixture objects (or, for #173, new `picture_items` entries plus a sibling PR's new `zimbabwe_map_ids` key) at the same JSON array/object insertion point. These required care beyond blind text concatenation: git's conflict markers did not include the shared closing braces each side's new content needed, so a naive append produced invalid JSON on the first attempt for #171 (caught immediately by `python3 -c "import json; json.load(...)"` before pushing — the file was corrected to close each JSON object/array explicitly rather than trusting the textual diff boundaries). Every resolution was verified by parsing the file as JSON and confirming no duplicate fixture `name` values before pushing.
- `research/semantic/index.md` (one additional conflict on #174) — same append-only-list pattern as `long_term_memory.md`, resolved the same way.

No conflict touched application code; every conflict was in a shared documentation/changelog or shared test-fixture file that multiple parallel PRs happened to append to at the same point. The code-level content of each PR (including the bug fixes from the prior review pass) was verified to survive each merge untouched — specifically re-checked that PR #173's prompt-leak fix (`PICTURE_NAMES` vs `PICTURE_ITEMS` in `prompts.py`) auto-merged cleanly and was still present after the merge with `experimental`.

### Merge commit map
| PR | Branch | Final merge commit on `experimental` |
|---|---|---|
| #168 | `research/visual-sources-survey` | `76488e64c` |
| #169 | `feat/whiteboard-sketch` | (merged after conflict resolution, pushed update `ad99ca3aa`) |
| #170 | `feat/diagram-statistics` | `d7ee1df29` (branch update `c88117984`) |
| #171 | `feat/diagram-constructions` | `d111c56e3` (branch update `0b13fc2de`) |
| #172 | `feat/diagram-zimbabwe-map` | `590bd46b2` (branch update `883011346`) |
| #173 | `feat/picture-kit-heritage` | `09695b956` (branch update `e59ea3bdc`) |
| #174 | `chore/dead-code-audit` | `58618a096` (branch update `e11ac4870`) |
| #175 | `feat/drop-pymupdf` | `cd70a053e` (clean, no conflict by its turn) |

## Changes Made
8 PR merges to `origin/experimental` (Rest-creator/HBEC), each carrying a merge commit and, where a conflict was found, one additional "update" commit on the PR's own branch resolving it against `experimental` before the final merge. No PR was squashed; the repo's existing merge-commit convention was followed. Temporary local git branches used to resolve conflicts (`feat-diagram-statistics-update` and five siblings) were deleted after use; none were pushed as new branches beyond updating the original PR branch.

## Verification
- `mergeStateStatus: CLEAN` / `mergeable: MERGEABLE` confirmed via `gh pr view` immediately before each `gh pr merge` call.
- Every `contracts/question-diagrams/fixtures.json` resolution was parsed with `python3 -c "import json; json.load(...)"` before pushing, and checked for duplicate fixture names.
- PR #173's prompt-leak fix was re-grepped in `AGENTIC_HARNESS/app/exam_practice/prompts.py` after its merge with `experimental` to confirm it survived the auto-merge.
- Did not run the frontend/backend test suites for real in this pass (same environment limitation noted in the prior review report) — this remains an open follow-up before `experimental` is next promoted to `master`.

## Follow-ups / Deferred
- Run the real test suites (frontend vitest, harness pytest) against the updated `experimental` tip before its next promotion to `master`, since CI itself remains blocked repo-wide (billing, since 2026-10-05) and none of today's merges were CI-verified.
- PR #176 (admin half of the PyMuPDF removal) remains open and in draft, with its two disclosed blocking regressions (a regex that doesn't match PDFium's rendering of the competency-matrix heading, and a pdfplumber sort-order difference from PyMuPDF) still unresolved — not part of this merge pass.
- `experimental` is now 8 PRs ahead of where it was at session start; `master`'s own promotion is a separate, later decision per this repo's blue/green process, not assumed here.

## References
- `reports/HBEC-2026-11-23-pr-168-to-176-review-batch.md` (the review this merge pass follows)
- `Project_Memory/HBEC/MAIN.md`

---

**Completed By:** Claude Sonnet 5
**Duration:** ~25 minutes
