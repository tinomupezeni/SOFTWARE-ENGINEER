# HBEC PR #100 Code Review

**Date:** 2026-10-17
**Project:** HBEC
**Type:** Audit / Code Review
**Status:** Completed

## Summary
Performed a read-only, skills-guided review of PR #100, “Maths, OCR,
production fixes, message visibility and support ticketing.” The review traced
the affected cross-service contracts, migrations, event consumers, paper
visibility rules, AI-paper generation flow, OCR changes, authentication
boundaries, and operational behavior. One high-confidence defect was
confirmed and one architectural durability issue remains. The initial
AI-paper subject-correction finding was withdrawn after the exact PR model was
rechecked: `Subject.level` exists.

## Context / Trigger
The user requested a code review using the installed engineering skills:
engineering baseline, contract integrity, database-change safety,
deployment truth, observability correctness, and AI behavioral correctness.
GitHub reported no CI checks for the PR branch, so source-level verification
was required in addition to reviewing the claimed local tests.

## Scope
Included:
- AI paper generation and admin subject correction
- OCR page reconstruction and math-paper paths
- Admin-to-Student paper sharing replication
- Student paper visibility filters
- Notifications, message history, and support tickets
- Stream delivery, idempotency, migrations, and failure handling
- Authentication and admin-role boundaries

Excluded:
- Running production deployment or changing PR code
- Browser/E2E validation requiring deployed PR artifacts
- Low-confidence style, performance, or speculative findings

## Method
Loaded and applied the repository's engineering-baseline, contract-integrity,
database-change-safety, deployment-truth, observability-correctness, and
AI-behavioral-correctness controls. Fetched `origin/pr-100`, compared it with
`origin/master`, traced producer/consumer pairs and database state transitions,
and independently verified each finding against the PR source and related
models/routes.

## Decisions & Findings

### Withdrawn: AI paper subject-correction finding

The exact PR ref defines `Subject.level` at
`STUDENT/hbec_backend/apps/curriculum/models.py:213-217`, so the previously
reported `AttributeError` is not a real defect. No AI architecture change is
needed.

### High: Explicit paper-share targets can be silently discarded

`STUDENT/hbec_backend/apps/replication/stream_consumer.py:274-310` skips an
explicit target that cannot be resolved immediately. The caller at lines
405-410 still applies the paper and completes the event using only the
successfully resolved targets. The paper visibility query at
`STUDENT/hbec_backend/apps/practice/views.py:601-610` requires the target
relationship for explicit sharing and disables legacy broad matching when any
target exists. A curriculum replication race therefore permanently hides the
paper from the skipped subject until an unrelated republish.

See issue log:
`Integrations_and_Auth/HBEC-2026-10-17-explicit-paper-share-target-dropped.md`.

### High: Support report events are acknowledged after ticket-processing failure

The Student Backend publisher at
`STUDENT/hbec_backend/apps/telemetry/report_tickets.py:48-83` is best-effort.
The Notifications consumer creates tickets at
`NOTIFICATIONS/app/notifications/fanout.py:340-342`, but its outer loop logs
processing exceptions and always acknowledges the Redis message at lines
431-440. There is no durable producer outbox or replay worker for the
unprocessed `NotificationOutbox` row. A transient database or service failure
can therefore permanently lose a student's support ticket.

See issue log:
`Integrations_and_Auth/HBEC-2026-10-17-support-report-event-acknowledged-on-failure.md`.

### Validation gap: CI evidence is absent

GitHub reported no checks for PR #100. The PR description's local test claims
were not independently reproducible as CI evidence during this review.
Required follow-up is a clean run of the repository's targeted and service
integration suites in the supported environments, plus migration application
and cross-service smoke tests.

## Changes Made
The explicit paper-sharing replication fix was added to PR #100 in commit
`09cc09936`. No AI source or architecture was changed.

Engineering records were added and pushed:
- `b8f93cf` — explicit paper-share target issue
- `6a82ebc` — support report event-loss issue
- The earlier AI finding was corrected in place and marked withdrawn.

## Verification
- Confirmed PR #100 is open against `master`.
- Confirmed the PR ref is available locally as `origin/pr-100`.
- Verified each finding against the exact PR source lines and adjacent
  producer/consumer or model definitions.
- Verified the engineering issue logs were committed and pushed to the
  `SOFTWARE-ENGINEER` repository.

## Follow-ups / Deferred
- Fix the explicit paper-share target defect before merge.
- Add bidirectional contract tests for AI-paper subject correction and explicit
  share target replication.
- Add outage/replay tests for `report.submitted`.
- Run the full supported CI matrix; GitHub currently shows no PR checks.
- Re-run deployment-truth and student-journey verification after fixes land.

## References
- PR #100: Maths, OCR, production fixes, message visibility and support
  ticketing
- `engineering-skills` controls: contract integrity, database change safety,
  deployment truth, observability correctness, AI behavioral correctness
- Related issue logs listed above

---

**Completed By:** Copilot
**Duration:** One review session
