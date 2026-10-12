# Gemini API keys rotated with a genuine two-tier fallback (new keys primary, old keys as a distinct-quota second tier)

**Date:** 2026-10-12
**Project:** HBEC Platform
**Type:** Infrastructure change / key rotation
**Status:** Completed

## Summary
Three new Gemini API keys were promoted to primary for the harness's LLM
routing (`google/gemini-flash` / `vision/gemini-flash` pools in
`litellm_config.yaml`), replacing the keys live until now. Rather than
discard the old keys, they were kept as a genuinely separate fallback tier
(`google/gemini-flash-legacy` / `vision/gemini-flash-legacy`) inserted into
the router's fallback chain ahead of Groq/the self-hosted GPU — so if the
new keys are exhausted or rate-limited, routing falls back to the old keys'
distinct quota before degrading off Gemini entirely. Applied to production
(`hbca-vps`, `/opt/hbec`) and verified live.

## Context / Trigger
User request: promote 3 newly-acquired Gemini keys (`GEMINI_KEY_1/2/3`,
staged in the repo root `.env` under a `##HBEC KEYS TO REPLACE CURRENT AI
KEYS` marker) to be the default Gemini keys, with automatic fallback to the
keys currently in use once the new ones are exhausted — without disturbing
Groq's existing role as the fallback-of-last-resort after Gemini as a whole.

## Scope
Included: `AGENTIC_HARNESS/litellm_config.yaml` (production config) and
`docker-compose.production.yml`'s three `GOOGLE_API_KEY*` injection points
(`x-harness-env` anchor, `litellm` service, `harness` service's own direct
copy for `provider_health`), plus the live VPS `.env` key rotation and a
restart of the services that needed to pick up the new config/env.

Explicitly excluded: `AGENTIC_HARNESS/litellm_config.local.yaml` and the dev
`docker-compose.yml` — the request was about the keys actually serving
production traffic; dev/local key rotation was not part of the ask and
wasn't touched.

## Method
Read `HBEC-2026-09-13-gemini-pro-fallback-shares-primary-keys.md` first
(already logged in this repo) before designing anything — it documents a
prior, near-identical-looking attempt at a second Gemini tier that was
removed because it resolved to the *same* keys as primary under a different
`model_name`, adding zero real protection during an account-wide Gemini
outage. The design here is only safe because the two tiers use genuinely
distinct API keys with independent quota — confirmed this distinction
explicitly before touching anything, rather than assuming the shape alone
was fine.

## Decisions & Findings
- **Tier naming kept the existing `GOOGLE_API_KEY`/`_2`/`_3` env var names
  pointing at the new keys** (rather than inventing new var names for the
  "primary" role) so no application code needed to change — only `.env`'s
  values and `litellm_config.yaml`'s new pool. The keys being replaced moved
  to new `GOOGLE_API_KEY_LEGACY`/`_2`/`_3` vars.
- **Fallback order**: `google/gemini-flash` → `google/gemini-flash-legacy` →
  `fast/llama3.1-70b` (Groq) → `gpu/qwen14b`, and the reverse entry
  (`fast/llama3.1-70b` → `google/gemini-flash` → `...-legacy` → GPU) updated
  to match, so a Groq-first failure still tries both Gemini tiers before the
  GPU. Vision pool mirrored the same shape ahead of
  `vision/claude-sonnet`. This preserves "exhaust all Gemini capacity before
  leaving the Gemini model family," which is the existing design intent the
  2026-09-13 incident doc's own comment block states.
- **The VPS `.env` edit was done via an uploaded, idempotency-checked script**
  (refuses to run if `GOOGLE_API_KEY_LEGACY` already exists) that read the
  old values directly from the live file and the new values from a
  locally-staged, root-only temp file — no key value was ever printed to a
  terminal or committed; only variable *names* were ever echoed for
  verification.
- Confirmed blue-green is already further along on this host than
  `CLAUDE.md`/the standing plan doc describes (`active_color=blue`,
  `harness-blue`/`harness-green` both running) — the legacy bare `harness`
  container (profile `legacy`) is a pre-cutover leftover whose image tag
  isn't pullable from GHCR by design and was correctly left untouched.

## Changes Made
- `AGENTIC_HARNESS/litellm_config.yaml`: added `google/gemini-flash-legacy`
  and `vision/gemini-flash-legacy` 3-key pools; updated `router_settings.
  fallbacks` to route through them.
- `docker-compose.production.yml`: added `GOOGLE_API_KEY_LEGACY`/`_2`/`_3`
  to the `x-harness-env` anchor, the `litellm` service, and the `harness`
  service's direct copy.
- `/opt/hbec/.env` (production, not in git): `GOOGLE_API_KEY`/`_2`/`_3` now
  hold the 3 new HBEC keys; `GOOGLE_API_KEY_LEGACY`/`_2`/`_3` hold the
  previous values. Backed up before editing
  (`.env.bak.20261012_061552`).
- Deployed updated `litellm_config.yaml` and `docker-compose.production.yml`
  to `/opt/hbec` (backups taken first); recreated `hbec-litellm`,
  `hbec-harness-blue`, `hbec-harness-green` to pick up the new config/env.
- Local repo root `.env`: removed the now-applied `GEMINI_KEY_1/2/3` staging
  block (file is gitignored, never committed).

## Verification
- `docker compose ... config` validated cleanly against the live `.env`
  once the blue-green color-env vars were sourced correctly (an unrelated
  `TAG_BLUE`/`TAG_GREEN` interpolation failure was confirmed pre-existing
  on the untouched backup file too, before assuming the new config caused
  it).
- All three recreated containers reported `healthy` post-restart.
- `GET /v1/models` on the live `litellm` container confirmed both
  `google/gemini-flash-legacy` and `vision/gemini-flash-legacy` are loaded.
- Real completions sent through both `google/gemini-flash` (new keys) and
  `google/gemini-flash-legacy` (old keys) against the live production
  `litellm` container both returned `200` with real model output — not just
  "configured," actually working end to end.
- Confirmed no key value was ever present in command output throughout
  (only variable names grepped post-change).

## Follow-ups / Deferred
- Dev/local `litellm_config.local.yaml` and `docker-compose.yml` were not
  given the legacy tier — low priority, since dev doesn't carry the same
  key-exhaustion risk profile; revisit if dev ever needs the same
  resilience.
- No change made to `provider_health.py`'s probe logic to also report on
  the legacy tier specifically — the fallback works via litellm's own
  routing regardless, and health-dashboard visibility into the legacy tier
  is a nice-to-have, not needed for the fallback to function.

## References
- `HBEC-2026-09-13-gemini-pro-fallback-shares-primary-keys.md` — the prior,
  surface-similar attempt that failed for a specific, checked-against
  reason (same keys, not a real second tier).
- `AGENTIC_HARNESS/litellm_config.yaml` (`router_settings.fallbacks`,
  `google/gemini-flash-legacy`, `vision/gemini-flash-legacy`)
- `docker-compose.production.yml` (`x-harness-env`, `litellm`, `harness`
  service blocks)

---

**Completed By:** Tinotenda Mupezeni
**Duration:** ~45 minutes
