# Frugal V1: Lab Stand-up, IEM Integrity/Evaluation, First IGM Cycle

**Date:** 2026-11-17
**Project:** Frugal
**Type:** Architecture Decision / Scope Decision (implementation, not just planning)
**Status:** Completed (Sprint 1 steps 1-4 of 7)

## Summary
Implemented and proved, end-to-end, the first full Finding -> IGM ->
Candidate -> IEM -> Verdict cycle described in
`Docs/Research V1.md` and `Docs/IGM-IEM-SPEC.md`. This is the first actual
execution of Frugal's core improvement loop, not a design document — every
claim below was run and its output captured, per the SDLC guide's
"Potemkin tooling" gate referenced in the prior scoping report
(`FRUGAL-2026-11-17-v1-architecture-and-igm-iem-scoping.md`).

## Context / Trigger
Continuation of the same-day architecture/scoping session. User asked to
proceed through the Sprint-1 steps the scoping report deferred: stand up
the Docker Compose lab, implement IEM's protected-benchmark integrity
check, and implement IGM against the first real finding.

## Scope
Included: isolated Docker Compose lab (victim + 3 attacker containers),
the distributed-SSH-bruteforce scenario, a deliberately limited baseline
detector, IEM's hash-sealed integrity gate and minimal evaluation harness,
and a first IGM candidate generator scoped to exactly one finding type.

Excluded (tracked as explicit follow-ups, not silently dropped): the
deploy actor, the human-approval gate, LLM-backed IGM generation (this
cycle's IGM is deterministic/hand-authored for one finding type), and the
full Wazuh/Suricata/OpenVAS monitoring stack (baseline detector stands in
for it in V1).

## Method
Built one vertical slice of the full pipeline against one concrete
scenario rather than building all components shallowly. At each stage,
ran the actual command and captured its output before moving on: the
Sprint-1 gate from the scoping report ("don't mark complete until
exercised, not just coded") was applied literally — including testing
IEM's fail-closed behavior under three distinct tamper conditions (hash
mismatch, untracked file, missing file) before trusting it.

## Decisions & Findings
- **Lab:** 3 attacker containers on distinct static IPs, each making 3
  failed SSH logins against one account (9 total), correctly produces a
  false negative in a per-IP-only detector — reproduced the exact
  limitation named in the original research doc. Logged as
  `candidates/FINDING-001-distributed-ssh-bruteforce.md`.
- **Subnet collision:** `172.28.0.0/24` collided with an existing Docker
  pool on the dev host; fixed and logged separately as
  `DevOps_and_Infrastructure/FRUGAL-2026-11-17-lab-compose-subnet-pool-overlap.md`.
- **IEM integrity gate:** proven to fail closed under all three tested
  tamper modes (hash mismatch, extra untracked file, missing file) —
  evaluation is refused outright, never silently skipped or defaulted to
  pass.
- **IEM evaluation harness:** correctly **rejected** the known-bad baseline
  detector (evidence: no alert raised against the fixture) and correctly
  **approved_for_human_review** the IGM-generated candidate (evidence: alert
  raised, with the harness's own stdout attached as `evidence_ref` — not a
  bare LLM judgment).
- **IGM first candidate:** added account-wide correlation across >=2
  distinct source IPs, kept the original per-IP check unchanged. Verified
  directly (outside the protected benchmark) against a synthetic
  single-IP log that the original per-IP detection path still fires —
  i.e. confirmed no regression on the case the candidate wasn't targeting.

## Changes Made
- `lab/compose/{docker-compose.yml,victim/Dockerfile,attacker/{Dockerfile,attack.sh}}`
- `lab/scenarios/seed_distributed_ssh.sh`
- `lab/tools/baseline-ssh-detector/detect.py`
- `candidates/FINDING-001-distributed-ssh-bruteforce.md`
- `benchmarks/protected/{distributed_ssh_bruteforce.json,fixtures/distributed_ssh_bruteforce.log,manifest.json}`
- `iem/{seal_manifest.py,integrity_check.py,run_evaluation.py}`
- `igm/generate_candidate.py`
- `candidates/CAND-001-distributed-ssh-bruteforce/{detect.py,candidate.json}`
- `README.md` updated to reflect actual (not aspirational) status after
  each step.

## Verification
- `python3 iem/integrity_check.py` — OK on clean state; failed closed on
  hash-tampered file, on an added untracked file. Exit codes checked (0
  clean, 1 tampered).
- `python3 iem/run_evaluation.py lab/tools/baseline-ssh-detector/detect.py` —
  verdict `rejected`, evidence attached.
- `python3 iem/run_evaluation.py candidates/CAND-001.../detect.py` —
  verdict `approved_for_human_review`, evidence attached.
- Direct run of the candidate against a synthetic single-IP fixture —
  original per-IP alert still fires (manual regression check).

## Follow-ups / Deferred
1. Deploy actor + human-approval gate + `VersionLedger`/rollback — prove
   deploy is blocked without sign-off.
2. Swap IGM's deterministic generator for an LLM-backed (Anthropic API)
   implementation, same interface contract.
3. Replace the baseline stand-in with Wazuh + Suricata + OpenVAS.

## References
- `Frugal/Docs/Research V1.md`, `Frugal/Docs/IGM-IEM-SPEC.md`,
  `Frugal/Docs/DECISIONS_LOG.md` (ADR-001, ADR-002, ADR-004).
- `reports/FRUGAL-2026-11-17-v1-architecture-and-igm-iem-scoping.md`
  (prior report, same day).
- `DevOps_and_Infrastructure/FRUGAL-2026-11-17-lab-compose-subnet-pool-overlap.md`.

---

**Completed By:** Claude (Sonnet 5), with tinomupezeni
**Duration:** Single session (continuation)
