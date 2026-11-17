# Heritage reseed retains removed corpus entries

**Date:** 2026-11-07
**Project:** HBEC
**Environment:** PR #116 and #113 source review; production not exercised
**Severity:** Medium
**Status:** Investigating

## Summary
The heritage startup seed upserts current corpus entries into a persistent Qdrant collection using title-derived IDs, but never removes points for titles that have been deleted or renamed. Once a digest is recorded, a removed entry can still be retrieved into every pillar as if it were current heritage content.

## Symptoms
- `seed_corpus` calls `store_embeddings` for current entries only.
- The collection is reused; no stale-point deletion or generation filter is applied.
- Retrieval searches the collection and has no current-corpus membership check.
- This is a source-derived persistence path; no target Qdrant experiment was run.

## Environment Details
- **Server/Host:** PR head `bc735cb1e` (#116), inherited by #113.
- **Services Affected:** Agentic Harness heritage grounding across learning pillars.
- **Related Components:** Heritage corpus seed, Qdrant collection and retrieval.
- **Time First Observed:** 2026-11-07 code review.

## Investigation Steps

### 1. Initial Diagnosis
Traced corpus IDs, reseeding and retrieval.

### 2. Root Cause Analysis
Stable title IDs make updates idempotent, but an absent title has no write and no removal path. The Redis digest is then advanced despite stale points remaining.

```bash
git show origin/review-pr-116:AGENTIC_HARNESS/app/shared/heritage_seed.py
git show origin/review-pr-116:AGENTIC_HARNESS/app/shared/heritage.py
```

### 3. Key Findings
- Renaming a title creates a new ID and leaves the old one.
- A factual withdrawal cannot be guaranteed by editing the corpus file alone.
- Tests cover reseed idempotence but not removal.

## Root Cause
The seed implements upsert synchronization, not full set reconciliation.

## Prevention / Rule
**Guardrail:** A Qdrant-backed seed test must seed an entry, remove it from the corpus, reseed, and assert that retrieval no longer returns it. This verifies withdrawal semantics across deploys.

## Solution

### Immediate Fix
Pending on the PR branches; require stale-point reconciliation before relying on deploy reseeding for corrections or withdrawals.

```bash
# No fix applied in this read-only review.
```

### Long-term Fix
Track a corpus generation or manifest, stage current points, and remove only obsolete points after the new generation is verified; keep readers restricted to the active generation.

## Prevention
- [ ] Add a removed-entry Qdrant regression test.
- [ ] Implement safe stale-point reconciliation.
- [ ] Verify a correction and withdrawal in the deployed retrieval path.

## Related Issues
- `Database_and_State/HBEC-2026-11-07-startup-seed-lock-can-lose-ownership.md`
- PR #116; inherited by PR #113.

## References
- `AGENTIC_HARNESS/app/shared/heritage_seed.py` in PR #116, lines 228–258.
- `AGENTIC_HARNESS/app/shared/heritage.py` in PR #116, retrieval path.

---

**Local fix prepared:** PR #113 repair branch `fix/pr113-review` captures existing heritage point IDs and deletes removed or renamed IDs after the new corpus has been upserted successfully. A focused local regression proves deletion order; production Qdrant reconciliation remains pending.

**Resolved By:** Pending production verification
**Time to Resolution:** Ongoing
