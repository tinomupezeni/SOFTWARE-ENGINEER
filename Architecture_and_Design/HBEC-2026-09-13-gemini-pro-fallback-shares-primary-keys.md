# The Gemini Fallback Tier Uses the Same 3 API Keys as the Primary Tier — No Real Redundancy Against a Billing Outage

**Date:** 2026-09-13
**Project:** HBEC
**Environment:** Production
**Severity:** Medium
**Status:** Resolved

## Summary
`litellm_config.yaml`'s router fallback chain sends a failed
`google/gemini-flash` request to `google/gemini-pro` as its second-choice
fallback. Both model groups resolve to the identical underlying model
(`gemini/gemini-flash-lite-latest`) using the identical three API keys
(`GOOGLE_API_KEY`, `_2`, `_3`). When Google's prepaid credits on that
account are depleted — as they were during the incident this was found
in — every key fails identically under both model group names, so the
"fallback" provides zero real redundancy: it just retries the same
already-exhausted quota under a different label before moving on to Groq.

## Symptoms
- No distinct symptom of its own beyond the Gemini billing incident
  itself; found by reading the fallback chain while diagnosing that
  incident and noticing the fallback target shares its provider AND its
  exact API keys with the model it's meant to be a fallback *for*.

## Environment Details
- **Server/Host:** production + staging (both use the same
  `litellm_config.yaml` shape)
- **Services Affected:** `hbec-litellm`
- **Related Components:** `router_settings.fallbacks` in
  `AGENTIC_HARNESS/litellm_config.yaml`
- **Time First Observed:** 2026-09-13, during the Gemini billing /
  Groq-model-retired investigation

## Investigation Steps

### 1. Initial Diagnosis
Read the fallback chain while confirming Groq's key/model status:
```yaml
fallbacks:
  [
    {"google/gemini-flash": ["fast/llama3.1-70b", "google/gemini-pro", "gpu/qwen14b"]},
    ...
  ]
```

### 2. Root Cause Analysis
Compared the `litellm_params` of every `google/gemini-flash` and
`google/gemini-pro` entry: identical `model:` value
(`gemini/gemini-flash-lite-latest`) and identical `api_key:` triplet
(`GOOGLE_API_KEY`/`_2`/`_3`). Confirmed directly against Google's API
during the same incident that all three keys were already returning
`429 RESOURCE_EXHAUSTED — prepayment credits depleted` — meaning
`google/gemini-pro` could never have succeeded either, for any request
that reached it during that window.

### 3. Key Findings
- The fallback ordering (`fast/llama3.1-70b` (Groq) comes *before*
  `google/gemini-pro` in the chain) means Groq being broken too (the
  companion finding) meant every failed Gemini request cycled through a
  dead Groq pool, then a Gemini fallback that could never have worked
  given the same account-level billing exhaustion, before finally
  reaching the GPU tier.
- This isn't a bug in the sense of incorrect code — the config is
  internally consistent and does what it's written to do. It's a design
  gap: nothing about the current three-key, single-account setup
  provides isolation against the one failure mode (account-level billing
  exhaustion) that affects every key on that account simultaneously.

## Root Cause
The three Gemini keys were set up for *rate-limit* rotation (each key has
its own RPM/TPM budget) rather than for *billing-account* redundancy —
they're very likely all provisioned under the same Google Cloud/AI Studio
billing project, so a single account-level "prepayment depleted" event
takes out all three at once. Naming one of the model groups built from
those same keys a "fallback" implies redundancy that isn't actually there
for this specific failure mode.

## Prevention / Rule
**Guardrail:** A fallback entry in `router_settings.fallbacks` should only
ever point at a target that is genuinely independent of the failure modes
the primary can suffer — for a billing/quota outage, that means a
different billing account (or a different provider entirely). A
config-linting check (or just a documented review rule at PR time) that
flags any fallback chain step sharing an `api_key` value with the step it
follows would catch this exact shape directly.

This closes the gap because the actual defect isn't a wrong value
anywhere — it's a fallback relationship that looks redundant but isn't,
which only a rule checking for *shared keys between chain steps*, not
just "is there a fallback configured," would surface.

## Solution

### Immediate Fix
Chose option 3, and went further than pure relabeling: removed
`google/gemini-pro` entirely rather than keep it and just fix the comments.
Reordering (the original option 2) turned out to already be moot — the
live fallback chain already tries Groq before cycling back to Gemini
(`{"google/gemini-flash": ["fast/llama3.1-70b", "google/gemini-pro", ...]}`),
so there was no reorder left to do.

Before removing, confirmed via direct research against the pinned proxy
source (`litellm` v1.55.8, matching every deployed compose file) that this
wasn't sacrificing real capacity: LiteLLM's usage-based-routing tracks
RPM/TPM per **deployment id** (`Router._generate_model_id`, which hashes in
the `model_name` group label itself, not just the underlying `litellm_params`),
so `google/gemini-flash` and `google/gemini-pro` — despite sharing the
identical real API key values — each got their own independent RPM/TPM
counter inside LiteLLM's own bookkeeping. That means `google/gemini-pro`
was never providing genuine extra throughput on those 3 keys; it let
LiteLLM believe it had roughly double the real per-key headroom (e.g. 28
RPM tracked internally vs. Google's actual ~15 RPM per-key server-side
limit), which could have caused real 429s from Google at exactly the
moment it was used as a fallback under load. Removing it costs nothing
real and closes a latent risk of over-driving the real per-key quota.

Removed:
- The 3-entry `google/gemini-pro` model_list pool from both
  `AGENTIC_HARNESS/litellm_config.yaml` and `.local.yaml`.
- `google/gemini-pro` from both `router_settings.fallbacks` entries in
  both files.
- The harness's own parallel fallback mechanism had the identical flaw:
  `MODEL_ROUTES["fallback_cloud"] = "google/gemini-pro"` in
  `app/shared/llm_client.py`'s `_build_fallback_chain` — removed that key
  and its entry in the `for key in (...)` loop, and updated the routing
  table's own comments.
- Also hand-patched the same removal directly into `/opt/hbec` (production)
  and `/home/winstontino/HBEC` (staging)'s live `litellm_config.yaml`
  copies, since neither is auto-updated by a git-tracked deploy for this
  file (see `HBEC-2026-09-13-production-litellm-config-drift-from-git.md`).

Verified: `yaml.safe_load` + a manual model-list/fallback dump on both
edited files, `ruff check` clean, and the provider-health parser
(`_parse_model_list`) correctly reports only 2 Gemini model ids now
instead of 3. Also hand-patched and verified live on both `hbec-litellm`
(production) and `hbec-litellm-staging`: recreated both containers with
`--force-recreate` (not a bare `up -d` — same bind-mount staleness risk
found and documented in
`HBEC-2026-09-14-staging-prometheus-stale-bind-mount-ignored-reload.md`),
and confirmed via `docker logs` on each that LiteLLM's own startup
"Set models:" list no longer includes `google/gemini-pro` while every
other pool (Groq, Gemini Flash, Vision, GPU, CPU) is intact.

### Long-term Fix
None needed — the design flaw no longer exists in the config. If real
cross-account Gemini redundancy is ever wanted later, that's a fresh
decision (provisioning a genuinely separate Google Cloud/AI Studio
project), not a fix to this entry.

## Prevention
- [x] Configuration changes needed — done, in git, production, and staging
- [x] Monitoring/alerts to add — `ProviderAllKeysDead` (built earlier this
      session) still gives visibility into the "every key on a provider
      dead at once" failure mode generally
- [x] Documentation to update — inline comments explain the removal and
      link back to this entry
- [x] Code changes required — done, in both `litellm_config.yaml` and
      `app/shared/llm_client.py`

## Related Issues
- Found during the same investigation as
  `HBEC-2026-09-13-groq-model-llama-3.3-70b-versatile-retired.md` and
  `HBEC-2026-09-13-production-litellm-config-drift-from-git.md`.

## References
- `AGENTIC_HARNESS/litellm_config.yaml`, `.local.yaml` — `google/gemini-flash`
  model entries and `router_settings.fallbacks` (the `google/gemini-pro`
  pool referenced throughout this entry is now removed)
- `AGENTIC_HARNESS/app/shared/llm_client.py` — `MODEL_ROUTES`,
  `_build_fallback_chain`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session as discovery (fix applied on a
later session date, 2026-09-14, after the user chose option 1/3)
