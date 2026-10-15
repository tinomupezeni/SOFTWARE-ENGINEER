# AI paper generation repeatedly unavailable because the free GPU provider is unreachable

**Date:** 2026-10-15
**Project:** HBEC
**Environment:** Production
**Severity:** Medium
**Status:** Investigating

## Summary
The production AI paper-generation endpoint is repeatedly returning a
controlled `503 gpu_unavailable` response because the configured free GPU
model is unavailable. The response is honest and avoids a raw 500, but paper
generation remains unavailable until the provider recovers or the operator
chooses the paid model.

## Symptoms
- `POST /api/v1/admin/papers/generate` returned `503` with
  `error_code: gpu_unavailable` at 2026-10-15 06:34–08:53 UTC.
- The latest recorded incident was 2026-10-15 08:53:45 UTC.
- The Harness logs repeatedly report failed connectivity checks for
  `gpu/qwen14b` and `ollama/llama3.2:3b`.
- The green/live and blue/idle Harness containers both show the same
  self-hosted-provider connectivity warnings.

## Environment Details
- **Server/Host:** `hbca-vps`, `/opt/hbec`
- **Services Affected:** `hbec-harness-green`, `hbec-harness-blue`
- **Related Components:** AI paper generation, LiteLLM/self-hosted model
  routing, GPU provider connectivity
- **Time First Observed:** 2026-10-15 06:34 UTC in the stored error log

## Investigation Steps

### 1. Initial Diagnosis
Inspected both deployed Harness containers' Docker logs and queried the
admin backend's shared `system_error_logs` table for
`/api/v1/admin/papers/generate`.

### 2. Root Cause Analysis
The stored errors identify the controlled failure as `gpu_unavailable`, while
Harness logs show repeated connection failures for the self-hosted GPU and
Ollama model checks. Both active and inactive color Harness instances report
the same provider reachability problem.

```bash
sudo docker logs hbec-harness-green --since 7d
sudo docker logs hbec-harness-blue --since 7d
python manage.py shell -c '...SystemErrorLog...'
```

### 3. Key Findings
- 27 paper-generation `503 gpu_unavailable` records are present in the
  current error inventory.
- The service is healthy and the failure is surfaced as an intentional
  application response, not a crash-loop or unhandled exception.
- The same provider failure is visible on both colors, so switching traffic
  would not restore free GPU generation.

## Root Cause
The free/self-hosted AI provider required by the current paper-generation
route is unreachable from production. The application correctly converts
provider exhaustion into a controlled `503`, but no healthy free-provider
capacity is currently available.

## Prevention / Rule
**Guardrail:** The deployment and production health checks must include an
authenticated, non-mutating AI provider readiness probe for every model route
advertised to administrators, and paper generation must remain disabled or
clearly marked unavailable when the free route fails.

This prevents the UI from presenting an apparently usable free-generation
path when the provider is unreachable, while preserving the existing
controlled `503` behavior.

## Solution

### Immediate Fix
No infrastructure change was made during this investigation. The existing
controlled `503 gpu_unavailable` response is the current safe fallback.

### Long-term Fix
- Add a provider-specific readiness check with latency and failure metrics.
- Expose provider availability to the admin generation UI before submission.
- Confirm the GPU endpoint/model alias and network reachability on the VPS.
- Keep a tested paid-model fallback or an explicit operator recovery path.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- `HBEC-2026-10-05-harness-paper-generate-unhandled-duplicate-identity-and-invalid-output.md`
- `HBEC-2026-09-09-litellm-router-timeout-killed-gpu-calls-before-harness-timeout-mattered.md`

## References
- Production `system_error_logs` entries for
  `/api/v1/admin/papers/generate`
- Docker logs from `hbec-harness-green` and `hbec-harness-blue`

---

**Resolved By:** Copilot
**Time to Resolution:** Investigation recorded; provider recovery pending
