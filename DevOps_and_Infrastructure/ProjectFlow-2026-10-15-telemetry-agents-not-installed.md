# Telemetry Agents Were Not Installed

**Date:** 2026-10-15
**Project:** ProjectFlow
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
The VPS Observability page showed three registered VPSes but no health data because registration only created database records; it did not install or start telemetry agents on the hosts. Production also lacked the backend token map required to authenticate heartbeat ingestion.

## Symptoms
- All registered VPSes displayed `Unknown`.
- Every VPS showed `Never` for the last heartbeat.
- No active alerts or recent events were present.
- The production backend had no configured telemetry token map.

## Environment Details
- **Server/Host:** `hbca-vps`, `restk-vps`, `chemglee-vps`
- **Services Affected:** ProjectFlow observability dashboard and heartbeat ingestion
- **Related Components:** `scripts/vps_telemetry_agent.py`, systemd/cron, production Compose environment
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
The production database was queried for registered VPS records and heartbeat counts. All three records existed, but each had zero heartbeats.

### 2. Root Cause Analysis
The documented rollout included an agent installation procedure, but deployment only ran `register_vpses`; it did not provision the agent on any registered host or configure `VPS_TELEMETRY_TOKENS` in production. The hosts had empty `/opt/projectflow` directories and no active telemetry service.

### 3. Key Findings
- `register_vpses` registers metadata only; it does not produce telemetry.
- The heartbeat endpoint rejects requests without a matching per-VPS token.
- `hbca-vps` allowed non-interactive sudo; `restk-vps` and `chemglee-vps` required interactive sudo passwords.
- All hosts had Docker access through their users' Docker group.

## Root Cause
Telemetry infrastructure was documented but not included in the deployment execution path. The dashboard therefore rendered valid empty-state data rather than live infrastructure state.

## Prevention / Rule
**Guardrail:** Add a production observability smoke check that asserts every enabled VPS has a heartbeat newer than its configured timeout before a deployment is considered complete.

This catches the exact gap between database registration and agent delivery, and prevents a deployment from being reported healthy while the dashboard has no telemetry.

## Solution

### Immediate Fix
- Generated unique tokens for `hbca-vps`, `restk-vps`, and `chemglee-vps`.
- Configured the production backend token map.
- Installed the telemetry agent and user cron schedule on all three VPSes.
- Used the systemd path where passwordless sudo was available and a user-owned cron fallback elsewhere.

### Long-term Fix
Include agent provisioning and the heartbeat smoke check in the production rollout automation. Keep per-host tokens in managed secrets rather than source-controlled Compose configuration.

## Prevention
- [x] Configuration changes needed
- [x] Monitoring/alerts to add
- [x] Documentation to update
- [ ] Code changes required

## Related Issues
- ProjectFlow observability UI and viewer-access rollout records.

## References
- `projectflow_backend/scripts/vps_telemetry_agent.py`
- `projectflow_backend/docs/observability-rollout.md`
- `projectflow_backend/deploy/projectflow-vps-telemetry.service`

---

**Resolved By:** Copilot
**Time to Resolution:** Same session
