# Curriculum Sync Failure & Frontend Sticky Cache Bug

**Date:** 2026-07-14
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
The student platform showed 0 available subjects and incorrectly defaulted to Cambridge IGCSE, despite the student's profile correctly identifying them as a ZIMSEC student. This was caused by a compound issue: an admin backend outbox sync that marked ZIMSEC as inactive, combined with a React frontend bug that blindly fell back to stale `localStorage` data without validating it.

## Symptoms
- The student's "Exam Practice" page showed "IGCSE" and "CAMBRIDGE".
- The page showed "No subjects added yet" because there were 0 subjects in the DB for Cambridge IGCSE.
- The Admin dashboard showed "1 Exam Boards: 0 active, 1 draft" for ZIMSEC.

## Environment Details
- **Server/Host:** hbec-vps
- **Services Affected:** `hbec-admin-backend`, `hbec-student-backend`, `STUDENT Frontend`
- **Related Components:** Outbox replication (Kafka/Redis), React `useLevelPreference` hook
- **Time First Observed:** 2026-07-14 07:18

## Investigation Steps

### 1. Initial Diagnosis
Investigated why `/api/curriculum/subjects/?level=igcse` returned an empty list. Checked the `hbec-student-backend` DB and found 0 subjects for IGCSE, and only 2 exam boards (`CAMBRIDGE` active, `ZIMSEC` inactive).

### 2. Root Cause Analysis
Investigated the admin backend database and found that ZIMSEC was the ONLY exam board, but its status was `draft`. The admin outbox replicates "draft" boards as `is_active=False` to the student backend. Because ZIMSEC was inactive on the student side, the student frontend fell back to an orphaned `CAMBRIDGE` record left over from development.

Further frontend analysis revealed a bug in `useLevelPreference.ts`:
```typescript
if (prev.examBoardCode) return prev; // BUG: Never validates if the cached board still exists!
```
Because the user's browser had `CAMBRIDGE` cached in `localStorage`, the UI forced the display to Cambridge IGCSE, completely bypassing the actual student profile preferences.

### 3. Key Findings
- Admin backend had ZIMSEC marked as "draft".
- Outbox replication successfully (but destructively) replicated ZIMSEC as inactive to the student DB.
- The student backend still had a ghost `CAMBRIDGE` record.
- The React hook `useLevelPreference` failed to validate `localStorage` against active boards.

## Root Cause
A combination of misconfigured admin data (ZIMSEC as draft) interacting with a frontend validation bug that caused it to cling to a deleted/orphaned `CAMBRIDGE` record from `localStorage`.

## Solution

### Immediate Fix
1. Activated ZIMSEC in the admin backend database, which triggered an outbox sync to the student backend.
2. Deleted the orphaned `CAMBRIDGE` record from the student backend database.

```bash
# Admin DB fix
docker exec hbec-admin-backend python manage.py shell -c 'from apps.exam_boards.models import ExamBoard; z = ExamBoard.objects.get(code="ZIMSEC"); z.status = "active"; z.save()'

# Student DB fix
docker exec hbec-student-backend python manage.py shell -c 'from apps.curriculum.models import ExamBoard; ExamBoard.objects.filter(code="CAMBRIDGE").delete()'
```

### Long-term Fix
Modified `useLevelPreference.ts` in the React frontend to strictly validate `localStorage` preferences against the newly fetched list of active exam boards.

```typescript
const validCodes = new Set(resp.data.map((b) => b.code));
if (prev.examBoardCode && validCodes.has(prev.examBoardCode)) return prev;
```

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required: Patched `useLevelPreference.ts`.

## Related Issues
- Related to July 1 subject filtering bug (`2026-07-01-subject-filtering-bug.md`).

## References
- None

---

**Resolved By:** Antigravity Agent
**Time to Resolution:** 15 minutes
