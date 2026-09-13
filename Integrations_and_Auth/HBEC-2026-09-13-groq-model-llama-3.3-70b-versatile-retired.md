# Groq's `llama-3.3-70b-versatile` Was Retired From Its Catalog — Every Fallback Request Silently 404'd

**Date:** 2026-09-13
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
Investigating a "AI is not working" report on production, litellm logs
showed every Groq-routed request failing with `404 model_not_found: "The
model llama-3.3-70b-versatile does not exist or you do not have access to
it."` Confirmed directly against Groq's own `GET /v1/models`: the model is
genuinely gone from the account's catalog entirely, not a permissions or
billing problem — the API key itself returns `200` against that same
endpoint. Groq's model lineup had simply moved on (current catalog
includes `openai/gpt-oss-120b`, `openai/gpt-oss-20b`, `qwen/qwen3.8-27b`,
etc. — none of which existed under the old name).

Groq is the harness's designated fallback the moment Gemini (the primary
provider) fails — and Gemini was independently failing at the same time
(billing credits depleted, a separate finding), so with Groq also broken,
every LLM call that needed to fail over had nowhere real to land.

## Symptoms
- LLM-backed features (paper generation, marking, revision content, etc.)
  failing across the board on production.
- `docker logs hbec-litellm`: `litellm.exceptions.NotFoundError:
  GroqException - {"error":{"message":"The model \`llama-3.3-70b-versatile\`
  does not exist or you do not have access to it.","code":"model_not_found"}}`
  on every attempt to use the `fast/llama3.1-70b` model group (all 3 Groq
  keys, load-balanced, all hitting the identical error since it's the
  model name at fault, not any one key).

## Environment Details
- **Server/Host:** hbca-vps, `/opt/hbec` (production) and the git repo's
  `AGENTIC_HARNESS/litellm_config.yaml`
- **Services Affected:** `hbec-litellm` (LiteLLM proxy), and transitively
  every harness pillar that calls `fast/llama3.1-70b` as a fallback
- **Related Components:** `AGENTIC_HARNESS/app/shared/llm_client.py`
  (calls model group names, not raw provider models directly)
- **Time First Observed:** 2026-09-13, investigating a user-reported "AI
  not working on any API key" incident

## Investigation Steps

### 1. Initial Diagnosis
`docker logs hbec-litellm --since 3h | grep -iE 'error|...'` on production
showed three distinct, unrelated failure classes stacked together (Gemini
billing depletion, this Groq 404, and a dead ZCHPC GPU tunnel). Isolated
this one by checking whether the Groq *key* itself was the problem.

### 2. Root Cause Analysis
```bash
GKEY=$(docker exec hbec-litellm printenv GROQ_API_KEY)
curl -s https://api.groq.com/openai/v1/models -H "Authorization: Bearer $GKEY"
# -> 200 OK, but llama-3.3-70b-versatile is absent from the returned list entirely
```
Confirmed the key authenticates fine; the model name itself is simply no
longer valid. Tested a direct chat-completion call against a current
catalog model (`openai/gpt-oss-120b`) with the same key — succeeded.

### 3. Key Findings
- The exact same stale reference existed in **three** places:
  `AGENTIC_HARNESS/litellm_config.yaml` (production/staging), and
  `AGENTIC_HARNESS/litellm_config.local.yaml` (local dev) — a model rename
  upstream silently broke every environment at once, since nothing
  actively probes that the configured model still resolves.
- `openai/gpt-oss-120b` is a reasoning model — verified live that with a
  small `max_tokens` budget its hidden reasoning tokens can consume the
  entire budget and return empty `content` (`finish_reason: "length"`,
  `content: ""`), the exact same trap this same config file already
  documents having hit once before with Gemini's non-"-lite" alias.
  `reasoning_effort: "low"` keeps this bounded; call sites with very small
  `max_tokens` (~200-300) should be rechecked if this pool ever looks like
  it's silently returning empty completions again.

## Root Cause
Groq deprecated `llama-3.3-70b-versatile` from its hosted catalog at some
point after this config was written, and nothing in the stack verifies
that a configured `litellm_params.model` string still resolves against
the live provider — the failure is invisible until a real request hits it
and 404s.

## Prevention / Rule
**Guardrail:** A scheduled health-check (or a CI job hitting each
provider's `/models` endpoint with the real keys) that confirms every
model string named in `litellm_config.yaml` still appears in that
provider's current catalog, alerting on any that don't — this is exactly
the kind of drift a human only notices when a real request fails in
production.

This closes the gap directly: the root cause here was that a provider-side
catalog change is invisible to this stack until it manifests as a live
request failure, and a periodic catalog-membership check would flag it
before that happens.

## Solution

### Immediate Fix
Replaced `groq/llama-3.3-70b-versatile` with `groq/openai/gpt-oss-120b`
(Groq's current closest general-chat equivalent) across all three Groq
pool entries, in both `litellm_config.yaml` and `litellm_config.local.yaml`,
plus `reasoning_effort: low` on each to bound reasoning-token consumption.
Verified live end-to-end through the actual LiteLLM proxy on production
(not just directly against Groq) — `200 OK`, real `content` returned,
`"model":"groq/openai/gpt-oss-120b"` in the response.

Production's `/opt/hbec/AGENTIC_HARNESS/litellm_config.yaml` isn't
git-connected (see the companion drift entry), so this was applied by hand
there directly (backed up first) in addition to the git-tracked fix, and
`hbec-litellm` was restarted to pick it up.

### Long-term Fix
The catalog-membership health check described above; until that exists,
any future "AI not working" report should include a direct
`GET /v1/models` check per provider as a first diagnostic step, not an
assumption that a configured model name is still valid.

## Prevention
- [ ] Monitoring/alerts to add — the catalog-membership check above
- [ ] Documentation to update — none beyond the inline config comments
      already added explaining the reasoning-token trap
- [x] Code changes required — done, in both the repo and production directly

## Related Issues
- Same investigation surfaced two more distinct findings, logged
  separately: `HBEC-2026-09-13-gemini-pro-fallback-shares-primary-keys.md`
  and `HBEC-2026-09-13-production-litellm-config-drift-from-git.md`.

## References
- `AGENTIC_HARNESS/litellm_config.yaml`, `litellm_config.local.yaml`
- `/opt/hbec/AGENTIC_HARNESS/litellm_config.yaml` (production, hand-patched)

---

**Resolved By:** Claude (Sonnet 5)
**Time to Resolution:** Same session as discovery
