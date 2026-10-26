# TESC Complexity Reduction, Hotspot #2: bulk_create_from_file (student_services.py)

**Date:** 2026-10-26
**Project:** TESC
**Type:** Refactor
**Status:** Complete, verified against real database writes on `tesc-prod`'s `green` color via a disposable test institution; not cut over to live traffic

## Summary
Second of three planned hotspot decompositions. Decomposed `backend/academic/services/student_services.py`'s `bulk_create_from_file` - the single worst complexity score in the entire codebase (111) - from one 783-line function into an orchestrator plus 7 named stages. Took a deliberately **more conservative** approach than hotspot #1, given this function's materially different risk profile: real student-record creation/update logic dense with incident-specific business rules, two internal preview/approval gates, and actual database writes in a commit loop.

## Context / Trigger
Phase 2 of the approved plan (`/home/shadowe/.claude/plans/wobbly-frolicking-crown.md`), following hotspot #1 (`build_queryset`, see companion report).

## Scope
**In scope:** `bulk_create_from_file` only.

**Explicitly not finely decomposed, by deliberate choice:** the per-row validation loop and the per-row commit loop. Both were extracted as single named units (`_parse_rows`, `_commit_rows`) rather than split into sub-functions, because reading the full function before touching it revealed this is where nearly all the hard-won, institution-incident-specific business rules live (the code itself has comments naming real past institutions - "Bondolfi", "Bulawayo", "United" - whose actual upload files motivated each specific rule). Splitting dense, rule-heavy logic this far into a session without the ability to exhaustively re-verify every historical edge case carries a real risk of silently dropping one of these rules. The complexity-score benefit of finer splitting did not outweigh that risk at this pass.

## Method
Read the entire 783-line function before writing any code (not just the complexity-flagged region) to map its actual pipeline shape: read file → build reference caches → detect Excel fill-down years → per-row validation loop (builds `rows_to_process` + records errors) → match existing students by National ID → dedupe claimed students → filter mixed/filled-down new program codes → approval gate (new programs) → approval gate (existing-student conflicts) → create missing programs → per-row commit loop → build result dict. Confirmed two internal early-return "preview" gates exist (`requires_approval: True` with no DB writes) - these turned out to be directly useful for safe, non-destructive verification.

Rather than relying on a unit test fixture, built and ran a live verification script against real database writes, scoped to a uniquely-tagged disposable test institution (created, exercised, and fully deleted within the same script) - the same pattern the project's own `smoke_test_student_bulk_upload_flow.py` already uses for safe bulk-upload testing. Explicitly asked the user for authorization before running it, since writing to the shared database (even in an isolated, self-cleaning scope) is a different risk class than hotspot #1's read-only diffing.

## Decisions & Findings
Extracted, in pipeline order:
- `_build_reference_caches(institution_id)` - faculty/department/program lookup caches, lookalike-code and name indexes.
- `_build_valid_value_maps()` - the free-text-to-canonical lookup tables (grade, dropout reason, status, work area, inclusivity category, semester).
- `_detect_filled_down_years(df)` - the Excel-fill-down enrolment-year heuristic.
- `_parse_rows(...)` - the per-row validation loop, kept as one unit (see Scope).
- `_match_and_dedupe_existing_students(rows_to_process, institution_id, record_error)` - National ID matching + claimed-student dedup.
- `_filter_mixed_and_filled_down_program_codes(...)` - the two new-program-code sanity checks.
- `_create_missing_programs(...)` - faculty/department/program auto-creation.
- `_commit_rows(...)` - the per-row DB commit loop, kept as one unit (see Scope).
- `bulk_create_from_file` - now a short orchestrator calling the above in sequence, still containing the two approval-gate early returns (these stay in the orchestrator since they're genuinely top-level control flow, not a separable stage).

`_record_error`/`_extract_row_data` closures stayed defined once in the orchestrator (they need to mutate its `errors`/`error_rows_data` lists) and are passed as callables into whichever extracted stage needs them, rather than being duplicated or turned into instance state.

**Complexity results (`ruff check --select C901`):**
| Function | Complexity |
|---|---|
| `bulk_create_from_file` (before) | 111 (one function, 783 lines) |
| `bulk_create_from_file` (after, orchestrator) | 13 |
| `_parse_rows` | 43 (deliberately not split further) |
| `_commit_rows` | 20 (deliberately not split further) |
| `_filter_mixed_and_filled_down_program_codes` | 17 |
| `_match_and_dedupe_existing_students` | 11 |
| `_build_reference_caches` / `_build_valid_value_maps` / `_detect_filled_down_years` / `_create_missing_programs` | not flagged (<10) |

Worst single score dropped from 111 to 43 - a 61% reduction, smaller than hotspot #1's 71% because of the deliberate decision not to split the two densest sections. The orchestrator itself is now trivially readable at complexity 13, down from 111.

## Changes Made
TESC `staging`/`main` commit `3711dc7`. Deployed to `tesc-prod`'s `green` color (image `tesc-backend-green:3711dc7`), `.sha_green` updated. Not cut over to live traffic.

## Verification
- `ruff check --select C901` confirms the complexity numbers above.
- `python3 -m pytest tests/test_bluegreen_deployment.py tests/test_expand_contract_gate.py` - 19/19 pass.
- **Real database-write diff test** (the decisive check, run with explicit user authorization given the write risk): a script creating a uniquely-tagged disposable test institution/faculty/department/program, then exercising `bulk_create_from_file` through 3 scenarios, run on `green` both before and after the refactor:

  | Scenario | Before | After |
  |---|---|---|
  | Clean 2-row upload, existing program | `requires_approval=False, count=2, error_count=0, db_student_count=2` | identical |
  | Row referencing a brand-new program code | `requires_approval=True`, new program details returned, **db_student_count_unchanged=2** (zero writes) | identical (zero writes confirmed again) |
  | 2 rows, one missing a required field | `count=1, error_count=1`, exact error message `"Student ID ...-04: Last Name is required."` | identical |

  Every result matched exactly (only the test's own random UUID tag differed between runs, as expected). Critically, the new-program approval-gate scenario confirmed **zero database writes** both before and after - the function's most important safety property (never silently creating programs/students without explicit confirmation) held through the refactor. The test institution and all its data were deleted at the end of each run; nothing was left behind in the shared database.

## Follow-ups / Deferred
1. Proceeding to hotspot #3 (`student_views.py`'s `get_queryset`, complexity 22) - the lowest-risk and smallest of the three, last in the plan's sequencing specifically so the diff-testing process was already validated on the two harder cases first.
2. `_parse_rows` (43) and `_commit_rows` (20) remain above the usual complexity threshold - explicitly flagged as a deliberate, risk-based tradeoff rather than an oversight. A future pass with more time budget to re-verify every embedded business rule individually could split these further; not recommended as a quick follow-up given the stakes.
3. `staff/services/staff_services.py`'s own `bulk_create_from_file` (complexity 21, noted in the identification report as a possible shared-logic candidate) remains unexamined - still deferred per the original plan's scope.

## References
- `/home/shadowe/.claude/plans/wobbly-frolicking-crown.md` - the approved 3-hotspot plan.
- `reports/TESC-2026-10-26-complexity-reduction-hotspot-1-build-queryset.md` - phase 1 of this same plan.
- `reports/TESC-2026-10-26-complexity-identification-guide-25.md` - the identification pass that found this hotspot.

---

**Completed By:** Claude Sonnet 5 (session with tinomupezeni)
