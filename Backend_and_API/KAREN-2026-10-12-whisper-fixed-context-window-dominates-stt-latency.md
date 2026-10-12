# Whisper STT took ~3s regardless of utterance length -- fixed-context encoder, not tuned

**Date:** 2026-10-12
**Project:** Karen (Friday voice assistant)
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary

Friday's perceived "slow to start transcribing" gap (3-5s between the user finishing speaking and a result) was traced to whisper.cpp's encoder always processing a fixed, zero-padded 30-second context window regardless of actual speech length, combined with `WhisperState` (its ~100MB+ of compute buffers) being recreated from scratch on every single utterance. Three real captures of very different lengths (1.6s, 9.7s, 20.3s) all took almost exactly the same ~2.95s to transcribe -- conclusive evidence the time was dominated by fixed per-call cost, not actual decode work. Fixed by caching `WhisperState` across calls and sizing `audio_ctx` to the real captured audio instead of the model's 30-second default. Live STT latency after the fix: 612ms (down from 2.6-4s).

## Symptoms

- User: "theres a gap between when i finish talking to when friday starts transcribing, it takes like 3-5 seconds."
- Logged `STT finished in N seconds` was consistently 2.6-4s across utterances from well under 1 second of actual speech up to over 20 seconds, with no correlation between audio length and processing time.

## Investigation Steps

### 1. Initial Diagnosis

Checked CPU core count (`nproc` = 4), confirmed ggml's CMake build already used `-O2 -march=native` (AVX2/FMA/F16C already enabled, ruling out a missing-SIMD explanation), and confirmed `FullParams` never set `n_threads`, `single_segment`, or `no_context` explicitly.

### 2. Root Cause Analysis

Added an explicit timing log around `state.full(...)` and compared across three live utterances:

```text
Audio captured: 1.63s  -> STT finished in 2.65s
Audio captured: 9.72s  -> STT finished in 2.98s (inference 2.956s)
Audio captured: 20.31s -> STT finished in 2.95s (inference 2.952s)
```

Near-identical timing across a 12x range of input length rules out "decode time scaling with audio length" as the dominant cost. Two compounding causes:

1. `stt::transcribe` called `ctx.create_state()` fresh on every single call. `WhisperState` owns its own large compute buffers (kv-cache, encode/decode scratch space -- the earlier startup log showed `compute buffer (encode) = 64-128MB` per state), so every utterance paid a full allocation cost regardless of the audio itself.
2. Whisper's encoder architecture pads input to a fixed context window (`audio_ctx`, default 1500 units = 30 seconds) and always runs the encoder over the full padded window -- a 1-second clip and a 25-second clip cost the same to encode unless `audio_ctx` is explicitly reduced to match the real input.

### 3. Key Findings

- `WhisperState` (`whisper-rs` 0.16.0) is `Send + Sync` and owns an internal `Arc`, independent of the `WhisperContext` it was created from -- safe to create once and reuse for the process lifetime.
- `set_audio_ctx` exists on `FullParams` but is marked `# EXPERIMENTAL` in `whisper-rs`; used here with generous headroom (+3s, 6s floor) rather than a tight fit, given Friday's prior sessions already had several reliability regressions from over-aggressive tuning.
- A parallel research pass through a reference voice-assistant repo (`Dix01/JARVIS`) confirmed its STT speed comes from a different engine entirely (CTranslate2/`faster-whisper`, int8 quantized), not a technique portable to `whisper-rs` -- except that a quantized ggml model file (e.g. `ggml-tiny.en-q5_1.bin`) is a plausible further speed lever, noted as a follow-up, not applied this session.

## Root Cause

Two independent, compounding costs that both scale with "cost per call" rather than "cost per second of audio": a fresh `WhisperState` allocation every utterance, and an encoder context window sized for the model's 30-second maximum instead of the actual (always short) captured audio.

## Prevention / Rule

**Guardrail:** any STT/LLM integration that allocates a fresh inference-state object per call must be reviewed for whether that object can be created once and reused -- enforce via code-review checklist item for `stt.rs`/`brain/mod.rs` ("is this object process-lifetime-cacheable, or does it have to be fresh per call, and why").

This generalizes beyond whisper: the same "accidentally paying a fixed setup cost every call instead of once" pattern can recur for any future model/client object added to the brain or STT path.

## Solution

### Immediate Fix

`karen-desktop/src-tauri/src/stt.rs`:

- Added a process-lifetime `static CACHED_STATE: OnceLock<Mutex<WhisperState>>`, created once via `cached_state(&ctx)` and reused for every `transcribe()` call instead of calling `ctx.create_state()` each time.
- Set `params.set_n_threads(available_parallelism)`, `set_single_segment(true)`, `set_no_context(true)` -- all previously left at whisper.cpp defaults.
- Sized `audio_ctx` dynamically from the actual captured sample count (`50 units/sec`, +150 units / 6s-minimum headroom, capped at the model's 1500 max) instead of leaving it at the 0 (model default, 30s) setting.
- Added an explicit `whisper inference (N threads) took ...` log line to make this class of regression directly observable in future sessions, instead of only an aggregate `STT finished in ...` figure.

```bash
cargo check --manifest-path karen-desktop/src-tauri/Cargo.toml   # pass
cargo test --manifest-path karen-desktop/src-tauri/Cargo.toml    # 61 passed
```

Live retest after rebuild: STT latency 612ms on a real utterance (down from 2.6-4s observed earlier in the same session).

### Long-term Fix

- Consider a quantized ggml model (`q5_1`/`q8_0`) as a further speed lever if more headroom is needed; noted but not applied this session, since the fixes above already closed most of the gap and changing model files changes transcription accuracy characteristics that deserve their own evaluation.
- Re-measure the `audio_ctx` headroom margin against real conversational use; the current +3s/6s-floor values were chosen for safety, not tuned for minimum latency.

## Prevention

- [x] Code changes required (done)
- [ ] Broader live retest across several real conversation turns, including longer sentences near the `audio_ctx` cap, to confirm no truncation regression from the experimental API

## Related Issues

- `KAREN-2026-10-12-vad-stuck-state-silently-discarded.md` and `KAREN-2026-10-12-headset-mic-jack-dead-no-signal.md` -- earlier in the same session; those fixed whether Friday heard anything at all, this fixes how long it took to process what it heard.

## References

- Files: `karen-desktop/src-tauri/src/stt.rs`
- Reference research: `github.com/Dix01/JARVIS` (read-only, confirms its STT speed comes from a different engine, not a portable whisper-rs technique)

---

**Resolved By:** Claude (Claude Code)
**Time to Resolution:** ~40 min
