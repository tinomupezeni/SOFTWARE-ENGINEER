# Stale VerifiedHQ Gap Analysis

**Date:** 2026-10-15
**Project:** VerifiedHQ
**Environment:** Development
**Severity:** Medium
**Status:** Investigating

## Summary
The repository's gap analysis reports several core features as unimplemented even
though the current code already contains initial implementations. This creates
planning and prioritization drift for the Zimbabwe attendance product.

## Symptoms
- `docs/GAPS_ANALYSIS.md` marks `/check-in/nonce` and `/check-in` as missing.
- `backend/app/routers/checkin.py` implements both endpoints and event retrieval.
- `docs/GAPS_ANALYSIS.md` marks the sensor-fusion engine as missing.
- `backend/app/sensor_fusion.py` contains the weighted evaluation service.

## Environment Details
- **Server/Host:** Local Git worktree
- **Services Affected:** Documentation, backlog planning, implementation prioritization
- **Related Components:** FastAPI check-in router, sensor-fusion service, mobile client
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Read `Research.md`, `docs/GAPS_ANALYSIS.md`, the backlog, and the current
FastAPI implementation to compare documented status with source behavior.

### 2. Root Cause Analysis
The gap analysis was written against an earlier implementation snapshot and has
not been reconciled with subsequent commits that added the check-in pipeline and
advanced verification services.

```bash
grep -nEi 'nonce|check-in|sensor fusion' docs/GAPS_ANALYSIS.md
sed -n '1,220p' backend/app/routers/checkin.py
sed -n '1,220p' backend/app/sensor_fusion.py
```

### 3. Key Findings
- The documented gap status is not a reliable source of truth for sprint
  prioritization.
- The existing implementation is still incomplete for production: offline
  outbox/idempotency, full device attestation, operational exception workflows,
  and payroll exports remain material gaps.
- The correct next step is reconciliation against executable tests and endpoint
  behavior, not simply changing status markers.

## Root Cause
Documentation status was not updated after implementation commits, and there is
no verification gate requiring gap-analysis claims to reference tests or source
evidence.

## Prevention / Rule
**Guardrail:** Every gap-analysis item must include a status, source path, and
verification command or test identifier; CI should reject entries marked
implemented without a matching test or endpoint check.

This ties planning claims to executable evidence and prevents stale snapshots
from driving product decisions.

## Solution

### Immediate Fix
Recorded the discrepancy and the evidence discovered during the cross-repository
research review.

### Long-term Fix
Reconcile `docs/GAPS_ANALYSIS.md` and `docs/backlog.md` with the current source,
then add focused API and service tests for each claimed MVP capability.

## Prevention
- [ ] Add source/test references to gap-analysis rows
- [ ] Add endpoint smoke checks to CI
- [ ] Reconcile the gap analysis after each phase-completion commit
- [ ] Update the backlog to prioritize the Zimbabwe MVP vertical slice

## Related Issues
- None recorded yet.

## References
- `docs/GAPS_ANALYSIS.md:18-47`
- `backend/app/routers/checkin.py:22-181`
- `backend/app/sensor_fusion.py:1-220`
- `Research.md`

---

**Resolved By:** Copilot
**Time to Resolution:** Ongoing
