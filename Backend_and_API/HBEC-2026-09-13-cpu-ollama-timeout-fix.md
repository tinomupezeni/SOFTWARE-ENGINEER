# CPU Ollama Fallback Timed Out Prematurely Due to Missing Timeout Override

**Date:** 2026-09-13
**Project:** HBEC
**Environment:** Production / All
**Severity:** Medium
**Status:** Resolved

## Summary
The local CPU Ollama (`cpu-3b`), configured as the final degraded-mode fallback when both Groq/Gemini and the ZCHPC GPU are unreachable, was failing under load. Although it responded to health checks correctly, real generation requests were erroring out after exactly 20 seconds. This occurred because the `timeout: 330` override (which was applied to the GPU model) was completely missing for the CPU model in `litellm_config.yaml`.

## Symptoms
- All primary API providers (Gemini, Groq) exhausted/failed.
- The GPU tunnel was unreachable.
- Requests fell back to the CPU Ollama container.
- Requests failed reliably at the 20-second mark despite the CPU model still actively generating tokens in the background, because LiteLLM's default global router timeout (tuned for fast providers like Groq) severed the connection.

## Environment Details
- **Server/Host:** `hbca-vps` (Production)
- **Services Affected:** `litellm`, Local CPU Ollama
- **Time First Observed:** 2026-09-13

## Investigation Steps

### 1. Initial Diagnosis
Reviewing the router config revealed that while `gpu/qwen14b` had a `timeout: 330` override, `cpu-3b` had no timeout specified at all, falling back to the global `timeout: 20` defined at the bottom of the routing file. 

### 2. Root Cause Analysis
Since the CPU Ollama model runs on constrained hardware and takes significantly longer than 20 seconds to generate a full response, the router killed the connection before completion.

## Root Cause
A missing `timeout` override on the `cpu-3b` fallback model definition caused it to inherit a global 20-second timeout intended for high-speed cloud providers. 

## Prevention / Rule
**Guardrail:** When adding any local or self-hosted model (GPU or CPU) to the LiteLLM router, it must explicitly define a `timeout` override in `litellm_params` that exceeds the application's maximum allowed generation time. The global timeout should only apply to fast cloud APIs.

This guardrail ensures slow hardware is not preemptively disconnected by the router before it has a chance to return a completed generation.

## Solution

### Immediate Fix
Added `timeout: 330` to the `cpu-3b` model definition in `AGENTIC_HARNESS/litellm_config.yaml` and `.local.yaml`. Deployed this fix manually to `/opt/hbec/AGENTIC_HARNESS/litellm_config.yaml` on the production VPS and restarted the `litellm` service.

```bash
# Deployed config edit and restarted
sudo tee /opt/hbec/AGENTIC_HARNESS/litellm_config.yaml > /dev/null
sudo docker compose -f docker-compose.production.yml restart litellm
```

### Long-term Fix
None required; the configuration is now fixed in both git and production. 

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

---

**Resolved By:** Antigravity
**Time to Resolution:** 5m
