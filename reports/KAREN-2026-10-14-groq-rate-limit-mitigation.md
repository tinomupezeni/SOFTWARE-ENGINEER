# Groq Rate-Limit Mitigation

**Date:** 2026-10-14
**Project:** Karen
**Type:** Reliability / Capacity Decision
**Status:** Completed

## Summary
Investigated recurring Groq 429 responses and implemented a free-first quota policy. The key finding was that rotating multiple Groq keys does not reliably increase capacity when the exhausted quota is organization-scoped. Karen now records a provider-wide cooldown from Groq response headers and uses local Ollama for ordinary interactive LLM turns during that window, while local Piper remains the default TTS path.

## Context / Trigger
The user reported recurring Groq rate limits and wanted a solution that avoided paid capacity. Existing code rotated keys and tracked token headers but could immediately retry every key after a 429.

## Scope
Included Groq LLM admission behavior, key rotation interaction, optional Groq TTS handling, local fallback behavior, focused tests, and architecture/engineering records. Comparative model-quality benchmarking, distributed quota coordination, and response caching were excluded because this is a single-process desktop application and the immediate failure mode was repeated 429 amplification.

## Method
Inspected Karen's Groq request paths and response-header handling, then compared them with open-source patterns from LiteLLM, Portkey Gateway, `llm-keypool`, and FreeLLM. Validated the implementation with focused and full Rust tests plus the frontend production build.

## Decisions & Findings
- Treat a Groq 429 as provider-wide by default, not merely key-local.
- Prefer `retry-after`, then request-reset or token-reset headers, with a bounded 60-second fallback.
- Do not rewrite explicitly forced provider calls.
- Use Ollama automatically for ordinary interactive turns while Groq is cooling down.
- Keep TTS local-first; rate-limited Groq TTS falls back immediately to Piper.
- Keep the quota state in-process because Karen is currently a single desktop process.

## Changes Made
- Added process-wide cooldown state and reset-duration selection in `karen-desktop/src-tauri/src/groq_keys.rs`.
- Recorded cooldowns for both LLM and Groq TTS responses.
- Added automatic non-forced interactive fallback to Ollama in `brain/mod.rs`.
- Documented the policy in `ARCHITECTURE.md`.
- Added focused cooldown and `Retry-After` format tests.

## Verification
- `cargo test groq_keys -- --nocapture`: 9 passed.
- `cargo test`: 77 passed.
- `cd karen-desktop && npm run build`: passed.
- Existing compiler warnings remain unrelated to this change.

## Follow-ups / Deferred
- Add a small local response cache only for deterministic, side-effect-free requests.
- Add token-cost admission control before sending large prompts.
- Add live telemetry for cooldown duration, fallback count, and 429 rate.
- Revisit cross-process coordination only if Karen becomes a shared service.

## References
- `Backend_and_API/KAREN-2026-10-14-groq-organization-rate-limit.md`
- `ARCHITECTURE.md`
- `karen-desktop/src-tauri/src/groq_keys.rs`
- `karen-desktop/src-tauri/src/brain/mod.rs`
- `karen-desktop/src-tauri/src/tts/groq.rs`

---

**Completed By:** Copilot
**Duration:** Same session
