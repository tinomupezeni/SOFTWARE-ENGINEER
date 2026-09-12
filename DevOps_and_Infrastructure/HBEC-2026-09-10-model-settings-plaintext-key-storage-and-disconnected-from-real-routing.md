# Admin's Model Settings Feature Stored Keys in Plaintext and Never Actually Drove Live LLM Routing

**Date:** 2026-09-10
**Project:** HBEC
**Environment:** Development → Staging (fixed and verified)
**Severity:** High
**Status:** Resolved (staging only — not yet promoted to production per explicit instruction)

## Summary
ProjectFlow task "HBCA Admin — API Key Management and Usage observation"
led to finding the existing `apps/model_settings` admin feature (a fully
built Adapters/Routing/API Keys UI + CRUD backend) had two serious problems:
`ApiKeyEntry.encrypted_key` stored real provider API keys as plaintext
despite the field name, and the entire feature was completely disconnected
from the platform's actual LLM routing — creating an adapter or key here
had zero effect on any real request, and the "usage" stats shown were
always zero because nothing ever wrote to them.

## Symptoms
No user-facing error — the feature looked fully functional (forms submit,
data saves, a "Test Adapter" button exists) while silently doing nothing to
real routing. Requests continued being routed entirely by the separate,
statically-configured `litellm_config.yaml`.

## Environment Details
- **Server/Host:** hbca-vps (staging, where this is now deployed and verified)
- **Services Affected:** Admin Backend (`apps/model_settings`), LiteLLM proxy container
- **Time First Observed:** 2026-09-10, investigating a ProjectFlow task

## Investigation Steps

### 1. Initial Diagnosis
Read `ApiKeyCreateSerializer.create()` — stores `key` directly into
`encrypted_key` with no cipher applied at all.

### 2. Root Cause Analysis
Traced the actual LLM call path: `AGENTIC_HARNESS/app/shared/llm_client.py`
never reads `litellm_config.yaml` — it makes HTTP calls to a *separate*
`litellm` proxy container, which is the only thing that reads that file
(mounted read-only). The admin's `ModelAdapter`/`ApiKeyEntry` tables had no
relationship to that file or that container at all. Two Celery tasks
(`replicate_model_config_to_harness`, `replicate_agent_config_to_harness`)
existed that looked like they should bridge this gap — both signed,
HMAC-verified, fully built — but neither was ever called from anywhere
(confirmed via full-repo grep for callers and Celery Beat schedule
entries), and the harness's receiver for both event types was an explicit
no-op logger, not a real handler. Even if wired up, that would have been
the wrong target anyway — the harness doesn't own routing config, the
separate proxy does.

### 3. Key Findings
- `ModelAdapter.metrics` / `ApiKeyEntry.last_used` were genuinely dead
  fields — schema existed, serializers/admin read them, nothing in the
  whole repo ever wrote to them.
- LiteLLM's own runtime Admin API (`/model/new`, `/model/update`,
  `/model/delete` — POST verb, not DELETE) was unused anywhere in the repo,
  and requires `STORE_MODEL_IN_DB=True` (a real database connection) to
  work at all — the proxy had none configured.
- Real per-model usage telemetry already existed and was sitting unused:
  the harness's Prometheus metrics (`harness_llm_calls_total`,
  `harness_llm_latency_seconds`) are populated on every real LLM call
  already, via `llm_client.py`'s `_record_metrics()`.

## Root Cause
The admin feature was built as UI + CRUD scaffolding with the intended
integration points stubbed (a no-op receiver, a dead Celery task, a
metrics field nothing writes to) and never finished — and separately, the
key-storage field was never actually wired to real encryption despite its
name implying it was.

## Prevention / Rule
**Guardrail:** (1) A custom model field type (`EncryptedCharField`) that
performs real encryption/decryption transparently at the ORM layer, so a
field can never be named "encrypted_*" without actually being encrypted —
a plain `CharField` can't masquerade as one. (2) A CI check that fails on
any Celery task, signal receiver, or "integration point" function with zero
call sites and zero test invocations anywhere in the repo — dead scaffolding
can't silently ship as a finished integration.

Both clauses map directly onto this bug's two independent causes: a
misleadingly-named plaintext field, and a fully-built but never-wired
integration path that nothing forced anyone to notice was inert.

## Solution

### Immediate Fix
- Real Fernet encryption for stored provider keys
  (`apps/model_settings/crypto.py`), keyed by a new
  `MODEL_SETTINGS_ENCRYPTION_KEY` setting.
- `LiteLLMAdminClient` (`apps/model_settings/litellm_client.py`) wraps the
  proxy's actual Admin API. Adapter create/update/delete/status views now
  apply synchronously to the live proxy, surfacing failures as 502s.
- Gave the LiteLLM proxy its own database (`hbec_litellm`, on the existing
  shared Postgres) so `STORE_MODEL_IN_DB` could be enabled — verified this
  did not disrupt existing routing (a real completion request through an
  existing config-defined model succeeded immediately after the restart).
- New Celery Beat task (`sync_model_usage_metrics`, every 5 minutes) reads
  Prometheus and finally populates `ModelAdapter.metrics`/`.last_used`.
- Full lifecycle verified live on staging: created a real adapter, confirmed
  it appeared on the live proxy via `/model/info` with a real assigned id,
  deleted it, confirmed it was actually removed from the proxy.

### Long-term Fix
None needed beyond the above — this is the complete fix. Not yet promoted
to production; staying on staging until explicitly told to promote.

## Prevention
- [x] Fixed and verified end-to-end on staging (38 new/updated tests, full
      admin backend suite of 526 tests still green)
- [ ] Promote to production when instructed

## Related Issues
- The dead `replicate_model_config_to_harness`/`replicate_agent_config_to_harness`
  tasks and their no-op harness-side receiver were left untouched
  (confirmed dead but harmless, and pointed at the wrong system for this
  purpose) — a separate decision for whoever owns that code, not part of
  this fix.

## References
- `ADMIN/adminBackend/apps/model_settings/` (crypto.py, litellm_client.py,
  apply.py, tasks.py — all new; views.py, serializers.py, models.py updated)
- `AGENTIC_HARNESS/app/shared/llm_client.py`, `app/shared/observability/metrics.py`
- `docker-compose.staging.yml` / `docker-compose.production.yml` (litellm
  service DB connection, admin-backend/admin-worker new env vars)
- `docker/init-db.sql` (new `hbec_litellm` database)

---

**Resolved By:** Claude (Sonnet 5), pairing with Tinotenda Mupezeni
**Time to Resolution:** Same session (staging only)
