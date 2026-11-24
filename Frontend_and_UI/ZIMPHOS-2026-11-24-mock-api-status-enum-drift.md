# Mock API's generic mutation fallback returns a status value outside its own contract enum

**Date:** 2026-11-24
**Project:** ZIMPHOS
**Environment:** Development (caught during PR review, PR #3, before merge)
**Severity:** Medium
**Status:** Investigating

## Summary
PR #3 adds `frontend/src/mocks/mockApi.ts`, whose generic fallback for unmatched mutation (POST/PATCH) paths returns `{mock:true, status:'accepted', ...body, created_at}`. This literal `status: 'accepted'` is never validated against `openapi.yaml`, unlike GET responses which run through `frontend/src/test/contract.test.ts`. `useDecideAdjustment` (`POST /adjustments/{id}/approve|reject`) is typed against `AdjustmentItem`, whose `status` enum is `'pending' | 'approved' | 'rejected'` — a value this fallback never produces.

## Symptoms
- No runtime symptom yet — caught during pre-merge code review. Any mutation hitting this generic fallback in mock/demo mode receives a `status` value outside its own declared TypeScript type; UI logic that branches on the real enum values (e.g. showing "approved" vs "rejected" styling) silently never fires in mock/demo mode, and `contract.test.ts` — which only validates GET/snapshot responses — does not catch it.

## Environment Details
- **Server/Host:** Development / PR review only, not deployed.
- **Services Affected:** `frontend` (mock/demo mode, used for the presentation build and local dev).
- **Related Components:** `frontend/src/mocks/mockApi.ts:24`; affects `useDecideAdjustment` and any other mutation relying on the generic fallback rather than a path-specific handler.
- **Time First Observed:** 2026-11-24, during review of PR #3.

## Investigation Steps

### 1. Initial Diagnosis
Compared the mock layer's mutation responses against the same endpoints' real response schemas in `openapi.yaml`, since PR #3's own contract test only covers GET/recorded responses.

### 2. Root Cause Analysis
The generic fallback was written as a one-size-fits-all mock for any mutation path not otherwise special-cased, using a single hardcoded `status` string that happens to match some endpoints' semantics (e.g. "accepted" for an async job) but not others' closed enums.

### 3. Key Findings
- `contract.test.ts` validates only GET/recorded (snapshot) responses against the OpenAPI schema; no equivalent check exists for mutation responses produced by the mock layer.

## Root Cause
A single untyped fallback response shared across semantically different mutation endpoints, with no schema validation covering the mock layer's mutation path.

## Prevention / Rule
**Guardrail:** extend the existing contract-test approach (`contract.test.ts`) to also validate mock-layer mutation responses against their corresponding OpenAPI response schema, for every mutation hook that exercises the generic fallback — not just GET/recorded data. This closes the exact gap that let an out-of-enum value go unnoticed.

## Solution

### Immediate Fix
_Pending — to be fixed in this session._

### Long-term Fix
Give `/adjustments/{id}/approve` and `/adjustments/{id}/reject` (and any other closed-enum mutation) path-specific mock handlers that return a value from their actual contract enum, and extend `contract.test.ts` to cover mutation responses.

## Prevention
- [x] Code review caught this before merge (no production exposure).
- [ ] Extend `contract.test.ts` to validate mutation responses against their OpenAPI schema.
- [ ] Documentation to update: none required beyond this log entry.
- [ ] Code changes required — in progress.

## Related Issues
- Found alongside other PR #3 findings; see sibling entries in this directory dated 2026-11-24.

## References
- PR: https://github.com/winstonjthinker/Zimphos/pull/3

---

**Resolved By:** Claude Sonnet 5 (code-review subagent, PR review session) — fix pending
**Time to Resolution:** Caught before merge; fix in progress
