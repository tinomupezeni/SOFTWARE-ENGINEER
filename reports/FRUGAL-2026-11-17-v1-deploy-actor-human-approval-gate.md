# Frugal V1: Deploy Actor and Human-Approval Gate

**Date:** 2026-11-17
**Project:** Frugal
**Type:** Architecture Decision / Scope Decision (implementation)
**Status:** Completed (Sprint 1 step 5 of 9)

## Summary
Implemented and proved the deploy actor and mandatory human-approval gate
that sit downstream of IEM in Frugal's improvement pipeline, closing the
loop first exercised in the prior same-day report
(`FRUGAL-2026-11-17-v1-lab-iem-igm-first-cycle.md`). The full
Finding -> IGM -> Candidate -> IEM -> Verdict -> HumanApproval -> Deploy
cycle now runs end to end against one real finding, with rollback proven.

## Context / Trigger
Continuation of the same-day Frugal V1 implementation session. The prior
report left step 5 (deploy actor + human approval gate) as the next
planned step; user asked to proceed with exactly that.

## Scope
Included: `deploy_actor/human_approval.py` (the only way a HumanApproval
record is created), `deploy_actor/deploy.py` (requires both an approved
verdict and a matching approval, refuses otherwise), `deploy_actor/rollback.py`,
and a `version_ledger.jsonl` append-only ledger. Also added `verdict_id`
and on-disk persistence to `iem/run_evaluation.py` so verdicts have a
stable identity for approval/deploy to reference.

Excluded (tracked as follow-ups): Postgres-backed DB roles for separation
of duties (currently enforced by which script touches which file/
directory, not DB grants); the orchestrator's continuous job loop; LLM-
backed IGM generation; Wazuh/Suricata/OpenVAS.

## Method
Same discipline as the prior report: every claim below was actually run,
including the negative/blocking cases, before being written down.

## Decisions & Findings
- **Refusal to rubber-stamp:** `human_approval.py` checks the verdict's own
  `verdict` field and refuses to write an approval record for anything
  IEM did not mark `approved_for_human_review` — tested directly against
  a rejected verdict (the known-bad baseline detector's), confirmed
  refused.
- **Deploy requires both artifacts:** `deploy.py` checks for an approved
  verdict AND a matching approval record on disk; tested running it with
  no approval present first — blocked, exit code 1, no file touched.
- **Live-target resolution via candidate metadata:** `deploy.py` reads
  `target_tool` out of the candidate's own `candidate.json` (written by
  IGM) rather than hardcoding a path per candidate, so the deploy actor
  doesn't need per-candidate special-casing.
- **Rollback proven, not assumed:** deployed CAND-001, confirmed the live
  detector now alerts on the protected fixture, rolled back via the
  ledger entry, confirmed the live detector reverted to missing the
  distributed attack (original behavior restored), then re-deployed to
  leave the lab in its intended improved state.

## Changes Made
- `iem/run_evaluation.py` — added `verdict_id` (deterministic hash of
  candidate_id + evaluated_at) and `write_verdict()` persisting to
  `iem/verdicts/<verdict_id>.json`.
- `deploy_actor/human_approval.py`, `deploy_actor/deploy.py`,
  `deploy_actor/rollback.py` (new).
- `deploy_actor/approvals/`, `deploy_actor/backups/`,
  `deploy_actor/version_ledger.jsonl` (runtime state produced by the
  commands below).
- `README.md` updated to reflect proven status.

## Verification
- `python3 deploy_actor/deploy.py <verdict_id>` with no approval present
  -> blocked, exit 1.
- `python3 deploy_actor/human_approval.py <rejected_verdict_id> ...` ->
  refused, exit 1.
- `python3 deploy_actor/human_approval.py <approved_verdict_id> tinomupezeni "..."`
  -> approval recorded.
- `python3 deploy_actor/deploy.py <approved_verdict_id>` -> deployed,
  backup + ledger entry written.
- Live detector re-run against the fixture -> now alerts.
- `python3 deploy_actor/rollback.py <deploy_id>` -> live detector reverted
  to original (confirmed by re-running against the fixture, no alert).
- Re-deployed the same verdict to leave the lab in the improved state.

## Follow-ups / Deferred
1. Postgres-backed DB roles for separation of duties, per ARCHITECTURE.md
   §3 (currently filesystem-path-based, not DB-grant-based).
2. Orchestrator job loop (continuous cycle vs. hand-driven scripts).
3. LLM-backed IGM generation.
4. Wazuh + Suricata + OpenVAS integration.

## References
- `Frugal/Docs/IGM-IEM-SPEC.md`, `Frugal/Docs/DECISIONS_LOG.md` (ADR-005).
- `reports/FRUGAL-2026-11-17-v1-lab-iem-igm-first-cycle.md` (prior report,
  same day).

---

**Completed By:** Claude (Sonnet 5), with tinomupezeni
**Duration:** Single session (continuation)
