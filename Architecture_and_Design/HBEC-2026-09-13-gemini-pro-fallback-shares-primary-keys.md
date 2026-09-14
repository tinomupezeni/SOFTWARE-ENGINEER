# The Gemini Fallback Tier Uses the Same 3 API Keys as the Primary Tier — No Real Redundancy Against a Billing Outage

**Date:** 2026-09-13
**Project:** HBEC
**Environment:** Production
**Severity:** Medium
**Status:** Investigating

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
None applied yet — flagged for the user's decision. Two independent knobs it doesn't currently have. Left as Investigating for that reason.

### Long-term Fix
Options to discuss with the user before choosing:
1. Provision the three Gemini keys under separate billing accounts/projects
   so a single account's depletion doesn't take out the whole pool.
2. Reorder the fallback chain so a truly independent provider (Groq, now
   fixed — see the companion entry) is tried before cycling back to a
   same-account Gemini fallback, rather than after.
3. Accept the current shape as "rate-limit redundancy only" and stop
   calling `google/gemini-pro` a fallback in the config's own comments,
   so a future reader doesn't assume protection that isn't there.

## Prevention
- [ ] Configuration changes needed — one of the three options above, per
      the user's choice
- [x] Monitoring/alerts to add — built as a generalized, per-provider
      version rather than a Gemini-specific one:
      `app/shared/observability/provider_health.py` re-authenticates every
      configured key on every provider every 5 minutes, and the new
      `ProviderAllKeysDead` alert
      (`harness_provider_key_live` all reading 0 for one `provider` label)
      fires exactly when every key on an account fails at once —
      distinguishing this from an ordinary single-key rate limit, which
      LiteLLM's own cooldown already absorbs transparently and shouldn't
      page anyone. This gives visibility into the failure mode; it does
      **not** by itself fix the underlying design gap (the three keys
      still share one billing account) — that's still the open decision
      above.
- [ ] Documentation to update — the config's own comments, once a
      decision is made
- [ ] Code changes required — none yet, pending the decision above

## Related Issues
- Found during the same investigation as
  `HBEC-2026-09-13-groq-model-llama-3.3-70b-versatile-retired.md` and
  `HBEC-2026-09-13-production-litellm-config-drift-from-git.md`.

## References
- `AGENTIC_HARNESS/litellm_config.yaml` — `google/gemini-flash`,
  `google/gemini-pro` model entries and `router_settings.fallbacks`

---

**Resolved By:** Not yet — identified only, awaiting a decision on which
long-term fix to apply
**Time to Resolution:** N/A
