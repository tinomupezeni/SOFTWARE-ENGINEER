# AI Paper Marking "Question Not Found" Drift Part 2

**Date:** 2026-10-09
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
The previous fix to inject `harnessQuestionId` into AI-generated practice papers' JSON response failed to resolve the issue for some papers. The backend was attempting to map the JSON question ID (e.g. `"math_q1"` or `"1"`) to the local `PaperQuestion` UUID, which always failed and returned `None`. As a result, the frontend continued to fall back to the internal UUID when communicating with the Harness, resulting in 404s. Furthermore, `harnessPaperId` was completely omitted from the payload, forcing the frontend to fall back to the `Artifact` UUID instead of the Harness-synced `Paper` UUID.

## Symptoms
- AI-generated practice papers still failed to mark for some questions.
- Browser network tab showed 404 "Question Not found" from the Harness.
- The `harnessQuestionId` and `harnessPaperId` were missing from the AI paper payload fetched by the frontend.

## Environment Details
- **Server/Host:** Production (admin.hbca.tech / student frontend)
- **Services Affected:** `student-backend`, `harness`
- **Related Components:** `apps.practice.views._artifact_response`
- **Time First Observed:** 2026-10-09

## Investigation Steps

### 1. Initial Diagnosis
Inspected the code committed in the previous session (`STUDENT/hbec_backend/apps/practice/views.py`).

### 2. Root Cause Analysis
Found that `_artifact_response` attempted to populate `harnessQuestionId` using:
```python
        for db_q in PaperQuestion.objects.filter(paper_id=artifact.id):
            harness_ids[str(db_q.id)] = db_q.harness_question_id
```
and then read it using `q_id` from the JSON artifact:
```python
            q_id = q.get("id", str(idx + 1))
            question_data["harnessQuestionId"] = harness_ids.get(q_id)
```
Because `q_id` is a string like `"1"`, `"2"`, or `"math_q1"`, and `str(db_q.id)` is a UUID, the `.get()` lookup always missed. 
Additionally, `harnessPaperId` was not being mapped from the associated `Paper` record.

### 3. Key Findings
- The `PaperQuestion` model records the original JSON ID (e.g., `"1"`) in its `question_number` field during sync.
- Using `db_q.question_number` as the dictionary key correctly aligns with `q_id` from the Artifact JSON.
- The corresponding `Paper` record contains the correct `harness_paper_id`.

## Root Cause
Type mismatch in dictionary keys (`UUID` vs `String/question_number`) when attempting to join database rows with JSON artifact dictionaries. Missing exposure of `harness_paper_id`.

## Prevention / Rule
**Guardrail:** Ensure that any joins between normalized database models and raw JSON artifacts strictly map on semantically equivalent fields (e.g., `question_number` to JSON `id`), rather than primary keys, as AI-generated artifacts have arbitrary string identifiers.
This ensures that dynamically generated content properly links to its synced database representation.

## Solution

### Immediate Fix
Updated `_artifact_response` in `views.py` to:
1. Lookup the `harness_paper_id` from the synced `Paper`.
2. Map `harnessQuestionId` using `str(db_q.question_number)` in addition to `str(db_q.id)`.
3. Include `harnessPaperId` in the serialized output so the frontend correctly routes requests to the Harness.

### Long-term Fix
Refactor AI papers so they don't serve raw JSON artifacts but instead serve the fully normalized `Paper` and `PaperQuestion` models like regular papers, ensuring a unified API structure and eliminating these manual "stitching" steps.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- Drift between Student DB and Harness DB (from previous log).

---

**Resolved By:** Antigravity
**Time to Resolution:** 30 minutes
