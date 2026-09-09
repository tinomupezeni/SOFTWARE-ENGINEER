# litellm's Own Router Timeout Silently Overrode the Harness's Admin GPU Budget

**Date:** 2026-09-09
**Project:** HBEC
**Environment:** Staging
**Severity:** Critical
**Status:** Resolved

## Summary
Admin AI paper generation deterministically failed with `gpu_unavailable` on
every attempt, even though the GPU model, tunnel, and Ollama daemon were all
healthy. The harness's own `call_llm(timeout=300.0)` for admin requests
never got a chance to be the binding constraint.

## Symptoms
- Every admin paper generation returned `gpu_unavailable` (503) regardless
  of question count, including a request as small as 2 questions.
- Harness logs showed `llm_primary_timeout` at exactly `timeout_s: 300.0`,
  but a raw call to the GPU model with the same prompt/settings completed
  cleanly in ~58s.

## Environment Details
- **Server/Host:** hbca-vps (staging), GPU box zchpc.movellasystems.com
- **Services Affected:** Agentic Harness, litellm proxy
- **Related Components:** `litellm_config.yaml`, `app/shared/llm_client.py`
- **Time First Observed:** 2026-09-09, during admin bulk-generation testing

## Investigation Steps

### 1. Initial Diagnosis
Confirmed the GPU tunnel, Ollama daemon, and model were all healthy and
responsive via direct `curl`/`ollama` calls, ruling out infrastructure being
down.

### 2. Root Cause Analysis
Called the GPU model directly with the exact production prompt and
generation settings — completed in 58s, well under any reasonable timeout.
Then called litellm's own proxy endpoint with the identical payload:

```bash
curl -m 290 http://litellm:4000/v1/chat/completions -d @payload.json
# HTTP 500 at 113s: "litellm.Timeout: Connection timed out after 20.0 seconds"
```

### 3. Key Findings
- `router_settings.timeout: 20` in `litellm_config.yaml` applied to every
  model, including the GPU model — a value tuned for the fast paid pools
  (Groq/Gemini respond in ~1-2s), not for a model that genuinely needs 60s+.
- litellm's router-level timeout fires and triggers its own fallback logic
  well before the harness's own 300s `asyncio.wait_for` around the same
  call ever gets a chance to be the deciding factor.
- litellm's own configured fallback (`{"ollama/llama3.2:3b": ["cpu-3b"]}`)
  then also failed, compounding the failure (see companion issue on the
  crashed local CPU fallback container).

## Root Cause
litellm's global `router_settings.timeout` (20s) silently overrode the
harness's own per-call timeout for the admin/GPU path, killing every request
long before the model could realistically finish.

## Solution

### Immediate Fix
None separate from the long-term fix — this was a configuration value, not
a code path requiring a hotfix/rollback.

### Long-term Fix
Added a per-model `timeout: 330` override in `litellm_config.yaml` on both
GPU-tunnel model entries (`gpu/qwen14b`, `ollama/llama3.2:3b`), set above the
harness's own 300s admin ceiling so that ceiling — not litellm's router
default — is what actually governs.

## Prevention
- [x] Per-model timeout override for the GPU path
- [ ] Consider a general litellm/harness timeout-layering test that fails
      CI if any two timeouts in the call chain aren't strictly ordered
- [x] Documented the layering (litellm timeout > harness admin timeout >
      Django's `HarnessExtractionClient` timeout) in code comments

## Related Issues
- Companion: crashed local CPU Ollama fallback container (same debugging session)
- Companion: staging harness container OOM under concurrent admin load

## References
- `AGENTIC_HARNESS/litellm_config.yaml`
- `AGENTIC_HARNESS/app/shared/llm_client.py`
- Commit `e8d96fb1`

---

**Resolved By:** Claude (Sonnet 5), pairing with Tinotenda Mupezeni
**Time to Resolution:** Same session (~1 hour from symptom to deployed fix)
