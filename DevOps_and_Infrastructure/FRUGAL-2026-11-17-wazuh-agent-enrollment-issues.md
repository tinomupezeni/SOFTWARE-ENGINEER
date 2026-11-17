# Wazuh agent enrollment: three distinct failures on first attempt

**Date:** 2026-11-17
**Project:** FRUGAL
**Environment:** Development (mywealth-vm)
**Severity:** Low
**Status:** Resolved

## Summary
Enrolling a minimal Ubuntu container as a Wazuh agent failed three
separate times for three separate reasons before succeeding: a missing
package dependency silently skipped the config substitution step, the
victim image had no log file for the agent to tail at all, and
re-enrolling under a previously-used agent name was rejected by the
manager.

## Symptoms
1. `dpkg -i wazuh-agent_*.deb` reported "dependency problems... leaving
   unconfigured" for `lsb-release`.
2. After installing the missing dependency, `wazuh-control start` failed
   with `ERROR: (4112): Invalid server address found: 'MANAGER_IP'` and
   `No client configured. Exiting.`
3. On a later re-enrollment attempt (after tearing down and rebuilding
   the victim container), `agent-auth` returned
   `ERROR: Duplicate agent name: victim (from manager)`.
4. Separately, before any of this: the baseline detector correctly saw
   nothing when first pointed at the victim's logs via a Wazuh localfile
   monitor, because the container's sshd logged only to its own stderr
   (`-e` flag), not to any file.

## Environment Details
- **Server/Host:** `mywealth-vm`
- **Services Affected:** Wazuh agent enrollment, `frugal-victim` container
- **Related Components:** `wazuh-agent` `.deb` package, `/var/ossec/etc/ossec.conf`,
  the Wazuh manager's agent registry, `lab/compose/victim/Dockerfile`
- **Time First Observed:** 2026-11-17, while standing up Wazuh on `mywealth-vm`

## Investigation Steps

### 1. Initial Diagnosis
Read each error message directly rather than assuming the install
"mostly worked": the dpkg dependency error, the literal `MANAGER_IP`
string left in a config file, and the manager's own duplicate-name
rejection each pointed at a different root cause.

### 2. Root Cause Analysis
```bash
dpkg -i wazuh-agent_4.12.0-1_amd64.deb   # fails: missing lsb-release
apt-get install -y lsb-release
dpkg --configure -a                       # "succeeds" but with a stray
                                           # error because the earlier
                                           # postinst never ran cleanly
grep MANAGER_IP /var/ossec/etc/ossec.conf # confirms substitution never happened
docker exec single-node-wazuh.manager-1 /var/ossec/bin/manage_agents -l
                                           # shows the stale "victim" entry
```

### 3. Key Findings
- The `wazuh-agent` `.deb`'s postinst script (which substitutes
  `WAZUH_MANAGER` into `ossec.conf`) only runs as part of a clean
  `dpkg -i`; a dependency failure partway through leaves the config with
  its literal placeholder, and a later `dpkg --configure -a` does not
  always re-run it.
- The Wazuh manager's agent registry is keyed by name and rejects a
  duplicate even after the old container backing that name is gone —
  it has no way to know the old one is dead unless told explicitly.
- The victim image's sshd logging setup (fine for the earlier
  `docker logs`-based capture script) was never going to work for any
  tool, including Wazuh, that tails an actual file.

## Root Cause
Three independent gaps: (1) an undeclared transitive dependency assumed
present on a full OS but absent from a minimal container image, (2) no
explicit check that config substitution actually happened before trying
to start the agent, (3) no agent lifecycle cleanup when a container is
torn down and rebuilt under the same intended name.

## Prevention / Rule
**Guardrail:** `lab/wazuh/enroll_agent.sh` now installs `lsb-release`
unconditionally before `dpkg -i`, hard-codes the manager address fix via
`sed` regardless of whether the postinst ran, and looks up and removes
any existing agent with the target name on the manager before attempting
enrollment — each step independent of whether the previous one "should
have" already handled it.

This closes the gap by making the script defensive at each of the three
points that failed, rather than relying on a clean first-time install
path that this environment doesn't actually have.

## Solution

### Immediate Fix
- Installed `lsb-release` before the agent package.
- Manually fixed `<address>MANAGER_IP</address>` -> `<address>wazuh.manager</address>`.
- Removed the stale agent via `manage_agents -l` / `-R` before
  re-enrolling.
- Added rsyslog + corrected file ownership to the victim image so sshd's
  auth events land in a file any log-tailing tool (Wazuh's agent, the
  project's own baseline detector) can read (see the separate commit
  "Victim logs via rsyslog...").

### Long-term Fix
Scripted all of the above into `lab/wazuh/enroll_agent.sh`; re-ran it
against the already-enrolled agent to confirm it handles re-enrollment
cleanly without manual intervention.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add — not applicable, dev-only lab
- [x] Documentation to update (`lab/wazuh/README.md`)
- [x] Code changes required (`lab/wazuh/enroll_agent.sh`)

## Related Issues
- `Frugal/lab/compose/victim/Dockerfile` / `entrypoint.sh` rsyslog fix,
  same session.

## References
- `Frugal/lab/wazuh/enroll_agent.sh`.
- `reports/FRUGAL-2026-11-17-v1-wazuh-full-stack-on-mywealth-vm.md`.

---

**Resolved By:** Claude (Sonnet 5), with tinomupezeni
**Time to Resolution:** ~25 minutes
