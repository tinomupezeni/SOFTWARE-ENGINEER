# Offline outbox's catch branch has no guard around its own IndexedDB write, can strand the UI mid-submit

**Date:** 2026-11-24
**Project:** ZIMPHOS
**Environment:** Development (caught during PR review, PR #3, before merge)
**Severity:** High
**Status:** Investigating

## Summary
PR #3's offline outbox (`queue.ts`) retries field-app submissions (counts, adjustments, deliveries) through IndexedDB when the network is unavailable. `attempt()`'s `catch` block, entered when the network request itself fails, calls `await db.outbox.update(...)` to record the failure — with no nested `try/catch` around that call. If this `db.outbox.update` itself throws (e.g. an IndexedDB quota or write error, plausible on storage-constrained phones), the exception propagates unhandled through `capture()` into the calling page's `handleSubmit`, which has no `try/catch/finally` of its own around `capture()`.

## Symptoms
- No runtime symptom yet — caught during pre-merge code review. On a storage-constrained device, a failed submit whose failure-recording write also fails leaves `setIsSaving(false)` and the `isSubmitting` ref never reset, so the Save button is stuck on "Saving…" indefinitely with no in-app recovery short of a full reload.

## Environment Details
- **Server/Host:** Development / PR review only, not deployed.
- **Services Affected:** `frontend` (field app offline sync).
- **Related Components:** `frontend/src/services/offline/queue.ts:56`; consumed by `CountPage.tsx`, `AdjustPage.tsx`, `DeliveryPage.tsx`.
- **Time First Observed:** 2026-11-24, during review of PR #3.

## Investigation Steps

### 1. Initial Diagnosis
Traced the full error path from a failed network request through the outbox's retry bookkeeping up to the page-level submit handler, to check whether every failure mode actually resolves the submit's loading state.

### 2. Root Cause Analysis
The `catch` branch assumes its own bookkeeping write cannot fail. On a phone near storage quota (a realistic condition for an offline-first field app that caches photos and queues writes), the IndexedDB write recording the failure can itself throw, and nothing downstream catches it.

### 3. Key Findings
- None of the three field-app submit handlers (`CountPage`, `AdjustPage`, `DeliveryPage`) wrap their call to `capture()` in `try/catch/finally`; they rely on `capture()`/`attempt()` never throwing.
- This compounds with a separate, already-logged finding that these same pages never reset their `isSubmitting` ref even on success (relying on unmount) — see `ZIMPHOS-2026-11-24-*` sibling entries.

## Root Cause
Missing defensive handling for a failure within a failure-handling path: the code handles "the submit failed" but not "the thing that records that the submit failed, also failed."

## Prevention / Rule
**Guardrail:** any `catch` block that itself performs I/O (a DB write, a network call) must wrap that I/O in its own `try/catch`, and any caller of an async operation that updates UI loading state must use `finally` to guarantee that state resets regardless of how the operation failed. A test that forces `db.outbox.update` to reject during the failure path, and asserts the submit button's loading state still clears, would catch this directly.

## Solution

### Immediate Fix
_Pending — to be fixed in this session._

### Long-term Fix
Wrap the nested `db.outbox.update` call in its own `try/catch` (logging/swallowing a secondary bookkeeping failure rather than propagating it), and add `finally` blocks around `capture()` calls in the three field-app submit handlers so loading state always resolves.

## Prevention
- [x] Code review caught this before merge (no production exposure).
- [ ] Add a test simulating a secondary IndexedDB write failure during the outbox's failure path.
- [ ] Documentation to update: none required beyond this log entry.
- [ ] Code changes required — in progress.

## Related Issues
- Found alongside other PR #3 findings; see sibling entries in this directory dated 2026-11-24.

## References
- PR: https://github.com/winstonjthinker/Zimphos/pull/3

---

**Resolved By:** Claude Sonnet 5 (code-review subagent, PR review session) — fix pending
**Time to Resolution:** Caught before merge; fix in progress
