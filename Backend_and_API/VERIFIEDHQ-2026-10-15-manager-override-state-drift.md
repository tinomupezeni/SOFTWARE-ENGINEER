# VerifiedHQ Manager Override State Drift

**Date:** 2026-10-15
**Project:** VerifiedHQ
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The manager override endpoint created an audit-ledger entry but did not update
the attendance event's current verification status or confidence score.

## Symptoms
- A manager could approve or reject an exception successfully.
- Subsequent exception queries and payroll exports still saw the old event state.
- The audit trail and operational state could disagree.

## Environment Details
- **Server/Host:** FastAPI backend
- **Services Affected:** Exception review, attendance export
- **Related Components:** `backend/app/routers/exceptions.py`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Traced `POST /exceptions/{event_id}/override` from request validation through
database commit.

### 2. Root Cause Analysis
The handler populated `AttendanceAuditLedger` but never assigned the validated
new status and score to the loaded `AttendanceEvent`.

### 3. Key Findings
- The audit entry alone was insufficient for current-state queries.
- Payroll export filters on the event's current verification status.

## Root Cause
The override implementation treated the audit record as the only state change,
without updating the canonical event projection used by operational queries.

## Prevention / Rule
**Guardrail:** An override transaction must update the canonical event projection
and insert its audit record in the same database transaction.

This preserves consistency between manager history, exception queues, and payroll
outputs.

## Solution

### Immediate Fix
Assign the validated status and confidence score to `AttendanceEvent` before the
existing transaction commits.

### Long-term Fix
Add an integration test that overrides an event, reloads it, and verifies both
the event state and audit entry.

## Prevention
- [x] Update event and audit record in one transaction
- [ ] Add integration regression test
- [ ] Add export-after-approval verification

## References
- `backend/app/routers/exceptions.py:121-148`
- `backend/app/models.py:252-310`

---

**Resolved By:** Copilot
**Time to Resolution:** Same review session
