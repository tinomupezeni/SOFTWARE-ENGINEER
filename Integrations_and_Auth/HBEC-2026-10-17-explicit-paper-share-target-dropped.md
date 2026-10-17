# Explicit Paper-Share Target Can Be Silently Dropped

**Date:** 2026-10-17
**Project:** HBEC
**Environment:** Code review (PR #100)
**Severity:** High
**Status:** Investigating

## Summary
The Student Backend replication consumer skips an explicit paper-sharing target
when the target subject is not yet replicated, has a different UUID, or fails
the board/code/grade fallback lookup. It still applies the paper and
acknowledges the replication event. The selected target is therefore lost
without retry or reconciliation, so students in that subject never see a
paper the admin explicitly shared.

## Symptoms
- A paper appears in the originating subject but not in a selected target
  subject.
- Logs report that the target was skipped, while the replication event is
  treated as successfully processed.
- The paper remains invisible until an unrelated republish happens.

## Environment Details
- **Server/Host:** PR #100 code path
- **Services Affected:** Admin Backend, Student Backend, student paper catalogue
- **Related Components:** paper replication and explicit sharing M2M
- **Time First Observed:** 2026-10-17 review

## Investigation Steps

### 1. Initial Diagnosis
Traced the Admin sharing payload through the Redis stream consumer and the
student catalogue visibility query.

### 2. Root Cause Analysis
`_resolve_share_targets()` logs and skips unresolved targets. `_handle_paper()`
then calls `shared_with_subjects.set()` with only the successfully resolved
subjects and completes the transaction. The explicit visibility query requires
a matching target row and disables legacy broad matching when any target exists.

### 3. Key Findings
- Curriculum replication can legitimately race paper replication.
- A target that is temporarily absent is not retried.
- Explicit sharing is fail-closed for the student, but the producer-side event
  is acknowledged as if the requested state was applied.

## Root Cause
The consumer treats incomplete resolution of an explicit target list as a
non-fatal warning instead of a failed cross-service state transition.

## Prevention / Rule
**Guardrail:** A paper replication event containing explicit share targets must
fail and enter the existing dropped-message/replay path unless every target
resolves uniquely.

This prevents an acknowledged event from persisting a partial sharing
configuration and makes curriculum-order races recoverable.

## Solution

### Immediate Fix
No fix was applied during the read-only PR review.

### Long-term Fix
Track unresolved targets and reject the event for retry/replay, or persist a
durable reconciliation record. Only an intentionally absent target list should
retain legacy sharing behavior.

## Prevention
- [ ] Make unresolved explicit targets a retryable replication failure
- [ ] Add an integration test where paper replication precedes subject
      replication
- [ ] Verify replay restores every selected target and student visibility

## Related Issues
- PR #100 review: Maths, OCR, production fixes, message visibility and support
  ticketing

## References
- `STUDENT/hbec_backend/apps/replication/stream_consumer.py:274-310`
- `STUDENT/hbec_backend/apps/replication/stream_consumer.py:405-410`
- `STUDENT/hbec_backend/apps/practice/views.py:601-610`

---

**Resolved By:** Unresolved
**Time to Resolution:** N/A
