# Harness Learner-Event Inbox Opens a Separate DB Session Per Event Instead of Batching

**Date:** 2026-10-02
**Project:** HBEC
**Environment:** Found reviewing PR #51 (`experimental` → `master`), which
introduces `AGENTIC_HARNESS/app/analytics/inbox.py`
**Severity:** Medium (throughput/latency cost on a path that runs for every
piece of student evidence, worst on backlog syncs)
**Status:** Investigating (flagged in PR review)

## Summary
`inbox.py::ingest()` (line 218) loops over `batch.events` (up to
`MAX_BATCH = 200`) and for each event calls `_claim()` (line 193), which
opens its own `async with create_session()` block (line 200), does one
`INSERT ... ON CONFLICT DO NOTHING ... RETURNING`, and commits — a fresh
connection-pool checkout, round trip, and commit per event, sequentially.
The student backend already batches delivery (up to 100 events per HTTP
call, per `STUDENT/hbec_backend/apps/ai_gateway/learner_events.py`), so this
is where that batching is discarded.

## Symptoms
None observed yet. Would surface as: a learner who was offline for days
syncs a backlog, turning one HTTP POST into up to 100-200 sequential DB
transactions on the harness, serialized.

## Environment Details
- **Server/Host:** AGENTIC_HARNESS (FastAPI, PostgreSQL)
- **Services Affected:** learner-event inbox ingestion
  (`POST /analytics/learner-events` or equivalent)
- **Related Components:** `app/analytics/inbox.py` (`_claim`, `ingest`),
  `STUDENT/hbec_backend/apps/ai_gateway/learner_events.py`
- **Time First Observed:** N/A (pre-merge review)

## Investigation Steps

### 1. Initial Diagnosis
Efficiency angle of the PR review checked the new inbox/outbox pipeline for
batching, given the student side explicitly batches up to 100 events per call.

### 2. Root Cause Analysis
Read `inbox.py` directly: `ingest()` iterates `batch.events` and calls
`_claim()` per event, each opening its own session/transaction.

### 3. Key Findings
- `rebuild_daily_activity.py` and the student-backend outbox were checked
  for the same pattern and found clean (both batch correctly) — this is an
  isolated gap in `inbox.py` specifically.

## Root Cause
`_claim()` was written as a single-event idempotent insert and `ingest()`
calls it in a loop, rather than `ingest()` performing one batched
`INSERT ... ON CONFLICT DO NOTHING ... RETURNING` over all events in a
single session/transaction.

## Prevention / Rule
**Guardrail:** rewrite `ingest()` to issue one batched insert over all
`batch.events` in a single session/transaction, then diff the returned ids
against the input to know which were newly claimed vs. duplicates, before
emitting bus events for the newly-claimed ones only.

## Solution

### Immediate Fix
None yet — flagged in PR #51 review.

### Long-term Fix
Batch the claim/insert as described above.

## Prevention
- [ ] Rewrite `ingest()`/`_claim()` to use one batched insert per request
- [ ] Add a test asserting a 100-event batch produces a bounded (O(1), not
      O(n)) number of DB round trips

## Related Issues
None.

## References
- `AGENTIC_HARNESS/app/analytics/inbox.py:193,218`
- PR #51: https://github.com/Rest-creator/HBEC/pull/51

---

**Resolved By:** Found during PR review (tinomupezeni / Claude Code)
**Time to Resolution:** N/A — pending fix
