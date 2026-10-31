# Deployment link checks emit logs without useful telemetry identity

**Date:** 2026-10-31
**Project:** HBEC
**Environment:** Production (`hbca-vps`)
**Severity:** Low
**Status:** Investigating

## Summary
During the blue/green cutover, standalone service-link verification processes emitted JSON HTTP-client logs with `service.name` set to `unnamed-python-service` and `trace_id` and `span_id` set to null. The link checks themselves passed, but the logs cannot be reliably attributed to a service or trace.

## Symptoms
- Verification output included `"service.name": "unnamed-python-service"`.
- The same HTTP request logs included `"trace_id": null` and `"span_id": null`.
- All signed service links returned the expected status, so this affected observability rather than link behavior.

## Environment Details
- **Server/Host:** `hbca-vps`
- **Services Affected:** Standalone admin, student, and harness link-check commands.
- **Related Components:** `scripts/deploy/verify-service-links.sh`, Python logging and OpenTelemetry setup.
- **Time First Observed:** 2026-10-31 blue/green cutover.

## Investigation Steps

### 1. Initial Diagnosis
Read the structured output from `manual-deploy-color.sh` and `manual-cutover.sh`.

### 2. Root Cause Analysis
`verify-service-links.sh` starts separate Python commands with `docker exec`. The observed records show those command processes did not establish a service-specific telemetry identity and active span for their HTTP-client logs. The exact configuration point remains to be identified.

```bash
rg -n 'check_service_links|link_check' scripts/deploy/verify-service-links.sh
```

### 3. Key Findings
- The deployment link gate passed.
- The JSON fields existed but contained generic or null values.
- The topic repair management command itself emitted non-null trace and span IDs.

## Root Cause
The standalone verification command path lacks effective service naming and trace-context setup before logging outgoing requests. The specific missing configuration or initialization has not yet been traced.

## Prevention / Rule
**Guardrail:** Add a deployment-gate assertion that rejects verification command logs with a generic `service.name` or null `trace_id`/`span_id` for HTTP-client records.

This catches missing telemetry initialization in the same process that performs the link check.

## Solution

### Immediate Fix
The production link checks were functionally successful; this telemetry defect remains open.

### Long-term Fix
Initialize service-specific OpenTelemetry resource identity and an active span in each standalone link-check command, then enforce the assertion above.

## Prevention
- [ ] Fix telemetry initialization for standalone link checks.
- [ ] Add a log-field assertion to the deployment verification gate.

## Related Issues
- `DevOps_and_Infrastructure/HBEC-2026-10-31-deploy-images-include-untracked-source.md`

## References
- `scripts/deploy/verify-service-links.sh`

---

**Resolved By:** Pending
**Time to Resolution:** Ongoing
