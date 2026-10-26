# TESC Complexity Identification (Guide 25's Complexity Taxonomy + Metrics)

**Date:** 2026-10-26
**Project:** TESC
**Type:** Audit
**Status:** Identification complete; no changes made — this is a prioritization input, not an action list

## Summary
Applied `25. Continuous Codebase Simplification.md`'s complexity-recognition tools (the Forms of Complexity taxonomy, the maintainability-metrics table, and specifically its "change coupling"/"frequently modified complex hotspots" guidance — which the guide names as the single most damaging complexity pattern) to the TESC backend and frontend. Used `ruff`'s McCabe cyclomatic-complexity check (already installed in this environment, no new tooling needed) plus `git log` churn history as the two independent evidence sources the guide recommends combining. Found one function at 11x the "should refactor" threshold, and confirmed with direct, dated evidence from this very session that the guide's hotspot theory holds here: the one function this session had to extend twice produced two real production bugs.

## Context / Trigger
Follow-up to the earlier clutter audit (`TESC-2026-10-26-codebase-clutter-audit-guide-25.md`, which covered dead/redundant *files*). User asked whether the guide also covers recognizing complexity and establishing simplicity rules; after explaining the guide's actual position (complexity-recognition: yes, in depth; fixed numeric "simplicity rules": explicitly rejected as scientifically indefensible, replaced with a risk-tiered evidence framework), the user asked to apply that recognition framework to TESC directly.

## Scope
**In scope:** structural/cyclomatic complexity (McCabe, via `ruff --select C901`) and code churn (`git log --name-only` frequency) across `backend/`, `frontend/src/`, and `inst/src/`, combined per the guide's explicit recommendation ("Change coupling... Excellent prioritization evidence when paired with static structure"). Also checked for architectural duplication (parallel systems solving the same problem).

**Out of scope:** cognitive-complexity scoring (no SonarQube-class tool available in this environment), dependency-graph/propagation-cost analysis (would need a proper call-graph tool), and a full intra-function readability review of every flagged hit - this pass ranks and surfaces candidates, consistent with the guide's own instruction that metrics are "a ranking signal; never sufficient for removal" (or, here, for refactor-worthiness) on their own.

## Method
`ruff check backend/ --select C901` for McCabe complexity (ruff was already installed; no `radon` or other tool needed - this is exactly the guide's "Where is deterministic automation strongest?" answer: linters/complexity rules are cheap, reproducible, low-setup). `git log --format="" --name-only -- <dir> | sort | uniq -c | sort -rn` for churn, across the full project history (not just this session). Cross-referenced the two: the guide's own research-questions table states plainly that "frequently modified complex hotspots" are more damaging than either high complexity or high churn alone, so the intersection is the headline finding, not either list independently.

## Decisions & Findings

### 1. The clearest hotspot: complexity and churn point at the exact same three files
| File | Lines | Commits touching it (all-time) | Worst function(s) flagged (McCabe, threshold 10) |
|---|---|---|---|
| `backend/academic/app_views/student_views.py` | 1,542 | **59** (highest in backend) | `get_queryset` 22, `gender_data_quality_import` 15, `bulk_upload` 13 |
| `backend/academic/services/student_services.py` | 1,160 | 39 | **`bulk_create_from_file` 111** - the single highest complexity score in the entire codebase, over 11x the threshold |
| `backend/reports/dynamic_service.py` | 694 | 24 | `build_queryset` 55, `generate_report_data` 17 |

This is not a theoretical concern for this project specifically. `dynamic_service.py`'s `build_queryset` is the exact function this session extended twice (to add the `current_enrollment` filter across report types) and hit **two real production bugs** doing it: a missing-schema-field 400 and a `Q`-variable scoping `UnboundLocalError` 500 (`Backend_and_API/TESC-2026-10-26-scholarships-schema-gap-and-Q-scoping-bug.md`). Both bugs were latent *before* this session's changes - the function's size and branching (55 independent paths) made it easy to add a new `report_type` branch without noticing it would interact badly with code 90 lines away. This is a direct, dated, in-project instance of the guide's own claim that architectural complexity correlates with bug-fix burden, not a generic literature citation.

`student_views.py`'s `get_queryset` (complexity 22) is the same function this session repeatedly extended for the `current_enrollment` filter, the ISEOP filter, and several other flags over its history - the file's 59-commit churn count is the highest of any backend file, and it's the single file most edited across this entire multi-week project by a wide margin.

### 2. The single worst number: `bulk_create_from_file`, complexity 111
`backend/academic/services/student_services.py:377` - a 111-branch function for parsing bulk student upload files. For calibration: ruff's default "should refactor" threshold is 10; SonarQube-class tools typically flag anything over ~15-20 as high-risk and over ~50 as "untestable without an enormous test matrix." At 111, this function has more independent logical paths than most entire small modules. A sibling function, `staff/services/staff_services.py`'s own `bulk_create_from_file` (complexity 21), suggests this "parse a bulk-upload spreadsheet with per-row validation and per-column special-casing" shape recurs across at least two domains (students, staff) as independently-maintained, similarly-complex implementations - worth checking for the "Redundant code" pattern (two similar-shaped bulk-upload functions that might share extractable logic) rather than just flagging each in isolation.

Other `backend/academic/services/ingestion_service.py` functions in the same complexity tier (`validate_upload` 61, `commit_upload` 54) suggest the bulk-ingestion pipeline as a whole, not just one function, carries most of the backend's structural complexity - consistent with it being genuinely complex *domain* logic (many institution types, program categories, data-quality rules) rather than obviously accidental complexity. The guide's own distinction between essential and accidental complexity applies directly here: before treating this as a refactor target, it's worth asking how much of the 111 branches are irreducible business rules (Zimbabwe's specific institution/program/status taxonomy) versus accumulated special-casing that could be data-driven instead of branch-driven.

### 3. Architectural complexity: two parallel reporting engines
`backend/reports/engine.py` (`ReportEngine.execute()`, the newer "Report Studio" semantic engine, schema in `semantic.py`) and `backend/reports/dynamic_service.py` (`DynamicReportService.build_queryset()`/`generate_report_data()`, the older "dynamic reports" engine, schema in `schema_config.py`) solve substantially the same problem - turn a report definition (entity + filters + columns) into a queryset and render it - as two independently-maintained systems with their own filter-mapping logic. This session had to add the same `current_enrollment` filter capability to **both** systems separately (`dynamic_service.py`'s custom-filter block, and `semantic.py`'s field declarations) to make it work for all the pages that needed it. This is the guide's "Architectural clutter" category by name: "Excess services... whose operational cost outweighs required isolation... two services deployed, versioned and changed together." Neither engine is dead (both are live, both were touched this session), so this isn't a removal candidate - it's a consolidation candidate, a materially bigger and riskier undertaking than anything in the earlier clutter audit, flagged here for visibility rather than action.

### 4. Frontend has the same shape, smaller scale
| File | Lines | Commits touching it (all-time) |
|---|---|---|
| `inst/src/components/AddStudentDialog.tsx` | 1,398 (largest frontend file) | 18 |
| `inst/src/pages/Students.tsx` | 860 | **22** (highest churn of any frontend/inst file) |
| `inst/src/components/helpers/UploadStudentsDialog.tsx` | — | 21 |

No equivalent of McCabe complexity was run for TypeScript (no ESLint complexity rule configured in this pass), but the size+churn intersection mirrors the backend pattern closely enough to flag the same way: large, frequently-touched components concentrated around student records and bulk upload, the same domain area driving the backend's worst numbers.

## Changes Made
None. Per the same staged-workflow discipline as the clutter audit, this report identifies and ranks candidates; it does not refactor anything. Refactoring a 111-complexity function that's actively relied on for real student data ingestion is categorically higher-risk than deleting an unreferenced script, and the guide's own risk framework (medium/high tier: "require... integration/build checks... reviewer," "never destructively modify solely from automated/LLM inference" for anything touching real data pipelines) argues for explicit scoping and characterization tests before any restructuring, not an immediate rewrite.

## Verification
`ruff check backend/ --select C901 --line-length 120` run directly against the live repository (29 functions flagged total, full ranked list retained in session output); `git log` churn counts computed against full project history, not a sample. Cross-referenced `dynamic_service.py`'s complexity finding against this session's own two real bug reports as independent confirming evidence, rather than relying on the metric alone - exactly the "don't trust a single complexity score" caution the guide itself gives.

## Follow-ups / Deferred
1. **No action recommended without a scoping decision from the user.** The three backend hotspots are candidates for investigation/possible decomposition, not a queued refactor - each would need characterization tests before any restructuring (per the guide's verification-technique table), given they're load-bearing for real student/staff data operations.
2. If prioritizing one: `dynamic_service.py`'s `build_queryset` has the strongest case for near-term attention, since it has *already* produced two real bugs this session, not just a high score in the abstract.
3. The `bulk_create_from_file` duplication between `academic/services/student_services.py` and `staff/services/staff_services.py` is worth a short investigation into whether shared bulk-upload logic could be extracted - lower urgency than #2 since neither has caused a known incident.
4. The two-reporting-engines architectural finding (§3) is the largest-scope item here and the least appropriate for an ad-hoc fix - would need a deliberate consolidation decision, likely its own project, not a cleanup task.
5. A proper frontend complexity pass (ESLint complexity rule or equivalent) was not run this pass; the size+churn signal alone (§4) is weaker evidence than the backend's McCabe-backed findings.

## References
- `Principal_Engineer/engineering-guides/25. Continuous Codebase Simplification.md` - specifically the "Forms of complexity" table, the "Software Complexity and Maintainability Metrics" table, and the research-questions row "Which complexity is most damaging?"
- `Backend_and_API/TESC-2026-10-26-scholarships-schema-gap-and-Q-scoping-bug.md` - the real, dated bugs this report cites as direct confirming evidence for `dynamic_service.py`'s hotspot status.
- `reports/TESC-2026-10-26-codebase-clutter-audit-guide-25.md` - the companion dead/redundant-file audit this report follows up on.

---

**Completed By:** Claude Sonnet 5 (session with tinomupezeni)
