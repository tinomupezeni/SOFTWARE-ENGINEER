# TESC Complexity Reduction, Hotspot #1: build_queryset (dynamic_service.py)

**Date:** 2026-10-26
**Project:** TESC
**Type:** Refactor
**Status:** Complete, verified against real production data on `tesc-prod`'s `green` color; not cut over to live traffic (separate decision)

## Summary
First of three planned hotspot decompositions (plan: `/home/shadowe/.claude/plans/wobbly-frolicking-crown.md`, approved by user). Decomposed `backend/reports/dynamic_service.py`'s `build_queryset` - the exact function that produced two real bugs earlier today when extended - from one 335-line, complexity-55 function into five small functions, none exceeding complexity 16. Verified behavior-preserving via before/after response diffing against real production data: 10 representative filter combinations across `students`, `scholarships`, and `graduates` report types, all with byte-for-byte identical totals.

## Context / Trigger
Follow-up to `TESC-2026-10-26-complexity-identification-guide-25.md`. User asked for a plan to reduce complexity in the identified hotspots, then approved a 3-hotspot, one-at-a-time plan (`build_queryset` first, since it already had an incident history; `bulk_create_from_file` second; `student_views.py`'s `get_queryset` third).

## Scope
**In scope:** `build_queryset` only, per the approved plan's explicit sequencing (one hotspot, fully verified, before starting the next).

**Out of scope (per plan):** `bulk_create_from_file`, `get_queryset`, the two-parallel-reporting-engines architectural question, and frontend hotspots - all deferred to their own phases.

## Method
Read the full function (lines 26-361) to map its actual structure before touching anything: base queryset setup → a `students`/`graduates`-specific custom-filter block (~10 special cases) → a `placements`/`scholarships`/`mobility`-specific block (1 special case) → a generic per-field loop dispatching by schema-declared type. Captured a characterization baseline (10 real filter-combination requests against the live `green` backend, recording exact `total` counts) before making any change, per the plan's verification section and the guide's own safe-refactor methodology (characterization tests before restructuring).

## Decisions & Findings
Extracted, in order of application, with no logic changes - only relocation:
- `_apply_student_graduate_filters(queryset, filters)` - the students/graduates custom-filter block (search, current_enrollment, has_specialized_skills, has_critical_skills, program__category, inclusivity, is_iseop, is_work_for_fees, year_of_study). Preserved the exact mix of `.pop()` vs `.get()` calls on `filters` as-is, even though it looks slightly inconsistent (e.g. `has_specialized_skills` isn't popped while `is_iseop` is) - per Fowler's refactoring definition the guide cites, this pass preserves existing behavior exactly, including any quirks; it does not also fix unrelated inconsistencies.
- `_apply_related_student_filters(queryset, filters)` - the placements/scholarships/mobility current_enrollment handling.
- `_apply_generic_field_filters(queryset, filters, report_type, user)` - the per-field loop's control flow (program_category OR-logic, institution_id security/relation-path handling, schema-field resolution).
- `_coerce_field_into_kwargs(filter_kwargs, field_type, actual_key, value)` - the boolean/choice/relation/number/date/string type-dispatch that was inline inside the per-field loop, pulled out as its own leaf function once `_apply_generic_field_filters` was still at complexity 28 after the first extraction pass (per the plan's "check after each step, split further only if needed" instruction rather than pre-emptively over-decomposing).
- `build_queryset` itself is now a short orchestrator: base setup → call the report-type-appropriate custom-filter function → call the generic field-filter function → return.

Also removed two `print(f"DEBUG BUILD_QUERYSET: ...")` statements - stdout noise, confirmed not part of the function's observable behavior (its return value) via the before/after diff, not removed on assumption alone.

**Complexity results (`ruff check --select C901`):**
| Function | Complexity |
|---|---|
| `build_queryset` (before) | 55 (one function, 335 lines) |
| `build_queryset` (after) | 14 |
| `_apply_student_graduate_filters` | 14 |
| `_apply_related_student_filters` | not flagged (<10) |
| `_apply_generic_field_filters` | 13 |
| `_coerce_field_into_kwargs` | 16 |

Worst single function dropped from 55 to 16 - a 71% reduction in the single highest score, with the added benefit that each piece is independently nameable, readable, and unit-testable, directly addressing the root cause of both of today's earlier bugs (an unrelated statement 90+ lines away silently affecting behavior via Python's function-wide scoping, and a new filter being added in one place without the reviewer noticing it needed registering elsewhere).

## Changes Made
TESC `staging`/`main` commit `2c932da`. Deployed to `tesc-prod`'s `green` color (image `tesc-backend-green:2c932da`), `.sha_green` updated. Not cut over to live traffic.

## Verification
- `ruff check --select C901` confirms the complexity drop above.
- `python3 -m pytest tests/test_bluegreen_deployment.py tests/test_expand_contract_gate.py` - 19/19 pass (no regression in the unrelated blue-green/migration-gate test suite).
- **Before/after response diff against real production data** (the decisive check): 10 filter combinations across `students`/`scholarships`/`graduates` report types, run against `green` both before and after the refactor, via a real superuser JWT through the actual `/api/v1/reports/dynamic/generate/` endpoint (not a unit test in isolation) - every single `total` count matched exactly:

  | Case | Before | After |
  |---|---|---|
  | students, no filter | 85,509 | 85,509 |
  | students, current_enrollment | 62,912 | 62,912 |
  | students, is_iseop | 0 | 0 |
  | students, has_specialized_skills | 10,291 | 10,291 |
  | students, has_critical_skills | 23,030 | 23,030 |
  | students, inclusivity | 1,356 | 1,356 |
  | students, program__category=STEM | 41,077 | 41,077 |
  | scholarships, current_enrollment+status+gender | 378 | 378 |
  | scholarships, no filter | 534 | 534 |
  | graduates, program_category=STEM | 11,858 | 11,858 |

- Also found a pre-existing bootstrap-marker safety issue (`active_color` had drifted to say "green" when "blue" was actually live - see companion bug log `TESC-2026-10-26-stale-active-color-marker-pointed-at-live-color.md`) as a pre-flight check before this deploy, not a symptom of this refactor.

## Follow-ups / Deferred
1. Proceeding to hotspot #2 (`bulk_create_from_file`, complexity 111) pending a quick check-in with the user, given its substantially larger scope (783 lines, real bulk-upload data-ingestion logic) versus this first, well-contained hotspot.
2. `build_queryset` itself still sits at complexity 14 (above the 10 threshold) - acceptable per the plan's "verify after each change, don't over-decompose" principle; a short orchestrator function naturally has one branch per report-type path plus the filters-truthy check, which is inherent to its dispatching job rather than accidental complexity.

## References
- `/home/shadowe/.claude/plans/wobbly-frolicking-crown.md` - the approved 3-hotspot plan this report executes phase 1 of.
- `reports/TESC-2026-10-26-complexity-identification-guide-25.md` - the identification pass that found this hotspot.
- `Backend_and_API/TESC-2026-10-26-scholarships-schema-gap-and-Q-scoping-bug.md` - the two real bugs this exact function produced earlier today, cited as the motivating incident history.

---

**Completed By:** Claude Sonnet 5 (session with tinomupezeni)
