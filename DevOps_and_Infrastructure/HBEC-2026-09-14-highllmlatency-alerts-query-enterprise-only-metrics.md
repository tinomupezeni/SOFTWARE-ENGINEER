# `HighLLMLatency` and `HighLLMErrorRate` Alerts Can Never Fire — They Query LiteLLM Enterprise-Only Metrics on an OSS Build

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
While verifying the observability stack after the 2026-09-13 AI outage,
confirmed that two of the alert rules meant to catch exactly that kind of
incident — `HighLLMLatency` and `HighLLMErrorRate` in
`monitoring/alerts.yml` — reference Prometheus metrics
(`litellm_request_duration_seconds_bucket`, `litellm_request_total`) that
the deployed LiteLLM proxy never emits. Enabling the `prometheus` callback
(this session's own fix, see `HBEC-2026-09-13-production-litellm-config-
drift-from-git.md`) turned the `/metrics` endpoint on and cleared the
`ServiceDown` alert for the `litellm` scrape target, but the per-request
metrics these two alert rules actually depend on are gated behind a LiteLLM
Enterprise license and are simply absent from the OSS build running in
production. These two rules have been silently unfireable since they were
written.

## Symptoms
- No visible symptom — the rules simply never fire, under any condition,
  including the exact outage they were written to catch.
- `/metrics` on `hbec-litellm` returns `200` (looks healthy) while
  containing none of the series either rule queries.

## Environment Details
- **Server/Host:** hbca-vps, `hbec-litellm`
- **Services Affected:** Alertmanager rule evaluation for `HighLLMLatency`,
  `HighLLMErrorRate`
- **Related Components:** `monitoring/alerts.yml`, `hbec-prometheus`
- **Time First Observed:** 2026-09-14

## Investigation Steps

### 1. Initial Diagnosis
Queried Prometheus directly for the metric either rule depends on:
```bash
curl -s 'http://localhost:6090/api/v1/query' \
  --data-urlencode 'query=rate(litellm_llm_api_failed_requests_metric_total[15m])'
# {"status":"success","data":{"resultType":"vector","result":[]}}
```
Empty result even though the litellm scrape target itself is `up`.

### 2. Root Cause Analysis
```bash
curl -s 'http://localhost:6090/api/v1/label/__name__/values' | grep litellm
# litellm_not_a_premium_user_metric_created
# litellm_not_a_premium_user_metric_total
```
Read the raw `/metrics` output directly from the container: the only
`litellm_*` series exposed is `litellm_not_a_premium_user_metric_total`,
whose own `HELP` text says it outright:
> 🚨 Prometheus Metrics is on LiteLLM Enterprise. You must be a LiteLLM
> Enterprise user to use this feature... If you have a license please set
> `LITELLM_LICENSE` in your env.

Confirmed `monitoring/alerts.yml`'s `HighLLMLatency` and `HighLLMErrorRate`
rules query `litellm_request_duration_seconds_bucket` and
`litellm_request_total` — neither of which exists on this deployment and
never will without a paid LiteLLM Enterprise license.

### 3. Key Findings
- `HarnessLLMErrorRate` (a third, separate rule in the same file) queries
  `harness_llm_calls_total`, a metric the harness itself emits from its own
  `/metrics` endpoint (not litellm's) — confirmed this one IS populated and
  working correctly. Only the two rules that depend on litellm's own
  Prometheus integration are dead.
- This means the actual working safety net against a repeat of the
  2026-09-13 outage is `HarnessLLMErrorRate` alone; the two litellm-native
  rules have added zero real coverage since they were written, despite
  appearing configured and despite their target now reporting `up=1`.

## Root Cause
`monitoring/alerts.yml`'s `HighLLMLatency`/`HighLLMErrorRate` rules were
written against LiteLLM's documented Prometheus metric names without
confirming those metrics are actually emitted by the OSS distribution in
use — they are gated behind LiteLLM's Enterprise tier and require
`LITELLM_LICENSE` to be set, which this deployment does not have.

## Prevention / Rule
**Guardrail:** Any alert rule added against a third-party service's metrics
must be verified against that service's actual `/metrics` output in the
target environment before being considered done — not just against its
documentation. A lightweight version of this: a one-line CI/deploy check
that greps `alerts.yml` for every metric name it queries and confirms each
one appears at least once in a live `/metrics` scrape, failing loudly if a
rule references a metric the stack can never produce.

This closes the gap because the failure mode here is structural: a rule
that "looks" correctly configured (valid PromQL, a real-looking metric
name) but can never fire has no natural signal telling anyone it's dead —
it just quietly does nothing forever.

## Solution

### Immediate Fix
Chose option 2 (rewrite against the harness's own metrics — free, reuses
already-proven-live infrastructure):
- `HighLLMLatency` now queries `harness_llm_latency_seconds_bucket`
  (`app/shared/llm_client.py:90` records this on every real call, already
  scraped and working), grouped `by (model)` instead of being a single
  job-wide check.
- `HighLLMErrorRate` was dropped outright rather than rewritten — it would
  have duplicated `HarnessLLMErrorRate`, which already computes the exact
  same signal per-model off `harness_llm_calls_total`.

Validated with `promtool check rules` before deploying, then applied
directly to both `/opt/hbec/monitoring/alerts.yml` (production) and
`/home/winstontino/HBEC/monitoring/alerts.yml` (staging), each backed up
first, and reloaded via each Prometheus's `/-/reload` (`--web.enable-lifecycle`
is set on both, so no container restart needed for production).

A second, unrelated bug surfaced on staging while verifying this fix —
logged separately as
`HBEC-2026-09-14-staging-prometheus-stale-bind-mount-ignored-reload.md`.

Verified via each Prometheus's `/api/v1/rules` that `HighLLMLatency` is
now live with `health: ok` and `HighLLMErrorRate` is gone, on both
environments.

### Long-term Fix
None needed beyond the guardrail above — this is now closed.

## Prevention
- [x] Configuration changes needed — done (option 2)
- [ ] Monitoring/alerts to add — a metric-existence check as described in
      the Guardrail above would still be worth adding generally (this
      instance is fixed, but nothing prevents a future rule being written
      against a metric that doesn't exist)
- [ ] Documentation to update — none yet
- [x] Code changes required — done

## Related Issues
- `HBEC-2026-09-13-production-litellm-config-drift-from-git.md` — the
  Prometheus-callback fix from that entry is what made this gap visible
  (the litellm scrape target went from `down` to `up`, but the rules that
  actually mattered were still querying nothing).
- `HBEC-2026-09-14-monitoring-profile-containers-never-started-on-production.md`
  — same overall observability initiative, same incident driving both.

## References
- `monitoring/alerts.yml`
- LiteLLM Enterprise Prometheus docs (metric availability gated by
  `LITELLM_LICENSE`)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session as discovery
