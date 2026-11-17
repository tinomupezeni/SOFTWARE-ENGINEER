# Startup seed lock can lose ownership and stop retrying

**Date:** 2026-11-07
**Project:** HBEC
**Environment:** PR #116 and #113 source review; production not exercised
**Severity:** High
**Status:** Investigating

## Summary
The new startup seed helpers use fixed-expiry Redis locks and delete the lock unconditionally. If a seed runs beyond its 600- or 900-second lease, another worker can acquire it while the first still runs; the first worker then deletes the second worker's lock. Workers that initially see `busy` stop retrying, so a crashed holder can also leave a changed corpus unseeded until another restart.

## Symptoms
- `ensure_seeded` uses `SET NX EX 900` and always calls `DELETE` in `finally` without comparing an owner token.
- `ensure_heritage_seeded` uses the same pattern with a 600-second lease.
- Both startup loops treat `busy` as completion rather than waiting for the digest to become current.
- These race paths are inferred from source; no multi-worker fault injection was run.

## Environment Details
- **Server/Host:** PR head `bc735cb1e` (#116), inherited unchanged by #113.
- **Services Affected:** Agentic Harness seed-on-deploy for heritage and curriculum maps.
- **Related Components:** Redis locks, embedding worker, Qdrant.
- **Time First Observed:** 2026-11-07 code review.

## Investigation Steps

### 1. Initial Diagnosis
Read both startup seed helpers and their tests.

### 2. Root Cause Analysis
A digest is used as the lock value, not a unique owner token. Expiry is fixed, with no renewal. `finally` deletes whatever lock currently exists. `seed_when_changed` returns on `busy`.

```bash
git show origin/review-pr-116:AGENTIC_HARNESS/app/shared/seed_on_deploy.py
git show origin/review-pr-116:AGENTIC_HARNESS/app/shared/heritage_seed.py
```

### 3. Key Findings
- The curriculum seed embeds 1,075 maps in batches before writing, so elapsed time depends on the external embedding worker.
- Tests cover a static busy lock but not expiry, ownership, or holder failure.
- A successful seed log or return from another worker does not prove the changed digest was applied.

## Root Cause
The Redis lock is a time-limited flag without owner-safe release or liveness confirmation by contenders.

## Prevention / Rule
**Guardrail:** Add a multi-worker seed test that expires the first lease, lets a second worker acquire it, and asserts the first cannot release the second lock; also assert a contender waits until the target digest is current or reports failure. This exercises both ownership and completion.

## Solution

### Immediate Fix
Pending on the PR branches; block the automatic-seeding claim until lock ownership and completion are verified.

```bash
# No fix applied in this read-only review.
```

### Long-term Fix
Use unique lock tokens with compare-and-delete release, renew the lease while seeding, and make busy workers poll the digest within a bounded retry budget. Surface a failed or incomplete seed in readiness or deployment verification.

## Prevention
- [ ] Add lock-expiry and crash-recovery tests.
- [ ] Implement owner-safe lock release and renewal.
- [ ] Verify multi-worker seeding against Redis and Qdrant before deployment.

## Related Issues
- `Database_and_State/HBEC-2026-11-07-curriculum-map-seed-deletes-serving-set.md`
- PR #116; inherited by PR #113.

## References
- `AGENTIC_HARNESS/app/shared/seed_on_deploy.py` in PR #116, lines 22–60.
- `AGENTIC_HARNESS/app/shared/heritage_seed.py` in PR #116, lines 265–305.

---

**Local fix prepared:** PR #113 repair branch `fix/pr113-review` uses unique Redis lock tokens, lease renewal, and atomic compare-and-publish/release scripts. Busy contenders retry until the digest is current or log exhaustion. Local tests cover lost ownership and busy retry; production Redis verification remains pending.

**Resolved By:** Pending production verification
**Time to Resolution:** Ongoing
