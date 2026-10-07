# Setup k6 and Grafana Telemetry Stack for Load Testing

**Date:** 2026-10-07
**Project:** TESC
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
The TESC project contained starter k6 scripts but lacked the necessary telemetry infrastructure (InfluxDB and Grafana) to visualize load test metrics and monitor real-time API response times.

## Symptoms
- Unable to visualize k6 load test results locally.
- Lack of historical test data for performance regression analysis.

## Environment Details
- **Server/Host:** Local Development
- **Services Affected:** Load Testing Infrastructure
- **Related Components:** k6, Docker Compose
- **Time First Observed:** 2026-10-07

## Investigation Steps

### 1. Initial Diagnosis
Checked `tests/05_load/` and found existing k6 scripts (`load_test_all.js`), but a search through the Docker Compose files revealed no Grafana or TSDB containers were provisioned.

### 2. Root Cause Analysis
The project had the initial tools for load testing but hadn't wired the telemetry output into a visualization stack.

### 3. Key Findings
- k6 native output to InfluxDB (v1.8) is the standard method for Grafana visualization.
- Official Grafana dashboard (ID 2587) handles k6 metric schemas automatically.

## Root Cause
Incomplete setup of load testing telemetry infrastructure.

## Prevention / Rule
**Guardrail:** Provision isolated docker-compose telemetry stacks for load testing.
By maintaining a dedicated `docker-compose.loadtest.yml`, we ensure load testing infrastructure does not pollute the primary application deployment configurations while still providing deep observability.

## Solution

### Immediate Fix
Created `docker-compose.loadtest.yml` with InfluxDB and Grafana, added Grafana auto-provisioning configs for the InfluxDB datasource and k6 dashboard, and created a `run_load_test.sh` script to orchestrate the process.

### Long-term Fix
The telemetry stack is now persistently available via Docker Compose and easily bootable using the custom bash script.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- N/A

## References
- [k6 Grafana Integration](https://grafana.com/docs/k6/latest/results-output/real-time/influxdb-grafana/)
- [Grafana Dashboard 2587](https://grafana.com/grafana/dashboards/2587-k6-load-testing-results/)

---

**Resolved By:** Antigravity
**Time to Resolution:** 10 minutes
