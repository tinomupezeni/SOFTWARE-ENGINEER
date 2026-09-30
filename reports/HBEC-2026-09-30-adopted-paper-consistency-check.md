# Scheduled Consistency Check for Harness-Adopted Papers

**Date:** 2026-09-30
**Project:** HBEC
**Type:** Feature (guardrail, cross-service)
**Status:** Completed — verified on staging with real data

## Summary
Built the recurring check that catches an adopted exam paper going stale
before a student does — the systemic guardrail identified as missing while
tracing and fixing `HBEC-2026-09-30-harness-adopted-papers-stale-after-question-reingest-404-on-marking.md`
(21 of 23 production papers, and, discovered while verifying this build,
21 of 25 staging papers, silently 404ing on every marking submission). A
daily Celery Beat task on the Student Backend asks the Harness to diff
every paper it has ever adopted against this backend's current question
data, sets a Prometheus gauge, and Alertmanager fires on any non-zero
value — read-only, no auto-remediation, since the actual fix cascades to
real `attempts` rows and stays a reviewed manual action.

## Context / Trigger
Direct continuation of the same day's incident: after tracing and fixing
the live 404 bug with the 5 Whys (at the user's explicit request), the
5th why landed on an already-known, already-recommended, never-built
guardrail (`HBEC-2026-09-11-orphaned-student-papers-point-to-deleted-harness-papers.md`'s
own "Prevention/Rule" section). The user's own follow-up: "lets build
that."

## Scope
**Included:**
- `AGENTIC_HARNESS/app/exam_practice/services/consistency_check.py` — the
  diff logic. Queries every adopted paper (`metadata->>'source' ==
  'student_backend_adoption'`), fetches each one's current upstream
  question set via the same `get_client().get_paper_for_adoption()` call
  `paper_adoption.py` already uses, and reports any paper with even one
  missing question id — not just a count mismatch, which the 2026-09-30
  incident showed can hide total drift (same count, zero overlap).
- New harness endpoint `POST /exam-practice/maintenance/check-adopted-consistency`
  (admin HMAC), mirroring the existing `remark-pending`/`repair-ai-papers`
  maintenance sweeps exactly.
- New Celery Beat task `check_adopted_paper_consistency_task`
  (`apps/practice/tasks.py`), daily, driving it from the Student Backend —
  same reason the existing sweeps live there: the harness runs multiple
  uvicorn workers with no leader election.
- New `harness_adopted_paper_drift_count` Prometheus gauge and an
  `AdoptedPaperConsistencyDrift` Alertmanager rule, following the
  `PROVIDER_KEY_LIVE`/`ProviderModelRetired` pattern this codebase already
  uses for "a periodic check populates a gauge, Alertmanager fires on it."
- 6 new harness-side tests (drift detection: full match, partial mismatch,
  totally-disjoint-but-same-count, paper-deleted-upstream, one bad lookup
  not stopping the pass, report shape) and 4 new Django-side tests
  (signature correctness, happy path, harness-failure handling, missing-key
  skip) — mirroring `test_remarking.py` and `apps/ai_gateway/tests/test_tasks.py`'s
  existing styles exactly.

**Explicitly excluded:**
- Auto-remediation. Detected drift is reported (gauge + log + endpoint
  response), never auto-deleted — the actual fix cascades to real
  `attempts` rows (confirmed while fixing the underlying incident: 11 real
  historical marking attempts existed against 7 of the 21 stale
  production papers), so it stays a reviewed, manual action, matching how
  `DroppedStreamMessage` is auto-detected but only manually replayed.

## Method
Forked a research pass first rather than guessing the architecture: read
the existing pending-marks remarking sweep end-to-end (harness endpoint,
Django Beat task, the shared HMAC signer, the Beat schedule dict syntax),
the existing custom-Prometheus-metric pattern (`PROVIDER_KEY_LIVE`, a
gauge populated by a periodic check rather than request traffic), and the
existing Alertmanager rule shape referencing that gauge. Every new piece
mirrors an existing one line-for-line rather than inventing a parallel
convention.

Verified with real staging data at every layer, not just "container
healthy": ran the actual Celery task function directly (not waiting for
Beat's daily tick) against the live staging stack, confirmed it made a
real signed HTTP call through to the harness, confirmed the harness
endpoint ran the real diff against the real Student Backend, confirmed the
Prometheus gauge was actually populated (`curl .../metrics` inside the
container, not assumed from code review) — and in doing so, independently
rediscovered the same class of drift already live on staging's own data
(21 of 25 adopted papers), which the check correctly flagged.

## Decisions & Findings
- **Read-only by design, not a limitation to fix later.** Considered
  auto-deleting drifted papers on detection (the exact remediation just
  used for the production incident) but rejected it: the FK cascade check
  done during that remediation found real `attempts` rows would be
  destroyed by a blind delete, and a scheduled job silently doing that
  every day is a different risk profile than a human reviewing and
  backing up first, as happened today.
- **Partial and total mismatches are both "drift," full stop** — no
  threshold, no "mostly matches" leniency. The incident this exists to
  catch had cases where the count matched exactly (5 harness / 5 upstream)
  while every single id was different; a check that only compared counts
  would have missed the whole thing.
- **Daily cadence, not the marking retry's 5 minutes.** Drift only follows
  a deliberate reingest/republish event upstream, not continuous traffic —
  matches `rebuild-learner-portraits`'s existing daily job in cost profile
  (a batch sweep, not an urgent retry).
- **One aggregate gauge, no per-paper labels.** Considered labeling by
  paper id for per-paper alerting, rejected for unbounded cardinality — an
  adopted-paper count that only grows over time would eventually blow up
  the metric's label set. The endpoint's own JSON response (which the log
  line and the manual invocation both carry) is where the per-paper detail
  actually lives; the gauge is deliberately just "is anything wrong."

## Changes Made
- `AGENTIC_HARNESS/app/exam_practice/services/consistency_check.py` (new)
- `AGENTIC_HARNESS/app/exam_practice/router.py` —
  `check_adopted_consistency_endpoint`
- `AGENTIC_HARNESS/app/shared/observability/metrics.py` —
  `ADOPTED_PAPER_DRIFT_COUNT`
- `AGENTIC_HARNESS/tests/exam_practice/test_consistency_check.py` (new, 6
  tests)
- `STUDENT/hbec_backend/apps/practice/tasks.py` —
  `check_adopted_paper_consistency_task`
- `STUDENT/hbec_backend/apps/practice/tests/test_tasks.py` (new, 4 tests)
- `STUDENT/hbec_backend/config/settings/base.py` —
  `check-adopted-paper-consistency` Beat schedule entry
- `monitoring/alerts.yml` — `content_consistency` rule group,
  `AdoptedPaperConsistencyDrift`
- Commit `9bb696ec`, pushed to `master`.

## Verification
- Harness: 6 new tests passing; full `tests/exam_practice/` suite (800
  tests total after the addition) re-run clean; `tests/test_isolation.py`
  (the cross-pillar/LLM-import guardrail) still passes; `ruff check` clean.
- Django: 4 new tests passing; full `apps/practice/` suite (113 tests
  total) re-run clean; `ruff check` clean; `manage.py check` clean.
- `monitoring/alerts.yml` parses as valid YAML.
- Staging (real data, not container-health-only): rebuilt and recreated
  all four affected containers (`harness`, `student-backend`,
  `student-worker`, `student-beat` — the Beat schedule and task code live
  in the shared Django image, not just the web container, so all three
  Django-side containers needed the rebuild). Ran the actual Beat task
  function directly against live staging: real HMAC-signed HTTP call to
  the harness, `200 OK`, real diff against the real Student Backend,
  correct report (`checked: 25, drifted_count: 21`). Confirmed the
  Prometheus gauge was populated correctly inside the container
  (`harness_adopted_paper_drift_count{pid="19"} 21.0`).
- GitHub Actions was billing-blocked for this push too (same ongoing,
  already-flagged condition — see the 2026-09-28 and 2026-09-29 reports),
  so staging deployment was manual, per
  `docs/STAGING_TO_PRODUCTION_RUNBOOK.md`.

## Follow-ups / Deferred
- Not yet promoted to production — this session's incident fix (deleting
  the 21 stale production papers) was already applied directly; this new
  guardrail should go through the normal staging→production promotion
  once GitHub Actions recovers or another manual promotion is done.
- **Staging independently has its own 21-of-25 drift right now**, found as
  a side effect of verifying this build — not remediated in this pass
  (out of scope: this task was building the detector, not re-running the
  incident's remediation a second time on a second environment). Worth a
  follow-up pass applying the same backup-then-delete remediation to
  staging's drifted papers.
- GitHub Actions remains account-wide billing-blocked — third report this
  week to note it; still needs the account owner to act.

## References
- `HBEC-2026-09-30-harness-adopted-papers-stale-after-question-reingest-404-on-marking.md`
  — the incident this guardrail exists to catch earlier next time
- `HBEC-2026-09-11-orphaned-student-papers-point-to-deleted-harness-papers.md`
  — where this exact guardrail was first recommended and left unbuilt

---

**Completed By:** Claude Sonnet 5
**Duration:** Single session, same day as the incident it follows from
