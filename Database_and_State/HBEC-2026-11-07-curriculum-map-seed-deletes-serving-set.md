# Curriculum map reseed deletes serving points before replacement succeeds

**Date:** 2026-11-07
**Project:** HBEC
**Environment:** PR #116 and #113 source review; production not exercised
**Severity:** High
**Status:** Investigating

## Summary
The new `seed_maps` path deletes every existing `clean_room_map` point in Qdrant before the replacement `store_embeddings` call. A failed upsert leaves the serving map set empty. Its deletion helper also catches and suppresses deletion errors, allowing stale removed entries to remain while the new digest is marked seeded.

## Symptoms
- A transient Qdrant write failure after deletion can remove all previously serving maps.
- A suppressed delete failure can leave obsolete map points in retrieval after the seed reports success.
- These are source-derived failure paths; no target-environment fault injection was run.

## Environment Details
- **Server/Host:** PR heads `bc735cb1e` (#116) and `1c96d3057` (#113).
- **Services Affected:** Agentic Harness curriculum retrieval.
- **Related Components:** `app/shared/curriculum_maps.py`, `app/shared/embedding_service.py`, startup seeding.
- **Time First Observed:** 2026-11-07 code review.

## Investigation Steps

### 1. Initial Diagnosis
Read the seed sequence and its tests.

### 2. Root Cause Analysis
`seed_maps` embeds, then calls `delete_by_field`, then `store_embeddings`. Only an embedding failure is covered by the negative test. `delete_by_field` logs and swallows all exceptions.

```bash
git show origin/review-pr-116:AGENTIC_HARNESS/app/shared/curriculum_maps.py
git show origin/review-pr-113:AGENTIC_HARNESS/app/shared/embedding_service.py
```

### 3. Key Findings
- The old set is deleted before replacement points are written.
- The delete helper cannot signal a failed deletion to the seed.
- `seed_on_deploy` records the digest after `seed_maps` returns, so stale points can be marked current.

## Root Cause
The replacement is implemented as separate delete and upsert operations without a safe generation switch or failure-atomic handoff, and the delete operation suppresses errors.

## Prevention / Rule
**Guardrail:** A seed integration test must inject failures at delete and upsert, then assert that the previous generation remains queryable and the digest is not advanced. This verifies the state transition rather than only an embedding precondition.

## Solution

### Immediate Fix
Pending on the PR branches; review recommendation is to block merge until the serving set cannot disappear on a failed write.

```bash
# No fix applied in this read-only review.
```

### Long-term Fix
Stage replacement points under a new generation and switch readers after verification, or use a collection alias/generation protocol that preserves the old set until the new set is complete. Propagate deletion errors and test recovery from partial writes.

## Prevention
- [ ] Add fault-injection tests for delete/upsert failures.
- [ ] Implement a safe generation switch and explicit delete failure propagation.
- [ ] Verify a real Qdrant replacement and rollback journey before deployment.

## Related Issues
- PR #116; inherited unchanged by PR #113.

## References
- `AGENTIC_HARNESS/app/shared/curriculum_maps.py` in PR #116, lines 149–179.
- `AGENTIC_HARNESS/app/shared/embedding_service.py` in PR #113, lines 398–431.

---

**Local fix prepared:** PR #113 repair branch `fix/pr113-review` embeds all maps, upserts stable point IDs with wait, then deletes only obsolete map IDs. Incomplete embedding batches fail before write; Qdrant deletion errors now propagate except absent collections. Local seed tests passed; production Qdrant reconciliation remains pending.

**Resolved By:** Pending production verification
**Time to Resolution:** Ongoing
