# Karen: Groq API key rotation with failover

**Date:** 2026-10-11
**Project:** Karen (Friday voice assistant)
**Type:** Architecture Decision / Small Feature
**Status:** Completed

## Summary

Both Groq call sites (LLM chat and cloud TTS) used a single `GROQ_API_KEY` with no fallback, so one expired key or one exhausted per-key quota (already observed: TTS 429, TPD 3600) killed the turn. A shared `groq_keys` rotation module now spreads calls round-robin across all configured keys and fails over to the next key on 401/403/429. Four Groq keys are configured; TTS falls back to local Piper only after every key is rejected.

## Context / Trigger

User request: add three additional Groq keys (plus one Gemini key, handled below) so an expired key routes to another. Triggered in part by the 2026-10-10 `karen.log` evidence of Groq TTS hitting `rate_limit_exceeded` (TPD 3600, used 3558) mid-conversation.

## Scope

Included: shared rotation helper, LLM request loop, Groq TTS provider, `.env` key storage, `.env.example` docs. Explicitly excluded: a Gemini provider — the fourth supplied key (`AQ.Ab8…`) is a Google AI Studio key, unusable as a Groq bearer, and the app has no Gemini integration; it is stored as `GEMINI_API_KEY` for future wiring.

## Method

Mapped every `GROQ_API_KEY` read (exactly two: `brain/mod.rs`, `tts/groq.rs`), centralized key collection/ordering/retry-policy in one module so both call sites share identical failover semantics, and kept single-key behaviour byte-for-byte equivalent to before.

## Decisions & Findings

- **Rotation + failover, not just failover:** each call starts at the next round-robin slot (`AtomicUsize`), spreading per-key quota usage; on 401/403/429 it walks the remaining keys in order. Key values are never logged — only counts and 1-based positions.
- **Rotate on 401/403 as well as 429:** per the user's "expired key routes to another" requirement; a bad-request/server error (400/404/5xx) is about the request or service, so those return immediately without burning the other keys.
- **Env shapes:** `GROQ_API_KEYS` (comma/newline list) + `GROQ_API_KEY` + `GROQ_API_KEY_2..9`, deduped, priority in that order. Numbered vars chosen as the primary documented shape (simplest to extend).
- **TTS all-keys-exhausted is `Retryable`, not `Fatal`:** previously a dead key meant `Fatal` → manager skips Piper → silent turn. Now total Groq rejection falls back to local Piper so the user still hears something. Single-key 400/401/403/404 keeps the old `Fatal` semantics.
- **LLM loop rebuilds the request per key attempt** (`body.clone()`), since a sent reqwest builder is consumed; all attempts share the turn's original latency deadline.

## Changes Made

- New: `karen-desktop/src-tauri/src/groq_keys.rs` (collection, round-robin ordering, `should_try_next_key`, unit tests).
- `lib.rs`: registered `mod groq_keys;`.
- `brain/mod.rs`: per-iteration send loop over rotated keys with warn-and-continue on 401/403/429.
- `tts/groq.rs`: same rotation inside `generate_audio`; all-exhausted → `Retryable` for Piper fallback.
- `.env` (gitignored): existing key kept as primary, three new `gsk_` keys as `_2.._4`, plus `GEMINI_API_KEY` (stored, unwired).
- `karen-desktop/.env.example`: documented the rotation vars (no secrets).

## Verification

- `cargo check`: passes, no new warnings (remaining warnings pre-existing in untouched code).
- `cargo test`: 46/46 pass (44 existing + 2 new `groq_keys` rotation-policy tests).
- `git check-ignore .env` confirmed — no secrets enter version control.
- Live rotation against Groq API not yet exercised (no running app session); first real 429/401 will show `rotating to next key` warns in the log.

## Follow-ups / Deferred

- Optional: wire `GEMINI_API_KEY` as a third LLM provider/fallback (new provider integration, larger scope — needs user go-ahead).
- Optional: surface "all Groq keys exhausted" as a HUD notice so repeated quota exhaustion is visible, not just logged.

## References

- Bug log: `Backend_and_API/Karen-2026-10-11-stt-silent-discard-no-logging.md`
- Key files: `groq_keys.rs`, `brain/mod.rs` (LLM loop), `tts/groq.rs`, `tts/manager.rs` (fallback policy)

---

**Completed By:** Muse Spark (OpenCode)
**Duration:** ~25 min
