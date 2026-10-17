# Global Engineering Guide Recurrence Controls

**Date:** 2026-10-17
**Project:** SOFTWARE-ENGINEER
**Type:** Standards Update / Process Improvement
**Status:** Completed

## Summary
Updated the engineering-guide library to convert recurring incident patterns
from the repository logs into explicit prevention controls. The changes
strengthen closure criteria, deployment truthfulness, migration preflights,
configuration validation, cross-service consistency, observability, security
boundaries, contract testing, AI behavior checks, and agent task decomposition.

## Context / Trigger
The repository-wide log review identified repeated failures caused by
cross-layer contract drift, false-positive deployment success, dirty production
data, configuration drift, silent replication loss, infrastructure-only
monitoring, incomplete authorization boundaries, and local-only verification of
environmental defects. The existing guides contained much of the correct
advice, but the recurring incidents showed that the advice needed stronger
closure rules and explicit evidence requirements.

## Scope
Updated the following guides:

- `5. Observability and Monitoring.md`
- `5. Secure Application Configuration.md`
- `6. Database Engineering.md`
- `7. Software Security Engineering.md`
- `8. E2E Testing.md`
- `10. Deployment And Maintenance.md`
- `11. SE Verification.md`
- `16. AI Agent Orchestration and Delegation.md`
- `17. AI-LLM System Observability and Behavioral Correctness.md`
- `19. Issue-to-Verified-Production Engineering Workflow.md`
- `20. Development Tasks Guide.md`
- `22. Multi-Service Data Replication and Consistency.md`

No project application code, project-local configuration, or runtime behavior
was changed.

## Method
Compared the consolidated repository log findings with the engineering-guide
manifest and the relevant guide content. Added focused, stack-agnostic sections
where the existing guidance was too advisory or did not explicitly require
evidence. Preserved existing guide structure and added controls near the
relevant operational material or at the guide's end where that avoided
interrupting existing examples and tables.

## Decisions & Findings

- Issue closure now distinguishes symptom mitigation, root-cause repair,
  prevention implementation, and prevention verification.
- Deployment success now requires artifact identity, migration state,
  dependency readiness, meaningful smoke behavior, and observer independence.
- Database migrations now require environment-specific dirty-data preflights
  and idempotent cleanup evidence.
- Configuration guidance now treats empty, placeholder, inconsistent, and
  environment-incompatible values as distinct invalid states.
- Replication guidance now requires versioned contracts, visible rejection and
  dead-letter paths, idempotency, and identifier-level reconciliation.
- Verification guidance now requires bidirectional contract checks, baselined
  failures, and real integration evidence for environmental defects.
- Security guidance now requires an end-to-end identity and authorization
  matrix across service and asynchronous boundaries.
- Agent-task guidance now requires decomposition at contract boundaries and
  target-environment evidence for environmental work.
- AI guidance now treats capability contracts and semantic output correctness as
  release concerns, not optional telemetry.

## Changes Made
Added 214 lines of guidance across twelve engineering-guide files. The changes
are documentation-only and are intended to be rewired into project-local
`CLAUDE.md`, `AGENTS.md`, runbooks, CI checks, and deployment gates in the next
initiative.

## Verification

- `git diff --check` passed.
- Confirmed all twelve target guide files contain their new prevention sections.
- Confirmed no application source files were modified.
- No runtime or application test suite was required because this checkpoint
  changes documentation only.

## Follow-ups / Deferred

- Wire the new controls into project-local standards and agent instructions.
- Add executable CI/deployment checks for the highest-frequency controls:
  migration preflight, artifact identity, contract direction, configuration
  validity, and test-baseline enforcement.
- Review the manifest's `applies_to` notes after project adapters absorb the
  updated controls.

## References

- `index.md`
- `Principal_Engineer/engineering-guides/MANIFEST.md`
- `reports/TESC-2026-10-16-unresolved-log-status-audit.md`
- `Principal_Engineer/engineering-guides/19. Issue-to-Verified-Production Engineering Workflow.md`
- `Principal_Engineer/engineering-guides/11. SE Verification.md`

---

**Completed By:** Copilot
**Duration:** One documentation update session
