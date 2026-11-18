# deploy.sh Required Env Vars With No Default, No Documented VPS Target

**Date:** 2026-11-18
**Project:** MARITCHO
**Environment:** Local (deploy operator's machine) -> Production VPS (`restk-vps`)
**Severity:** Low
**Status:** Resolved

## Summary
`deploy/production/deploy.sh` hard-required `MARICHO_VPS`, `MARICHO_DOMAIN`, and `MARICHO_WS_URL` as environment variables with `: "${VAR:?message}"`, with no default and no record anywhere (shell profile, `.ssh/config` comment, CI secret, repo doc) of what the actual production VPS target's name was — only an SSH config alias (`restk-vps`, pointing at `winstontino@159.198.42.231`) existed, undocumented in the repo.

## Symptoms
- Running `deploy/production/deploy.sh` with no env vars set fails immediately with "Set MARICHO_VPS, for example deployer@example-vps" — by design, but gave no path to the actual value.
- The only clue to the real target was an SSH config alias already set up on the operator's machine; nothing in the repo or CI said "deploy to restk-vps" explicitly.

## Environment Details
- **Server/Host:** N/A (tooling/process gap)
- **Services Affected:** Deploy operator workflow only
- **Related Components:** `deploy/production/deploy.sh`, `deploy/production/README.md`, `~/.ssh/config` (`restk-vps` alias)
- **Time First Observed:** 2026-11-18, when asked to deploy PR #13 to production and no local env vars were set

## Investigation Steps

### 1. Initial Diagnosis
Checked this shell's env, `~/.bashrc`/`~/.zshrc`/`~/.profile`, `.github/` workflows, and found no deploy automation or stored value for any of the three required variables.

### 2. Root Cause Analysis
The single production target was never made a default in the script, and its connection details were never written down anywhere version-controlled — only living as a personal SSH config alias.

### 3. Key Findings
- `~/.ssh/config` had `Host server1 restk-vps` -> `159.198.42.231`, `User winstontino` — this was the only source of truth for the target.
- The VPS's own `~/apps/maricho/.env` already had real secrets (DB password, SECRET_KEY, etc.) — those were never the problem; only the *local* invocation parameters (which host to SSH into) were undocumented.

## Root Cause
A single-target production deploy script required its target to be supplied by hand every time, with the target's actual value recorded nowhere accessible to someone without prior tribal knowledge of the operator's personal SSH config.

## Prevention / Rule
**Guardrail:** For a single-target deploy script, default the target in the script itself (with env-var override still available for a second target later) and name that target explicitly in the README's Deploy section, rather than relying on an example placeholder (`deployer@example-vps`) plus undocumented personal `~/.ssh/config` knowledge.

This closes the gap because the next person (or agent) to deploy no longer needs to already know an SSH alias that exists only on one operator's machine — the default is right there in version control.

## Solution

### Immediate Fix
Changed the three `: "${VAR:?...}"` hard requirements in `deploy.sh` to `"${VAR:-default}"` with `MARICHO_VPS=restk-vps`, `MARICHO_DOMAIN=maricho.restk.tech`, `MARICHO_WS_URL=wss://maricho.restk.tech` as defaults. Updated `deploy/production/README.md`'s Deploy section to show the now-argument-free `deploy/production/deploy.sh` invocation, note that `restk-vps` is an SSH config alias to set up on a new machine, and show the env-var override path for deploying elsewhere.

### Long-term Fix
None further needed — the script still supports overriding every value for a future second environment (staging, a second region, etc.).

## Prevention
- [x] Documentation to update (done — see Immediate Fix)
- [x] Code changes required (done — see Immediate Fix)

## Related Issues
- None

## References
- PR #13 deploy (Maritcho) — this surfaced while deploying that PR's merge commit to `restk-vps`

---

**Resolved By:** Claude (deploy follow-up)
**Time to Resolution:** Same session
