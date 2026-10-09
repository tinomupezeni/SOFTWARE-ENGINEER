# Intermittent No-Response and UI Wiping

**Date:** 2026-10-09
**Project:** Karen
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
Karen would successfully capture input, transcribe it, and receive an LLM response, but frequently failed to deliver that response to the user. The text UI would flash and vanish, and no audio would play. Furthermore, when the user interrupted, stale text generation and audio queueing would continue in the background and overlap with the new response.

## Symptoms
- User speaks, STT succeeds, but no response is heard or seen.
- UI text flashes briefly at the very end of generation and immediately disappears.
- Interrupting the assistant does not stop the background generation, leading to stale responses bleeding into the next turn.
- The logs show TTS failures (`429 Too Many Requests` from Groq and local Piper model missing).

## Environment Details
- **Server/Host:** Local desktop environment
- **Services Affected:** `pipeline::run`, `brain::run_agentic`, `tts` subsystem
- **Related Components:** Tauri, Rust Backend, React Frontend
- **Time First Observed:** 2026-10-09

## Investigation Steps

### 1. Initial Diagnosis
Checked if the STT or LLM was failing. Both were succeeding. Checked the TTS logs and found that Groq was returning 429 errors and Piper was failing because `en_US-lessac-medium.onnx` was not installed.

### 2. Root Cause Analysis
Investigated why the *text* was disappearing when TTS failed. Found that `pipeline::run` unconditionally emitted an `idle` event as soon as the LLM finished streaming. Because TTS was asynchronous and failed silently/slowly, the `idle` event wiped the UI state containing the answer before the user could read it.
Investigated why cancellation failed. Found that the `tts::cancel()` only killed the `aplay` process, but the overarching pipeline and LLM SSE stream were unaware of the cancellation and continued their work.

### 3. Key Findings
- The UI text delivery was improperly coupled to the lifecycle of the LLM stream rather than the user's reading/interaction state.
- Cancellation state was not shared between the audio subsystem and the text generation subsystem.
- The chunking logic for TTS was brittle, sending punctuation-only strings that caused `400 Bad Request` from the TTS API, and failing to handle multiple sentences in a single chunk.

## Root Cause
1. **State Overwrite:** Unconditional emission of `idle` event upon LLM stream completion wiped the React UI state.
2. **Missing Global Cancellation:** No shared context or generation ID linked the TTS cancellation to the LLM streaming loop, allowing stale generations to persist.
3. **TTS API Limits:** Groq API limits hit, and Piper local model was not installed as a fallback.

## Prevention / Rule
**Guardrail:** Global `AtomicUsize` generation counter checked on every async iteration loop (`run_agentic` SSE loop).

Any long-running asynchronous stream or pipeline that updates user-facing state must validate its originating `gen_id` against a global atomic counter before yielding or emitting events, ensuring that cancelled or stale tasks immediately abort rather than corrupting current state.

## Solution

### Immediate Fix
- Removed the unconditional `idle` event emission from `pipeline::run` and `lib.rs` bootup.
- Filtered TTS chunks with `.is_alphanumeric()` to prevent `400 Bad Request`.
- Updated the sentence extraction to use a `while let` loop to handle multiple sentences per chunk.

### Long-term Fix
- Elevated `current_generation` to an `AtomicUsize` accessible via `tts::get_current_generation()`.
- Passed the `gen_id` to `pipeline::run` and `run_agentic`.
- Added a check in the LLM streaming loop to abort if `get_current_generation() != gen_id`.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- Related to TTS Refactor and Concurrency Pipeline (Stage 2/3).

## References
- Groq API documentation on rate limits.
- Piper local TTS model requirements.

---

**Resolved By:** Antigravity
**Time to Resolution:** 1 hour
