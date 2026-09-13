# ZCHPC GPU Tunnel Unreachable & LiteLLM Timeout Configuration Drift

**Date:** 2026-09-13
**Project:** HBEC
**Environment:** Production
**Severity:** Medium
**Status:** Workaround Applied

## Summary
While investigating AI generation failures on production, it was found that the ZCHPC GPU tunnel (a fallback model) is unreachable (`Connection refused` on port 32508 of `zchpc.movellasystems.com`). Additionally, the production LiteLLM configuration lacked a critical `timeout: 330` fix for the `gpu/qwen14b` fallback, causing any requests sent to it to prematurely time out at 20s.

## Symptoms
- Systemd `autossh` tunnel shows active on `hbca-vps` but `curl` to the forwarded port fails.
- Direct connection to `zchpc.movellasystems.com:32508` is refused.
- Long-running inference queries on the ZCHPC GPU would time out after 20s if they actually reached it, due to missing configuration on the production `litellm_config.yaml`.

## Environment Details
- **Server/Host:** `hbca-vps` (Production)
- **Services Affected:** `litellm`
- **Related Components:** ZCHPC SSH Tunnel
- **Time First Observed:** 2026-09-13

## Investigation Steps

### 1. Initial Diagnosis
Checked the systemctl status on `hbca-vps` for the zchpc tunnel. The `autossh` process was running, forwarding local port `11436` to `11434` on `zchpc.movellasystems.com:32508`.

### 2. Root Cause Analysis
Tried to ping and curl the GPU Ollama port. Ping to `zchpc.movellasystems.com` succeeded, but `ssh` to port 32508 returned `Connection refused`. This indicates the remote GPU rental has likely expired, the IP has changed, or the SSH service was stopped/re-configured. 

Additionally, we compared `/opt/hbec/AGENTIC_HARNESS/litellm_config.yaml` on the VPS with the git repository and found that the `timeout: 330` override for `gpu/qwen14b` and `ollama/llama3.2:3b` was missing on production.

### 3. Key Findings
- The ZCHPC tunnel destination is unreachable.
- `litellm_config.yaml` on production is not synced with git and lacked the timeout override.

## Root Cause
Configuration drift between git and production caused the missing `timeout: 330` fix. The ZCHPC server port 32508 being closed is likely due to the GPU rental expiring or environment rebuild.

## Prevention / Rule
**Guardrail:** Configuration files deployed in `/opt/hbec` (such as `litellm_config.yaml`) must be deployed through CI/CD pipelines to ensure parity with the Git repository, rather than manual out-of-band edits, preventing fixes made in Git from being omitted in production.

This guardrail ensures fixes committed to source control (such as the timeout parameter override) are consistently deployed, eliminating manual omissions.

## Solution

### Immediate Fix
Manually injected the `timeout: 330` fix into the production `/opt/hbec/AGENTIC_HARNESS/litellm_config.yaml` configuration and restarted the `litellm` Docker container to ensure if the GPU comes back online, requests are not terminated at 20s.

```bash
# Deployed config edit and restarted
sudo tee /opt/hbec/AGENTIC_HARNESS/litellm_config.yaml > /dev/null
sudo docker compose -f docker-compose.production.yml restart litellm
```

### Long-term Fix
Investigate the status of the ZCHPC GPU node and restore the SSH port/tunnel if the service is still active. Transition `/opt/hbec` updates to an automated deployment process.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

---

**Resolved By:** Antigravity
**Time to Resolution:** 10m
