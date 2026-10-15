# Student AI paper generation still failed on active color with malformed JSON

**Date:** 2026-10-15
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Investigating

## Summary
A student tried to generate an Agriculture AI paper three times on the active
production color. Each request was accepted and returned a generation job, but
the asynchronous Harness job failed with `ValueError: The AI response was not
valid JSON`. The student therefore saw a failed generation rather than a
paper. The malformed-output repair change exists in the deployed idle blue
color, but public traffic is still on green, which runs the older revision.

## Symptoms
- Three Agriculture generation jobs were started for the same student between
  2026-10-15 08:46:45 and 08:47:49 UTC.
- Each start request returned `202 Accepted`.
- Each job was polled successfully with `200 OK`.
- Each job then emitted `paper_generation_failed`.
- The exception was:
  `ValueError: The AI response was not valid JSON`.
- The failure was recorded inside the asynchronous job and did not create a
  new HTTP 500 system-error entry.

## Environment Details
- **Server/Host:** `hbca-vps`, `/opt/hbec`
- **Services Affected:** `hbec-student-backend-green`, `hbec-harness-green`
- **Related Components:** Student AI paper gateway, Harness paper generator,
  asynchronous Redis-backed generation jobs, blue-green deployment
- **Time First Observed:** 2026-10-15 08:46:45 UTC

## Investigation Steps

### 1. Initial Diagnosis
Traced the student frontend request to:

```text
POST /api/ai/papers/generate/
GET  /api/ai/papers/generate/{job_id}/
```

The Student Backend forwarded the request to:

```text
POST /api/v1/exam-practice/papers/generate
GET  /api/v1/exam-practice/papers/generate/{job_id}
```

### 2. Root Cause Analysis
Production logs on `hbec-student-backend-green` showed the student request
being sent to `harness-green` and accepted. Harness logs then showed three
`paper_generation_failed` events. The stack ended in
`paper_generator._extract_json()`, which rejected the provider response.

The active color was:

```text
green = 9ae140
```

The idle color containing the bounded malformed-JSON repair implementation
was:

```text
blue = 1a3b4ec
```

Therefore, the fix had been deployed and live-tested on blue but had not yet
been cut over to the color receiving student traffic.

### 3. Key Findings
- This was not the current `gpu_unavailable` admin-generation failure.
- The student request path returned a normal `202` followed by normal `200`
  polling responses; the terminal failure was contained in the job payload.
- The frontend already displays the returned job error, but the active backend
  still lacked the repair behavior.
- Middleware-based system-error reporting does not capture asynchronous job
  failures, so the incident was visible in container logs but not in the
  central error inventory.

## Root Cause
The malformed-JSON repair was present only on the inactive blue deployment.
Student traffic remained on the older active green revision, so provider
responses that could have received one bounded repair attempt still failed the
job immediately.

## Prevention / Rule
**Guardrail:** A blue-green deployment must not be considered complete for a
behavioral fix until the active-color decision is explicit and every
asynchronous job failure is persisted with its terminal error code and
revision; the deployment checklist must verify the intended color before
closing an incident.

This prevents a fix validated on the idle color from being mistaken for a
production fix, and makes background-job failures searchable without relying
on Docker log retention.

## Solution

### Immediate Fix
No traffic switch was made during this investigation. Blue already contains
the malformed-JSON repair and passed its deployment/health gates.

### Long-term Fix
- Decide whether to cut over blue after its normal approval and observation
  window.
- Persist terminal generation failures in the job record and central error
  telemetry with a stable error code.
- Add a generation-failure metric separated by provider failure, malformed
  output, timeout, and validation failure.
- Add an end-to-end test that submits a student generation request through the
  active-color proxy and exercises the repair path.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code/deployment state identified

## Related Issues
- `HBEC-2026-10-05-harness-paper-generate-unhandled-duplicate-identity-and-invalid-output.md`
- `HBEC-2026-10-15-ai-paper-generation-gpu-unavailable.md`

## References
- `STUDENT/Frontend/src/features/exam-practice/api/generateApi.ts`
- `STUDENT/hbec_backend/apps/ai_gateway/views.py`
- `AGENTIC_HARNESS/app/exam_practice/router.py`
- `AGENTIC_HARNESS/app/exam_practice/services/paper_generator.py`
- Production logs from `hbec-student-backend-green` and
  `hbec-harness-green`

---

**Resolved By:** Copilot
**Time to Resolution:** Investigation recorded; active-color remediation pending
