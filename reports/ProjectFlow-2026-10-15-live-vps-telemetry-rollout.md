# Live VPS Telemetry Rollout

**Date:** 2026-10-15
**Project:** ProjectFlow
**Type:** Observability rollout
**Status:** Completed

## Summary
Installed and activated telemetry agents for the three registered ProjectFlow VPSes and connected them to the production observability backend. The dashboard now receives real resource and container telemetry instead of showing empty registration records.

## Context / Trigger
The newly deployed VPS Observability page showed three registered machines but all were `Unknown` with `Never` heartbeat timestamps. Investigation was required to determine whether the issue was frontend rendering, backend ingestion, or missing host-side telemetry.

## Scope
Included production token configuration, agent installation, scheduling, heartbeat verification, and live data validation for `hbca-vps`, `restk-vps`, and `chemglee-vps`. This did not include redesigning the dashboard or changing user permissions.

## Method
Compared database registrations with heartbeat records, inspected each VPS for the agent and service, verified Docker and Python prerequisites, provisioned unique tokens, installed the agent using the available privilege model, and checked fresh database heartbeats and metric values.

## Decisions & Findings
- Registration and telemetry are separate operations; `register_vpses` does not install an agent.
- Each VPS uses a unique token mapped by `vps_id`.
- User cron was used where interactive sudo prevented systemd installation, because the users already had Docker socket access and the agent does not require root privileges for its current metrics.
- The existing agent logs a harmless `caddy` command error on hosts without the expected Caddy CLI, but still submits successful heartbeats.

## Changes Made
- Added the production `VPS_TELEMETRY_TOKENS` map.
- Installed the telemetry script and schedules on all three registered VPSes.
- Activated periodic heartbeat submission to `/api/observability/heartbeat/`.

## Verification
- Each VPS had multiple heartbeat rows after installation.
- Latest heartbeat age was approximately 35 seconds for all three hosts.
- Live values were received:
  - `chemglee-vps`: CPU 3.55%, memory 40.7%, disk 40.0%.
  - `hbca-vps`: CPU 1.36%, memory 34.1%, disk 62.0%.
  - `restk-vps`: CPU 0.49%, memory 47.8%, disk 36.0%.
- Heartbeat ingestion returned HTTP 201 from each agent.

## Follow-ups / Deferred
- Add a deployment smoke check requiring a recent heartbeat for every enabled VPS.
- Move the token map into managed production secrets.
- Make the agent's service checks host-configurable and avoid logging expected missing commands as errors.
- Add an explicit systemd/cron health indicator to the observability dashboard.

## References
- `DevOps_and_Infrastructure/ProjectFlow-2026-10-15-telemetry-agents-not-installed.md`
- `projectflow_backend/scripts/vps_telemetry_agent.py`
- `projectflow_backend/docs/observability-rollout.md`

---

**Completed By:** Copilot
**Duration:** Same session
