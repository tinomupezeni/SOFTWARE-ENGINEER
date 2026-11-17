# Frugal V1: Wazuh Full Stack Stood Up on mywealth-vm, Finding #002 Discovered

**Date:** 2026-11-17
**Project:** Frugal
**Type:** Architecture Decision / Scope Decision (implementation)
**Status:** Completed (Wazuh full stack) — supersedes part of ADR-007

## Summary
Stood up Wazuh's official single-node deployment (manager + indexer +
dashboard, v4.12.0) on `mywealth-vm`, the VM provisioned specifically for
this per ADR-007's deferral decision, and proved it with a real scenario
run rather than stopping at "containers are up." Enrolling the lab's
victim host as a Wazuh agent and replaying the distributed-SSH scenario
against it surfaced a genuine, independently-discovered finding: Wazuh's
own default brute-force correlation rule has the same per-source blind
spot Finding #001 described for the project's hand-written baseline
detector — now confirmed against a real, independent, production
security tool.

## Context / Trigger
Continuation of the multi-day Frugal V1 implementation. ADR-007 (logged
2026-11-17 earlier the same day) deferred Wazuh's full stack to a VM
sized for the OpenSearch-based indexer's RAM appetite. User located
`mywealth-vm` (25 CPU, 41GB RAM, Docker pre-installed) and asked to SSH
in, pull the repo, and continue building there; this report covers the
Wazuh portion of that follow-up.

## Scope
Included: `vm.max_map_count` prerequisite (user ran the required `sudo`
command themselves, since the VM had no passwordless sudo and the
assistant cannot grant itself privileged access), Wazuh's official
`wazuh-docker` v4.12.0 single-node deployment, agent enrollment of the
existing `victim` lab container, and a real scenario run proving
detection end to end.

Excluded (tracked as explicit follow-ups): writing a custom Wazuh
correlation rule for Finding #002 (that is IGM/IEM work for a future
cycle, analogous to CAND-001), OpenVAS (still deferred per ADR-007),
interactive dashboard UI verification (checked only for reachability).

## Method
Ran into and fixed several real obstacles rather than working around them
silently:
- Disk filled to 91% mid-build after the Wazuh images/volumes landed;
  freed 1.5GB via a narrowly-scoped `docker builder prune -f` (a broader
  `-af` image prune was correctly blocked by the session's own
  permission classifier as a destructive action, so a safer, equivalent
  narrower command was used instead).
- `vm.max_map_count` (262144 required by OpenSearch, 65530 present, no
  passwordless sudo) — stopped and had the user run the privileged
  command themselves rather than attempting to bypass it.
- Wazuh agent `.deb` depends on `lsb-release`, not present in the minimal
  victim image; the resulting failed `dpkg -i` meant the postinst script
  that substitutes the manager's address into `ossec.conf` never ran,
  leaving a literal `MANAGER_IP` placeholder that then failed agent
  startup with a config error — diagnosed from the actual error message
  rather than assumed.
- Re-enrolling the same container under the same agent name after a
  teardown/rebuild hit "Duplicate agent name" on the manager — resolved
  by removing the stale registration first, then scripted that removal
  into `enroll_agent.sh` so it doesn't require a human to notice and fix
  it by hand next time.
- The victim's sshd logged only to the container's stderr (`-e` flag, no
  syslog daemon), which was fine for the earlier `docker logs`-based
  capture script but invisible to a Wazuh agent's localfile monitor,
  which needs a real file to tail. Added rsyslog, then hit a second,
  distinct bug: the entrypoint's `touch /var/log/auth.log` created it
  `root:root` 644, but `rsyslogd` runs as the unprivileged `syslog` user
  and silently suspended its write action — fixed by matching the
  file's ownership to what rsyslog expects (`syslog:adm`, `640`).

Each of these was confirmed via a real re-run, not assumed fixed because
the code looked right.

## Decisions & Findings
- **Wazuh full stack genuinely proven:** indexer cluster health GREEN
  (`_cluster/health` queried directly), manager's Filebeat connected and
  shipping, dashboard returning its expected login redirect, agent
  `victim` shown `Active` by `agent_control -l` on the manager.
- **Finding #002 (the headline result):** running the distributed-SSH
  scenario (3 attacker IPs, 3 attempts each, 9 total against one account)
  against the enrolled agent produced 9x rule 5760 ("sshd: authentication
  failed") but zero escalated brute-force correlation alerts. A direct
  control run — one attacker alone sending 10 rapid attempts against the
  same account — did trigger rule 5551/5763 (level 10). This confirms the
  miss is specifically about the attack being distributed across sources,
  not a broken or disabled correlation feature, mirroring Finding #001's
  root cause (`srcip`-keyed thresholds) in Wazuh's own default ruleset.
- **Scripted, not just performed by hand:** `lab/wazuh/setup_wazuh_stack.sh`
  and `lab/wazuh/enroll_agent.sh` encode every fix discovered above and
  were both re-run against the already-running stack/already-enrolled
  agent to confirm idempotency, not just written and trusted.
- **ADR-007 partially superseded:** its Wazuh-deferral half is done; the
  OpenVAS half remains deferred and unchanged.

## Changes Made
- `lab/wazuh/setup_wazuh_stack.sh`, `lab/wazuh/enroll_agent.sh`,
  `lab/wazuh/README.md` (new).
- `candidates/FINDING-002-wazuh-default-ruleset-misses-distributed-ssh.md`
  (new).
- `Docs/DECISIONS_LOG.md` — ADR-007 status updated (Wazuh half
  superseded, OpenVAS half unchanged).
- `README.md` — Status and Next steps updated to reflect what's proven.
- On `mywealth-vm` (not part of this git repo): `~/Projects/wazuh-docker`
  cloned at `v4.12.0`; the Wazuh stack and enrolled agent are live there.

## Verification
- `curl -s -k -u admin:... https://localhost:9200/_cluster/health` ->
  `"status":"green"`.
- `docker exec single-node-wazuh.manager-1 /var/ossec/bin/agent_control -l`
  -> agent `victim`, `Active`.
- Scenario run -> `alerts.json` showed 9x rule 5760, 0x correlation rule.
- Control run (single IP, 10 attempts) -> rule 5551 and 5763 (level 10)
  fired, confirming the correlation mechanism itself works and the miss
  is specific to the distributed case.
- Re-ran both setup scripts against already-running state; both completed
  without error or duplication (after fixing one idempotency bug in
  `setup_wazuh_stack.sh`'s cert-check logic, caught during this same
  verification pass — see the separate bug log entry).

## Follow-ups / Deferred
1. Write a custom Wazuh local correlation rule for Finding #002 and run
   it through the existing IGM -> IEM -> deploy_actor cycle, targeting
   the manager's `local_rules.xml` instead of the log-based detector.
2. OpenVAS on the same VM (ADR-007, still open).
3. Interactive dashboard verification.
4. LLM-backed IGM live verification (carried over, still blocked on
   credentials in the primary dev environment).

## References
- `Frugal/Docs/DECISIONS_LOG.md` ADR-007.
- `Frugal/lab/wazuh/README.md`.
- `reports/FRUGAL-2026-11-17-v1-suricata-integration-openvas-wazuh-deferred.md`
  (the original deferral decision, same day).
- Separate bug log:
  `DevOps_and_Infrastructure/FRUGAL-2026-11-17-wazuh-agent-enrollment-issues.md`.

---

**Completed By:** Claude (Sonnet 5), with tinomupezeni
**Duration:** Single session (continuation)
