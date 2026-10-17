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
boundaries, and operational behavior. Three high-confidence defects were
confirmed. The PR should not merge until the cross-service consistency and
support-delivery paths are corrected and covered by end-to-end tests.

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

### High: AI paper subject correction crashes before Harness synchronization

`STUDENT/hbec_backend/apps/internal/ai_papers_admin.py:169-174` reads
`subject.level`, but the Student Backend `Subject` model has no `level`
attribute; the level is represented by the related grade. The Student Backend
saves the subject change at lines 238-240 before calling the helper at line
250. The resulting `AttributeError` is not handled by the HTTP exception
branches, so the request fails after the local write and leaves the Harness
copy under the old subject.

See issue log:
`Backend_and_API/HBEC-2026-10-17-ai-paper-subject-correction-crash.md`.

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
No HBEC source files or PR files were modified. This was a read-only review.

Engineering records were added and pushed:
- `75e214f` — AI paper subject correction issue
- `b8f93cf` — explicit paper-share target issue
- `6a82ebc` — support report event-loss issue

## Verification
- Confirmed PR #100 is open against `master`.
- Confirmed the PR ref is available locally as `origin/pr-100`.
- Verified each finding against the exact PR source lines and adjacent
  producer/consumer or model definitions.
- Verified the engineering issue logs were committed and pushed to the
  `SOFTWARE-ENGINEER` repository.

## Follow-ups / Deferred
- Fix the three high-severity defects before merge.
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
