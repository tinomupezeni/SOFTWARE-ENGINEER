# TESC Complexity Reduction, Hotspot #3: get_queryset (student_views.py)

**Date:** 2026-10-26
**Project:** TESC
**Type:** Refactor
**Status:** Complete, verified against real production data on `tesc-prod`'s `green` color; not cut over to live traffic

## Summary
Third and final hotspot of the approved plan. Decomposed `StudentViewSet.get_queryset`'s flat filter chain (complexity 22) into a small dispatch table. The lowest-risk of the three hotspots, as planned - each filter was already independent and order-insensitive (Django ANDs every `.filter()` call regardless of application order), so this was closer to a mechanical transformation than hotspots #1-2's more careful logic extraction.

## Context / Trigger
Phase 3 (final) of `/home/shadowe/.claude/plans/wobbly-frolicking-crown.md`, done last specifically so the diff-testing process was already validated on the two harder hotspots first.

## Method
Read the current function fresh (it had been edited several times earlier this session for the Current Enrollment feature) to confirm its exact present shape before touching it: `select_related` setup → ISEOP-vs-regular-students branching (depends on `self.action`, not a query param - kept inline) → `program_id`/`institution_id` (each can arrive under either of two param names - kept as direct pre-loop reads) → 15 single-query-param filters, each independent → a final `.annotate()` for fee totals.

## Decisions & Findings
Extracted the 15 independent filters into `_apply_flat_student_filters(queryset, params, enrollment_filters)`: a `(param_name, requires_enrollment_filters, handler)` table applied in a loop. A few filters needed small named handler functions rather than a one-line lambda (`status`'s extra Graduated-year check, `year_of_study`'s computed year conversion, `current_enrollment`'s value check); the rest are inline lambdas. `program_id`/`institution_id` stayed as direct reads in `get_queryset` itself - their two-name-aliasing doesn't fit the single-param dispatch shape cleanly, and leaving them as 2 simple lines added negligible complexity.

**Complexity results (`ruff check --select C901`):**
| Function | Complexity |
|---|---|
| `get_queryset` (before) | 22 (one function) |
| `get_queryset` (after) | not flagged at all (<10) |
| `_apply_flat_student_filters` | 16 |

## Changes Made
TESC `staging`/`main` commit `c6bac5c`. Deployed to `tesc-prod`'s `green` color (image `tesc-backend-green:c6bac5c`), `.sha_green` updated. Not cut over to live traffic.

## Verification
- `ruff check --select C901` confirms the numbers above.
- `python3 -m pytest tests/test_bluegreen_deployment.py tests/test_expand_contract_gate.py` - 19/19 pass.
- **Real HTTP response diff** against production data: 15 cases covering every dispatched filter plus a combination case, run against `/api/academic/students/` on `green` before and after, via a real superuser JWT:

  | Filter | Before | After |
  |---|---|---|
  | no filter | 85,509 | 85,509 |
  | status=Active | 61,278 | 61,278 |
  | status=Graduated | 19,831 | 19,831 |
  | gender=Female | 46,841 | 46,841 |
  | institution_type=Polytechnic | 42,838 | 42,838 |
  | year_of_study=1 | 34,976 | 34,976 |
  | current_enrollment=true | 62,912 | 62,912 |
  | has_specialized_skills=true | 10,291 | 10,291 |
  | on_attachment=true | 6,162 | 6,162 |
  | has_critical_skills=true | 23,030 | 23,030 |
  | program__category=STEM | 41,077 | 41,077 |
  | inclusivity=true | 1,356 | 1,356 |
  | search=MUTARE | 14 | 14 |
  | is_iseop=true | 1,386 | 1,386 |
  | combo (status+gender+current_enrollment) | 31,596 | 31,596 |

  Every count matched exactly.

## All three hotspots: final summary
| Hotspot | File | Before | After (worst function) | Reduction |
|---|---|---|---|---|
| #1 `build_queryset` | `reports/dynamic_service.py` | 55 | 16 | 71% |
| #2 `bulk_create_from_file` | `academic/services/student_services.py` | 111 | 43 (deliberately not split further) | 61% |
| #3 `get_queryset` | `academic/app_views/student_views.py` | 22 | 16 | 27% (but the orchestrator itself is now unflagged) |

All three verified behavior-preserving via real request/response diffing against production data (read-only for #1 and #3, a disposable self-cleaning test institution for #2's real writes) - not unit tests in isolation, and not code review alone. All three deployed to `tesc-prod`'s `green` color; none cut over to live traffic, which remains a separate decision.

## Follow-ups / Deferred
1. Whether/when to cut `green` over to live traffic - this now includes the full Current Enrollment feature, Facilities/Scholarships work, the clutter-audit cleanup, and all three complexity reductions from today, none of which have reached real users yet.
2. The two-parallel-reporting-engines architectural duplication (flagged in the original identification report) remains deferred - out of scope for this function-level plan.
3. Frontend hotspots (`AddStudentDialog.tsx`, `inst/Students.tsx`) were never addressed - no complexity tool was run against them, only size+churn.
4. `_parse_rows` (43) and `_commit_rows` (20) in hotspot #2 remain above the usual threshold by deliberate choice - a legitimate target for a future, more cautious pass if there's ever a need to touch that logic again anyway.

## References
- `/home/shadowe/.claude/plans/wobbly-frolicking-crown.md` - the approved plan, now fully executed.
- `reports/TESC-2026-10-26-complexity-reduction-hotspot-1-build-queryset.md`, `reports/TESC-2026-10-26-complexity-reduction-hotspot-2-bulk-create-from-file.md` - phases 1-2.
- `reports/TESC-2026-10-26-complexity-identification-guide-25.md` - the identification pass that found all three hotspots.

---

**Completed By:** Claude Sonnet 5 (session with tinomupezeni)
