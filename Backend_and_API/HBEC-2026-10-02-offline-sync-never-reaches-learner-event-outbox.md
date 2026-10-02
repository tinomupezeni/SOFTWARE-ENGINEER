# Offline-Synced Answers Never Emit `attempt_submitted`, Contradicting the New Outbox's Own Comment

**Date:** 2026-10-02
**Project:** HBEC
**Environment:** Found reviewing PR #51 (`experimental` → `master`), which
introduces the student-backend "learner-event outbox"
**Severity:** High (silent evidence loss — mastery, timeline, learner memory,
streak and the teaching loop never see offline-synced work)
**Status:** Investigating (flagged in PR review; root cause lives in code
PR #51 does not touch)

## Summary
PR #51 rewrites `STUDENT/hbec_backend/core/event_bridge.py` into a durable
outbox (`apps.ai_gateway.models.LearnerEventOutbox`) so "evidence seen only
by the student backend now reaches learner memory." Its new docstring for
`emit_offline_sync_completed` asserts: *"The sessions themselves are not
sent: each synced answer is already its own attempt event, and sending the
totals as well is how the same work used to be counted twice."*

That assumption is false. `STUDENT/hbec_backend/apps/offline/services.py`
(`SyncService._sync_attempt`, not touched by this PR) creates
`QuestionAttempt` objects directly via `.objects.create(...)` and never calls
`EventBridge.emit_attempt_submitted` anywhere in that file. The only event
fired for a sync is the receipt-only `offline_sync_completed`
(`apps/offline/tasks.py::process_bulk_sync`), which "carries no marks."

## Symptoms
None reported yet in production — found via code tracing during PR review.
Would surface as: a student who practices offline and syncs later shows no
mastery update, no permanent timeline row, no `learner_memory` write, no
teaching-loop evidence, and (per the new `streak_writer.COUNTERS`, which does
not include `offline_sync_completed`) no streak/goal credit for that work.

## Environment Details
- **Server/Host:** Student Backend (Django, port 8000) + Harness (FastAPI, port 8080)
- **Services Affected:** offline sync, learner mastery, learner timeline,
  teaching loop, streaks/goals
- **Related Components:** `STUDENT/hbec_backend/apps/offline/services.py`
  (`_sync_attempt`, `_sync_session`), `apps/offline/tasks.py`
  (`process_bulk_sync`), `STUDENT/hbec_backend/core/event_bridge.py`
  (`emit_offline_sync_completed`, `emit_attempt_submitted`)
- **Time First Observed:** N/A (pre-merge review)

## Investigation Steps

### 1. Initial Diagnosis
Cross-file tracer angle of the PR review asked: does every event source that
should feed the new outbox actually do so? Offline sync was the one path
that claimed it already did, in a comment added by this very PR.

### 2. Root Cause Analysis
Read `_sync_attempt` directly: it writes `QuestionAttempt` rows with no
`EventBridge` import or call anywhere in `apps/offline/services.py`.
`apps/offline/tasks.py::process_bulk_sync` only calls
`EventBridge.emit_offline_sync_completed(...)` after the whole batch, with
`synced_count`/`error_count` totals, no per-answer event.

### 3. Key Findings
- `apps/offline/*` is untouched by PR #51 — this is a pre-existing gap, but
  this PR's own new code states, as fact, that it doesn't exist.
- `streak_writer.COUNTERS` (new in this PR) has no entry for
  `offline_sync_completed`, so even the one event that does fire for a sync
  earns no streak/goal credit either.

## Root Cause
`_sync_attempt` was written against the old (pre-outbox) event model, where
nothing emitted per-answer events for offline practice; that gap predates
this PR. The outbox rewrite assumed (and now documents) that the gap had
already been closed, without verifying the offline sync path.

## Prevention / Rule
**Guardrail:** `apps/offline/services.py::_sync_attempt` must call
`EventBridge.emit_attempt_submitted(..., occurred_at=attempt's offline
timestamp)` for each synced attempt (the new `occurred_at` parameter this PR
added to `emit_attempt_submitted` exists for exactly this: evidence recorded
late keeps its own day). Add a test asserting that syncing N offline
attempts produces N `attempt_submitted` outbox rows, so this exact
regression (or its original absence) cannot silently return.

## Solution

### Immediate Fix
None yet — flagged in PR #51 review. Not blocking the PR's own stated scope
(it didn't touch offline sync), but should be fixed promptly since the new
outbox's docstring now asserts it is already handled.

### Long-term Fix
Wire `_sync_attempt` to `EventBridge.emit_attempt_submitted` using the
attempt's own `offlineSubmittedAt`/`occurred_at`.

## Prevention
- [ ] Add `EventBridge.emit_attempt_submitted` call in `_sync_attempt`
- [ ] Add streak credit for synced attempts (via `attempt_submitted`, which
      `streak_writer.COUNTERS` already handles — no new counter needed once
      the event fires)
- [ ] Regression test: offline sync → N `attempt_submitted` outbox rows

## Related Issues
- PR #51 (learner-event outbox, teaching loop)

## References
- `STUDENT/hbec_backend/apps/offline/services.py`
- `STUDENT/hbec_backend/apps/offline/tasks.py`
- `STUDENT/hbec_backend/core/event_bridge.py`
- PR #51: https://github.com/Rest-creator/HBEC/pull/51

---

**Resolved By:** Found during PR review (tinomupezeni / Claude Code)
**Time to Resolution:** N/A — pending fix
