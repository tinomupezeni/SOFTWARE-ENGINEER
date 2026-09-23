# Measuring Student API Latency — Real Production Numbers + a Lasting Admin Dashboard Card

**Date:** 2026-09-23
**Project:** HBEC
**Type:** Audit / Feature
**Status:** Completed (staging), production promotion pending

## Summary
User asked to start measuring how fast HBEC's APIs are, beginning with the
Student backend. Investigation found the instrumentation for this already
existed and was already collecting real data — `django_prometheus` exposes
per-endpoint latency histograms, already scraped on both staging and
production. Pulled real numbers from production's Prometheus immediately,
then built a lasting Student API Latency card on the Admin dashboard (not
Grafana, per explicit instruction — nobody visits it) so this stays visible
going forward instead of being a one-off answer.

## Context / Trigger
"ok, now we want to measure how fast our apis are for tis systeme, starting
with the student side first." Two follow-up decisions from the user during
scoping: measure from production's real Prometheus data rather than a
synthetic staging load test, and make the lasting visibility an Admin
dashboard card rather than a Grafana panel, since "no one will be visiting
grafana."

## Scope
Student backend (`STUDENT/hbec_backend/`) API latency only, this pass.
Harness and Admin backend latency were not measured — Harness already has
its own p95 panel on the existing Grafana dashboard (unrelated to this work);
Admin was out of scope for "starting with the student side."

## Method
1. Checked what observability infrastructure already existed before building
   anything new: confirmed `django_prometheus` middleware is installed on
   Student backend, its `/metrics` endpoint is scraped by Prometheus on both
   `docker-compose.staging.yml` and `docker-compose.production.yml`, and the
   specific metric (`django_http_requests_latency_seconds_by_view_method`)
   was already present in a live `/metrics` response — no new instrumentation
   needed.
2. Queried production's Prometheus directly (read-only PromQL, `docker exec
   hbec-prometheus`) for p50/p95 latency and request count by view over both
   24h and 7d windows, to get real numbers immediately and to check whether a
   day's data was representative or a fluke.
3. Investigated the two latency outliers found by reading the actual view
   code, not by guessing from the endpoint name.
4. Built the lasting dashboard feature by extending the exact pattern this
   codebase already uses for a Prometheus-backed dashboard card
   (`DashboardLLMUsageView`), rather than inventing a new one.

## Decisions & Findings

**The real numbers (production, 7-day window):**
- `payment_initiate` — p50 3.75s, p95 4.875s, n=5. `InitiatePaymentView`
  proxies synchronously to the Payments microservice, which itself calls
  Paynow or ZB — real Zimbabwean mobile-money gateways with inherent
  multi-second initiation latency. Not a bug in HBEC's own code; the
  `timeout=15.0` and 502-on-connection-error handling already in place are
  a reasonable defensive posture for a slow third party.
- `ai_gateway:login-help` — p95 3.5s, n=12. `LoginHelpView` calls the
  Harness's LLM for the pre-login "Friday" assistant. Slow because it's an
  LLM call, which the view's own docstring already treats as expected
  (degrades to an empty answer rather than a 500 or a long hang).
- Everything else measured is fast: most student-facing views sit at
  20–250ms p95, including auth (`google-auth` 950ms is the next slowest,
  still reasonable for bcrypt + a DB round trip), curriculum reads,
  subscription status, and the AI gateway's proxy/analytics endpoints.

**Sample sizes are currently very small.** Most endpoints see under 30
requests per week on production right now (early/soft-launch traffic
levels, not the 800–1500 concurrent users the VPS is sized for). A p95 on
2–5 samples is really just "the slower of a handful," not a stable
statistic — this shaped the dashboard design (see below) rather than being
a caveat buried in a report nobody rereads.

**Measurement source decision:** production's real Prometheus over a
synthetic staging load test. Staging carries almost no traffic (mostly this
session's own smoke-test calls), so a load test there would measure a
script hitting an idle box, not real usage patterns. Production access was
read-only PromQL — no code or config touched, no risk.

**Visibility decision:** an Admin dashboard card over a Grafana panel,
per explicit instruction that nobody actually opens Grafana day to day.
Extends `apps/dashboard/` rather than adding a new app, matching how
`DashboardLLMUsageView` already surfaces Prometheus-backed data on the same
dashboard.

## Changes Made

**Admin backend:**
- `apps/model_settings/tasks.py` — renamed the private `_query_prometheus`
  to public `query_prometheus_instant` (matching the already-public
  `query_prometheus_range` naming), so `apps/dashboard/views.py` can reuse
  it instead of duplicating an HTTP-calling helper. 8 call sites updated in
  the same file.
- `apps/dashboard/views.py` — new `DashboardStudentApiLatencyView`
  (`GET /dashboard/student-api-latency/`), `?window=` validated against an
  allowlist (`1h`/`24h`/`7d`/`30d`) before interpolation into PromQL, since
  it's a raw query-string value reaching a query language, not free text.
  Returns `{available, window, views: [{view, requests, p50Ms, p95Ms}]}`,
  sorted slowest-first, self-scrape noise (`prometheus-django-metrics`)
  excluded, NaN (zero-sample) views dropped rather than shown as 0ms.
  Degrades to `{available: false, views: []}` on any Prometheus failure.
- `apps/dashboard/urls.py` — route added.
- `apps/dashboard/tests/test_student_api_latency.py` — 6 new tests: sort
  order, noise exclusion, graceful degradation, window allowlist rejection
  (including a literal injection-shaped value), a known window passing
  through correctly, and NaN/zero-sample handling.

**Admin frontend:**
- `src/features/dashboard/types/index.ts` — `StudentApiLatencyView`,
  `StudentApiLatency` types.
- `src/features/dashboard/api/dashboardApi.ts` — `getStudentApiLatency()`.
- `src/features/dashboard/hooks/useStudentApiLatency.ts` — polls every 2
  minutes (no scheduled sync behind this endpoint, unlike LLM usage, so it
  can poll less eagerly without going stale), holds the window selection.
- `src/features/dashboard/components/StudentApiLatencyCard.tsx` — mirrors
  `LLMUsageCard`'s layout. Shows the 10 slowest endpoints by p95, p50 and
  request count beside each. An endpoint under 20 requests in the window
  gets an inline `*` flag and a footnote explaining why — the point of
  showing request counts at all is to stop a thin sample from reading as a
  stable measurement. Window selector (1h/24h/7d/30d). Honest states for
  "Prometheus unreachable" (distinct from) "no traffic in this window."
  6 new component tests.
- `DashboardPage.tsx` — card wired in alongside `LLMUsageCard`.

## Verification
- Backend: 737/737 tests passing (throwaway Postgres), `ruff check` clean.
- Frontend: 246/246 tests passing, `tsc -b --noEmit` clean.
- Staging: both services rebuilt and redeployed, confirmed healthy. Live
  smoke test against the real endpoint: 200 OK, real Prometheus queries
  executing (visible in logs), 25 views returned correctly sorted, sample
  counts as low as n=1 correctly surfaced rather than hidden, a
  deliberately malformed `window` value correctly fell back to the safe
  default rather than reaching PromQL.

## Follow-ups / Deferred
- **Production promotion not yet requested or done.** The real numbers this
  report cites came from a read-only query against production's Prometheus,
  not from deploying this code there — the dashboard card itself is only
  live on staging so far, per this session's standing production-caution
  practice. Promoting it is a normal admin-backend/frontend deploy once
  requested.
- Harness and Admin backend latency were not measured in this pass.
- The two slow endpoints found are architectural (proxying to a slow third
  party), not bugs — no fix proposed or expected here; flagged for
  awareness (e.g. confirming the frontend shows a loading state during a
  4-second payment initiation) rather than remediation.

## References
- `ADMIN/adminBackend/apps/dashboard/views.py`
  (`DashboardStudentApiLatencyView`)
- `ADMIN/adminBackend/apps/model_settings/tasks.py`
  (`query_prometheus_instant`, renamed from `_query_prometheus`)
- `ADMIN/adminFrontend/src/features/dashboard/components/StudentApiLatencyCard.tsx`
- `STUDENT/hbec_backend/apps/accounts/views.py` (`InitiatePaymentView`)
- `STUDENT/hbec_backend/apps/ai_gateway/views.py` (`LoginHelpView`)
- `monitoring/prometheus.staging.yml`, `monitoring/prometheus.production.yml`
  (confirmed `student-backend` already scraped)

---

**Completed By:** Claude Sonnet 5
**Duration:** Same session — investigation, real-data pull, feature build,
and staging verification.
