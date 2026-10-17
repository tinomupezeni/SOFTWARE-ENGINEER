# Support Report Event Is Acknowledged After Processing Failure

**Date:** 2026-10-17
**Project:** HBEC
**Environment:** Code review (PR #100)
**Severity:** High
**Status:** Investigating

## Summary
Support reports are published to the notification Redis stream as
`report.submitted`, but the notification consumer acknowledges every stream
message even when ticket creation raises an exception. The Student Backend
publisher is also best-effort and does not retain a durable retry record. A
transient database, Redis, or process failure can therefore permanently lose a
student's support ticket.

## Symptoms
- A student successfully submits a report but no support ticket is created.
- The event is removed from the consumer's pending list after the processing
  exception.
- No automatic replay or durable reconciliation exists for the lost report.

## Environment Details
- **Server/Host:** PR #100 code path
- **Services Affected:** Student Backend, Notifications Service, support ticketing
- **Related Components:** telemetry report publication, Redis stream consumer,
  ticket creation
- **Time First Observed:** 2026-10-17 review

## Investigation Steps

### 1. Initial Diagnosis
Traced a written feedback or paper report from `transaction.on_commit` through
the Student Backend Redis publisher and the Notifications stream consumer.

### 2. Root Cause Analysis
The publisher catches all stream-write failures and returns `False`. On the
consumer side, processing exceptions are counted and logged, but the message is
always `XACK`ed. The `NotificationOutbox` row is not a replay worker; an
unprocessed row remains without the stream message that could drive recovery.

### 3. Key Findings
- Ticket creation is not part of the original report transaction.
- A processing failure is explicitly acknowledged rather than retried.
- The support workflow has no durable producer outbox or reconciliation job.

## Root Cause
The notification stream inherited an always-ack/no-retry policy that is unsafe
for the new support-ticket side effect, while the producer retained only a
best-effort publish attempt.

## Prevention / Rule
**Guardrail:** Every support-report event must be backed by a durable outbox
with retry/reconciliation semantics, and the consumer must not acknowledge it
until ticket creation is committed or the event is durably quarantined for
replay.

This preserves the report-to-ticket business outcome across transient service
and database failures instead of treating logging as recovery.

## Solution

### Immediate Fix
No fix was applied during the read-only PR review.

### Long-term Fix
Persist report events in the Student Backend transaction, retry delivery with
bounded backoff, and make the Notifications consumer replay unprocessed
outbox entries or move them to an operator-visible dead-letter state.

## Prevention
- [ ] Add a durable producer outbox for `report.submitted`
- [ ] Add retry/replay semantics for ticket creation failures
- [ ] Add an outage test proving a report eventually creates one ticket
- [ ] Alert on unprocessed report events and ticket-creation failures

## Related Issues
- PR #100 review: Maths, OCR, production fixes, message visibility and support
  ticketing

## References
- `STUDENT/hbec_backend/apps/telemetry/report_tickets.py:48-83`
- `STUDENT/hbec_backend/apps/telemetry/views.py:317-322`
- `NOTIFICATIONS/app/notifications/fanout.py:340-342`
- `NOTIFICATIONS/app/notifications/fanout.py:431-440`
- `NOTIFICATIONS/app/notifications/fanout.py:619-664`

---

**Resolved By:** Unresolved
**Time to Resolution:** N/A
