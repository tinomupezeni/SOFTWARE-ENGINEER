# Frugal V1 Architecture, Tool Assembly, and IGM/IEM Scoping

**Date:** 2026-11-17
**Project:** Frugal
**Type:** Architecture Decision / Scope Decision
**Status:** Completed (Sprint 0 scoping — implementation not started)

## Summary
Scoped the V1 prototype architecture and technology stack for Frugal, an
AI-driven cybersecurity defence system built on tool-level recursive
self-improvement (IGM generates candidate improvements to security tooling,
IEM independently evaluates them). Assembled the set of security monitoring
tools V1 will defend with, and wrote the IGM/IEM/deploy-actor interface
contract. Produced foundational docs and repo scaffold; no implementation
code was written.

## Context / Trigger
User had an existing concept doc (`Docs/Research V1.md`) describing the
IGM/IEM recursive self-improvement loop at a conceptual level, with no
architecture, stack, or concrete tool list yet. User asked to start scoping
the V1 prototype's architecture/stack, assemble the cybersecurity tools it
will use, and set up IGM and IEM.

## Scope
Included: architecture doc, stack selection, security-tool assembly for the
isolated lab, IGM/IEM/deploy-actor interface spec, ADRs for the
separation-of-duties and integrity decisions, repo directory scaffold.

Excluded (deliberately, per the research doc's own V1 scope and SDLC
greenfield gates): any actual service implementation, CI pipeline, or
Docker Compose lab stand-up. Per the SDLC guide's "Potemkin tooling" gate,
the repo's README explicitly states Sprint 1 is not complete until the
harness, integrity check, and approval gate are each proven to work, not
just scaffolded.

## Method
Per the user's global CLAUDE.md rule, consulted
`Principal_Engineer/engineering-guides/MANIFEST.md` and read guides 1 (SDLC,
greenfield gates), 7 (Software Security Engineering), and 17 (AI/LLM System
Observability and Behavioral Correctness) via a forked subagent to extract
only the concretely actionable constraints, rather than copying the guides
wholesale. Guide 2 was checked and had nothing additive beyond guide 1 for
this project.

## Decisions & Findings
- **Separation of duties (ADR-001):** IGM (generate-only) and IEM
  (evaluate-only) run as separate services with separate credentials and DB
  roles; a fourth actor (deploy) holds the only write access to live tool
  config. Driven by guide 7: an AI proposing changes to its own defensive
  tooling is a privilege-escalation path if any component holds both
  propose and apply rights.
- **Protected benchmark integrity (ADR-002):** the protected test suite
  IGM/IEM are judged against is stored outside both components' write
  access, hash-verified at evaluation time, fails closed on tampering.
  Prevents the subject under test from weakening its own evaluation
  criteria.
- **Rule/script-based tools only for V1 (ADR-003):** chose Wazuh, Suricata,
  auditd, OpenVAS, Atomic Red Team over any ML-based detector, specifically
  because IGM's diffs to rule/text-based tools stay human-inspectable and
  IEM's regression testing stays tractable — ML retraining is explicitly
  out of scope for V1.
- **Grounded IEM verdicts (ADR-004):** IEM's pass/fail must trace to actual
  scenario-harness execution results, not freeform LLM reasoning, per guide
  17's ungrounded-output failure mode. Any LLM call inside IEM may
  summarize evidence but may not itself decide the verdict.
- **Human approval gate (ADR-005):** mandatory before any candidate reaches
  production, reframed from the research doc's "controlled deployment"
  preference into a hard secure-design requirement per guide 7.

## Changes Made
- `Frugal/ARCHITECTURE.md` — V1 architecture, component diagram, stack,
  separation-of-duties table, Sprint-1 gate definition, non-goals.
- `Frugal/Docs/DECISIONS_LOG.md` — ADR-001 through ADR-005.
- `Frugal/Docs/IGM-IEM-SPEC.md` — concrete input/output schemas and
  credential scoping for IGM, IEM, and the deploy actor.
- `Frugal/README.md` — repo layout and the five-step Sprint-1 exit
  criteria.
- Repo scaffold: `orchestrator/`, `igm/`, `iem/`, `deploy_actor/`,
  `benchmarks/protected/`, `benchmarks/adaptive/`, `scenario_harness/`,
  `candidates/`, `lab/compose/`, `lab/tools/` (empty, placeholder only).

## Verification
None applicable — no executable code was produced at this stage. The
README explicitly records that Sprint 1 is not to be marked complete until
the scenario harness, integrity check, and approval gate are each
demonstrated to work (not just present), to avoid the Potemkin-tooling
failure mode this same guide library has flagged on other projects.

## Follow-ups / Deferred
1. Stand up the `lab/` Docker Compose environment with Wazuh + Suricata +
   auditd and seed the SSH distributed-login-attempt scenario from the
   research doc.
2. Implement the scenario harness end-to-end against that one scenario.
3. Implement and prove the protected-benchmark hash check fails closed.
4. Implement IGM against that one finding type and produce one real
   candidate.
5. Wire and prove the human-approval gate blocks deploy absent sign-off.

## References
- `Frugal/Docs/Research V1.md` — original concept doc.
- `Principal_Engineer/engineering-guides/1. SDLC.md`,
  `7. Software Security Engineering.md`,
  `17. AI-LLM System Observability and Behavioral Correctness.md`.

---

**Completed By:** Claude (Sonnet 5), with tinomupezeni
**Duration:** Single session
