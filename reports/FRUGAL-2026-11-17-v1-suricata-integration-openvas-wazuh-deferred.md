# Frugal V1: Suricata Integration; OpenVAS and Full Wazuh Deferred to a VM

**Date:** 2026-11-17
**Project:** Frugal
**Type:** Architecture Decision / Scope Decision (implementation)
**Status:** Completed (Suricata) / Deferred by decision (OpenVAS, Wazuh full stack)

## Summary
Integrated Suricata into the Frugal V1 lab as a genuinely independent
detection surface for the distributed-SSH-bruteforce scenario (network
connection-volume thresholding, as opposed to the existing log-content
detector), and proved it against a real attack run. Explicitly deferred
OpenVAS and Wazuh's full stack (indexer + dashboard) to a future VM with
adequate resources, per a decision made with the user rather than silently
skipped or faked.

## Context / Trigger
Continuation of the same-day Frugal V1 implementation session. README.md
named "fold in Wazuh + Suricata + OpenVAS" as a follow-up; user asked to
proceed with it. Before starting, checked this dev machine's resources
(80GB free disk, 6.4GB available RAM, 4 CPUs) and flagged that OpenVAS's
NVT feed sync (1-3+ hours typical on first run) and Wazuh's indexer
(typically wants 4GB+ RAM) made "stand up and prove all three this
session" unrealistic without either a multi-hour unattended sync or a
resource-starved stack whose working state couldn't actually be verified.
Asked the user how to scope it; they chose to skip OpenVAS for now and
move the heavier infra (Wazuh full stack, OpenVAS) to a future VM, while
proceeding with Suricata now.

## Scope
Included: Suricata container integrated into `lab/compose/docker-compose.yml`,
a custom detection rule, a repeatable scenario script, and a real proof
run against the existing distributed-SSH scenario.

Excluded, by explicit decision (not silently dropped): Wazuh's
manager+indexer+dashboard stack, OpenVAS/Greenbone. Recorded as ADR-007 in
`Docs/DECISIONS_LOG.md` with the reasoning and the exact follow-up
("stand up and prove on a dedicated VM").

## Method
Hit a concrete deployment obstacle and worked around it with a legitimate
alternative rather than a hack: host-level packet capture
(`tcpdump`/Suricata on the Docker bridge) needs `sudo`, which isn't
configured for non-interactive use in this environment. Instead of either
skipping Suricata or asking for a password mid-session, used
`network_mode: "service:victim"` so Suricata shares the protected host's
own network namespace — a standard host-based NIDS pattern, not a
workaround that compromises what's being proven. Recorded as ADR-006.

Wrote a connection-volume threshold rule deliberately different from the
log-based detector's approach, since SSH traffic is encrypted and
Suricata cannot read "Failed password" lines the way
`lab/tools/baseline-ssh-detector/detect.py` does. Ran the full attack
scenario with Suricata attached and inspected `eve.json` directly rather
than trusting that the rule "should" fire.

## Decisions & Findings
- **Suricata fired correctly, on real traffic:** confirmed 9 SSH app-layer
  events (one per failed connection attempt) from all 3 distinct attacker
  IPs, and exactly one alert once their combined volume to the victim
  crossed the rule's threshold (`track by_dst`, count 5 / 60s).
- **Suricata's detection surface already handles the distributed case
  without IGM's help:** because the rule tracks by destination rather than
  source, it caught the distributed attack on its own — no "Finding ->
  IGM -> fix" cycle was needed for this detection surface the way it was
  for the log-based tool. This is a genuine property of network-layer
  volume detection, not something tuned after the fact to match the
  scenario; worth noting for future findings analysis (not every gap
  IGM/IEM need to fix is universal across tools).
- **Reran the scenario twice** to confirm the Suricata integration is
  actually repeatable (second run fired its own alert cleanly;
  `fast.log`/`eve.json` just accumulated across runs, as expected for an
  append-only log).
- **OpenVAS/Wazuh-full deferral is a recorded decision, not an omission:**
  ADR-007 states the reasoning (resource/time cost vs. unverifiable state)
  and the concrete follow-up (prove each on a VM the same way Suricata was
  proven here).

## Changes Made
- `lab/compose/docker-compose.yml` — added `suricata` service.
- `lab/suricata/rules/local.rules` (new).
- `lab/scenarios/seed_distributed_ssh_suricata.sh` (new).
- `.gitignore` — added `lab/suricata/output/`.
- `Docs/DECISIONS_LOG.md` — ADR-006 (network-namespace-sharing rationale),
  ADR-007 (OpenVAS/Wazuh-full deferral).
- `README.md` updated to reflect proven/deferred status.

## Verification
- `docker run --rm jasonish/suricata:latest -V` — confirmed image runs
  (Suricata 8.0.8).
- Full scenario run (`seed_distributed_ssh_suricata.sh`): `eve.json`
  showed 9 `ssh` events from 3 distinct source IPs and 1 `alert` event
  with the expected signature; `fast.log` matched.
- Re-ran a second time to confirm repeatability.

## Follow-ups / Deferred
1. On a dedicated VM: stand up OpenVAS/Greenbone, let the NVT feed sync
   complete, and prove a real scan finds something (or correctly finds
   nothing) against a known-vulnerable target — don't mark done on
   container-up alone.
2. On the same or another adequately-sized VM: stand up Wazuh's full
   stack (manager + indexer + dashboard), enroll the victim as an agent,
   and prove an alert reaches the dashboard from a real scenario run.
3. LLM-backed IGM live verification (carried over from the prior
   in-progress report, still blocked on credentials).
4. Postgres-backed job table and DB-role separation of duties.

## References
- `Frugal/Docs/DECISIONS_LOG.md` ADR-006, ADR-007.
- `reports/FRUGAL-2026-11-17-v1-llm-backed-igm.md` (prior report, same
  day, also carrying a documented "not yet proven" item).

---

**Completed By:** Claude (Sonnet 5), with tinomupezeni
**Duration:** Single session (continuation)
