# Friday's deterministic command router produced text with no audio

**Date:** 2026-10-12
**Project:** Karen (Friday voice assistant)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary

A new, not-yet-committed `brain/router.rs` module let `run_agentic` answer
simple commands (open app, set volume, system status, stop playback)
without an LLM round-trip, returning a plain `String`. Every one of those
early-return paths skipped `tts::speak_chunk` entirely — the HUD showed the
reply text, but nothing was ever spoken. Found while adding a similar
fast-path for plain conversational turns ("hi"); fixed at the shared root
cause rather than letting the new code repeat it.

## Symptoms

- A routed command (e.g. "open VS Code", "set volume to 40%", "system
  status") would show its result text in the HUD's answer stage, but Friday
  stayed silent — indistinguishable from TTS itself failing.
- Only commands that fell through to the full LLM streaming path produced
  audio, since that path is the only one that calls `speak_chunk`.

## Environment Details

- **Server/Host:** garden (Linux)
- **Services Affected:** `karen-desktop` Tauri app — `brain/mod.rs`,
  `brain/router.rs`
- **Related Components:** `tts/mod.rs` (`speak_chunk`), `pipeline.rs`
  (consumes `run_agentic`'s return value but never speaks it either — by
  design, since speaking was assumed to already have happened during
  streaming)
- **Time First Observed:** 2026-10-12, during this session's work

## Investigation Steps

### 1. Initial Diagnosis

While adding a conversational fast-path (greetings/identity/status
checks) to avoid an LLM round-trip for simple turns, searched the codebase
for every call site of `tts::speak_chunk` to make sure the new fast-path
reply would actually reach TTS the same way the streamed LLM path does.

### 2. Root Cause Analysis

```bash
grep -rn "speak_chunk" karen-desktop/src-tauri/src
```

Found only three call sites, all inside the LLM streaming loop in
`brain/mod.rs` (per-sentence chunk, trailing remainder, tool
acknowledgement). `router::route`'s four match arms in `run_agentic`
(`StopPlayback`, `SystemInfo`, `SetVolume`, `OpenApp`) each `return
Ok(string)` directly, and `pipeline.rs`'s caller only emits the `"answer"`
HUD stage from that string — it never calls `speak_chunk` on the final
return value, because that was never necessary before: previously the
only path that produced a `run_agentic` answer was the streaming path,
which always speaks as it goes.

### 3. Key Findings

- `router::route`'s early returns are plain strings with no side effect
  beyond the HUD emit in `pipeline.rs`.
- The streaming path's incremental `speak_chunk` calls are the *only*
  mechanism that reaches TTS; any new early-return path silently inherits
  "text-only" behavior unless it explicitly calls `speak_chunk` itself.
- `StopPlayback` is a deliberate exception: `pipeline.rs`'s own
  cancel-command handling (`is_cancel_command`) already treats "stop" as
  silent by design, so it wasn't changed.

## Root Cause

`run_agentic` has two classes of return path — streamed (speaks as it
generates) and short-circuited/deterministic (built to return instantly) —
but only the streamed path was ever wired to `tts::speak_chunk`. The
router module added a second short-circuit class without carrying that
wiring over.

## Prevention / Rule

**Guardrail:** every non-streamed `return Ok(reply)` in `run_agentic` must
route through a single `speak_now` helper that calls `speak_chunk`, rather
than returning a bare string — enforce via code-review checklist item
("does this early return in `run_agentic` reach TTS, or only the HUD?").

This makes "produces an answer" and "is spoken" the same code path by
construction, so a future fast-path addition can't silently reintroduce a
text-only reply.

## Solution

### Immediate Fix

`karen-desktop/src-tauri/src/brain/mod.rs`:

- Added `speak_now(text, speech_ended_at, gen_id) -> String`, which calls
  `tts::speak_chunk` with a fresh utterance id/seq 0 and returns the text
  unchanged so call sites can stay one-line.
- Wrapped `router::Route::SystemInfo`, `SetVolume`, and `OpenApp`'s replies
  in `speak_now`. `StopPlayback` intentionally left silent (matches
  `pipeline.rs`'s own cancel-command behavior).
- Wrapped the background-task "I've queued that as task …"
  acknowledgement in `speak_now` as well, since it had the same gap.

```bash
cargo check --manifest-path karen-desktop/src-tauri/Cargo.toml   # pass
cargo test --manifest-path karen-desktop/src-tauri/Cargo.toml    # 60 passed
```

### Long-term Fix

- None planned beyond the guardrail above; the helper closes the gap for
  all current and future short-circuit routes in one place.

## Prevention

- [x] Code changes required (done — `speak_now` helper, wired into all
      non-streamed reply routes)
- [ ] Guided live retest to confirm routed commands (open app / volume /
      system status) are now audible, not just shown in the HUD

## Related Issues

- `Karen-2026-10-12-vad-buffer-accumulates-idle-silence.md` — same
  session, different stage of the pipeline (capture vs. reply delivery);
  both were silent failures that looked identical to "Friday is broken"
  from the user's side.
- `reports/Karen-2026-10-12-conversational-fast-path.md` — the initiative
  that surfaced this bug while adding a new fast-path reply type.

## References

- Files: `karen-desktop/src-tauri/src/brain/mod.rs`,
  `karen-desktop/src-tauri/src/brain/router.rs`,
  `karen-desktop/src-tauri/src/tts/mod.rs`

---

**Resolved By:** Claude (Claude Code)
**Time to Resolution:** ~15 min
