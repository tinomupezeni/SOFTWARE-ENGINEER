# Missing Harness Question IDs in Practice Papers

**Date:** 2026-10-09
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
AI-generated practice papers in the student backend were being created without saving the `harness_question_id`. As a result, the student frontend fell back to using the student database's internal integer `id` for marking requests. When the frontend attempted to mark questions, the harness backend returned 404 "Question not found" because it was receiving the wrong ID.

## Symptoms
- Students experienced 404 errors when attempting to mark AI practice papers.
- Error logs showed: `POST https://student.hbca.tech/harness-stream/api/v1/exam-practice/papers/.../questions/<uuid>/worked-solution 404 (Not Found)`
- The `<uuid>` in the URL was actually the student backend's `id`, not the `harness_question_id`.

## Environment Details
- **Server/Host:** hbca-vps
- **Services Affected:** Student Backend, Harness Backend
- **Related Components:** `apps.practice.models.PaperQuestion`

## Investigation Steps

### 1. Initial Diagnosis
- The bug was traced to the `SyncPaperView` in `STUDENT/hbec_backend/apps/internal/views.py`, which correctly synced `harness_paper_id` but neglected to save `harness_question_id`.

### 2. Root Cause Analysis
- The code bug was fixed in `SyncPaperView`.
- However, ~16,000 existing `practice_paperquestion` rows still lacked `harness_question_id`.
- Re-syncing the papers entirely would delete the old rows and create new ones with new internal `id`s, breaking existing student sessions (which store progress in `localStorage` keyed by `id`).

## Root Cause
The sync logic from the Harness DB to the Student DB was incomplete. It did not capture `harness_question_id` for questions, resulting in existing records missing this crucial foreign key reference.

## Prevention / Rule
**Guardrail:** Enforce a `NOT NULL` constraint on `harness_question_id` for `practice_paperquestion` once all data is migrated.

Ensuring DB-level constraints on required foreign identifiers prevents silently falling back to local IDs and ensures data integrity during sync operations.

## Solution

### Immediate Fix
- Fixed the `SyncPaperView` to save `harness_question_id` for newly synced papers.
- Deployed the fix via Blue-Green deployment to the `green` stack on production.

### Long-term Fix
- Performed an inline data migration on the live database. We queried the correct `harness_question_id` from the Harness DB based on `harness_paper_id` and `order_index`, dumped it to a CSV, and then ran a Django shell script to update the 16,976 missing rows in the Student DB.

```bash
docker exec -i hbec-student-backend-green python manage.py shell -c "import csv; from apps.practice.models import PaperQuestion; ..."
```

## Prevention
- [x] Code changes required
- [x] Configuration changes needed

---

**Resolved By:** Antigravity
**Time to Resolution:** 30m
