# Admin topic sharing flattened copied subtopics

**Date:** 2026-10-31
**Project:** HBEC
**Environment:** Production (`hbca-vps`) and local development
**Severity:** High
**Status:** Investigating

## Summary
Sharing a subject's topics to another grade copied some subtopics as root topics. A read-only production audit found 175 flattened copies across six subject-grade combinations. A backend prevention fix is implemented and locally tested, but it has not been deployed and the historical rows remain unchanged.

## Symptoms
- Shared topics appeared jumbled in the target grade's admin topic tree.
- Biology Form 3 had 76 root topics while its linked Form 4 set had 21.
- The affected copies retained their numeric `order` values but lost `parent_id`.

## Environment Details
- **Server/Host:** `hbca-vps`
- **Services Affected:** Admin backend and admin frontend; student replication is downstream.
- **Related Components:** `TopicShareView`, `TopicShareGroup`, topic tree rendering.
- **Time First Observed:** Reported during the 2026-10-31 session.

## Investigation Steps

### 1. Initial Diagnosis
Traced the admin Share Topics modal to `POST /api/curriculum/topics/share/` and compared source and copied topic rows by share group.

### 2. Root Cause Analysis
The backend iterated topics in model order (`order`, `name`) and assigned a copied parent only if the source parent had already been mapped. Children often had smaller order numbers than their parents, so they were copied first with `parent_id = NULL`. The mapping also lived outside the target-grade loop.

```bash
rg -n 'class TopicShareView|old_to_new|parent_id' ADMIN/adminBackend/apps/curriculum/views.py
ssh hbca-vps 'docker exec hbec-postgres psql -X -v ON_ERROR_STOP=1 -U hbec -d hbec_admin -c "BEGIN READ ONLY; SELECT count(*) FROM topics WHERE share_group_id IS NOT NULL; COMMIT;"'
```

### 3. Key Findings
- 343 linked topic pairs had identical order values; 175 pairs differed in root-versus-child status.
- All 175 flattened copies have exactly one matching parent copy in the target subject.
- The read-only repair mapping is saved at `/tmp/hbec-unflatten-dry-run-20261031.csv` (175 unique target IDs).

## Root Cause
Topic sharing used display order as creation order. It did not topologically sort the source hierarchy or resolve an already-shared target parent before creating a child.

## Prevention / Rule
**Guardrail:** The topic-sharing API must create or resolve each selected topic's ancestor chain before the child, with a source-to-target ID map scoped to one target grade. A regression test must assert parent IDs in both persisted rows and the list API response when child order is lower than parent order.

## Solution

### Immediate Fix
The local `TopicShareView` change walks ancestors first, reuses existing parent copies, and starts a fresh ID map for each target grade. Three focused PostgreSQL-backed API tests passed. Production deployment and historical data repair are still pending.

```bash
POSTGRES_PORT=55433 .venv/bin/pytest apps/curriculum/tests/test_topic_share_api.py -q --tb=short
```

### Long-term Fix
Deploy the tested backend change, then run a guarded Django repair using the dry-run mapping and verify admin and student hierarchies.

## Prevention
- [x] Focused hierarchy regression tests added locally.
- [ ] Deploy the backend prevention fix.
- [ ] Repair and verify the 175 existing flattened copies.

## Related Issues
- None recorded.

## References
- `ADMIN/adminBackend/apps/curriculum/views.py`
- `ADMIN/adminBackend/apps/curriculum/tests/test_topic_share_api.py`

---

**Resolved By:** Pending deployment and data repair
**Time to Resolution:** Ongoing
