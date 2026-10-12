# Pipeline failures (STT/LLM/model load) were HUD-only, never voiced

**Date:** 2026-10-12
**Project:** Karen (Friday voice assistant)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary

All three failure exits in `pipeline::run` (Whisper model load failure, transcription failure, and brain/LLM loop failure) only emitted a HUD `"error"` stage with the raw internal error string -- none of them called `tts::speak_chunk`. A real failure (e.g. a Groq 400, see companion entry) looked identical to Friday simply freezing: the mission log showed a raw API error string, but nothing was said out loud. User explicitly asked for Friday to "come alive" around failures -- report what broke, in character, the way a competent assistant would say "I can't do that because of an error in my own reasoning," rather than going silent.

## Symptoms

- A real backend failure (LLM 400, STT failure, model load failure) showed only a raw, technical error string in the HUD mission log (e.g. `LLM provider returned 400 Bad Request: {"error":{...}}`), with zero voice response.
- From the user's side, this was indistinguishable from the app hanging -- no auditory signal that something had gone wrong, let alone what.

## Investigation Steps

### 1. Initial Diagnosis

User reported a Groq 400 error appearing silently in the mission log while testing live, and separately asked for Friday to react in-character to errors instead of just logging them.

### 2. Root Cause Analysis

```bash
grep -n "emit_if_current(\"error\"" pipeline.rs
```

All three `Err(e) =>` branches in `pipeline::run` (whisper load, transcription, brain loop) followed the identical pattern: `log::error!(...)` then `emit_if_current("error", Some(&e))` then `return false` -- no call to `tts::speak_chunk` anywhere in any of the three. This matches a pattern already found earlier this session in the deterministic command router (`KAREN-2026-10-12-router-routes-never-reached-tts.md`): any code path that returns an answer/result without going through the LLM-streaming loop has to opt in to speaking explicitly, and these three simply never did.

### 3. Key Findings

- The raw error strings are informative for logs/debugging but inappropriate to read verbatim to the user (e.g. a raw JSON error body) -- they needed translation into something Friday would actually say, not just a TTS call on the raw string.
- Different failure classes (missing API key, model load failure, STT failure, LLM 4xx/5xx, timeout) all deserve distinct spoken lines so the user gets a real sense of *what* broke, consistent with Persona.md's "Truth and Evidence" principle (accurate about what failed, no invented specifics) and "Response Discipline" (calm, specific, not generic).

## Root Cause

Voicing was only ever wired into the success/streaming path of the pipeline; none of the three failure exits were ever connected to TTS, so every backend failure was silent by construction, not by accident of a particular bug.

## Prevention / Rule

**Guardrail:** every `return false` / `return Err(...)` exit in `pipeline.rs` that represents a failed turn must either call `voice_error` (or an equivalent) or have an explicit code comment justifying silence (the existing cancel-command path is the only legitimate silent exit, by design) -- enforce via code-review checklist item ("does this failure path ever reach the user's ears, or only the HUD/log").

This is the same class of gap as `KAREN-2026-10-12-router-routes-never-reached-tts.md` (answer paths that forgot to opt into TTS) applied to the failure side instead of the success side -- the guardrail should cover both directions going forward.

## Solution

### Immediate Fix

`karen-desktop/src-tauri/src/pipeline.rs`:

- Added `in_character_error(&str) -> String`, a classifier mapping raw error substrings (missing Groq key, Whisper model/inference failure, LLM 4xx/5xx by status code, latency-budget timeout, stream error) to short, persona-consistent spoken lines, with a generic fallback for anything unclassified.
- Added `voice_error(&str, speech_ended_at, gen_id)`, which calls `tts::speak_chunk` with the classified line.
- Wired `voice_error` into all three failure exits in `pipeline::run`, alongside (not instead of) the existing `emit_if_current("error", ...)` HUD emit, so the raw text is still available for debugging while the user also hears a true, in-character explanation.
- Added a test asserting each failure class produces a distinct spoken line (not a generic one-size-fits-all message).

```bash
cargo check --manifest-path karen-desktop/src-tauri/Cargo.toml   # pass
cargo test --manifest-path karen-desktop/src-tauri/Cargo.toml    # 61 passed
```

### Long-term Fix

- None planned; classification list can grow as new failure modes are observed in real use.

## Prevention

- [x] Code changes required (done)
- [ ] Guided live retest triggering at least one real failure (e.g. temporarily unset `GROQ_API_KEY`) to confirm the spoken line plays correctly end-to-end

## Related Issues

- `KAREN-2026-10-12-router-routes-never-reached-tts.md` -- same root pattern (a reply/result path that doesn't automatically reach TTS), found earlier this session on the success side.
- `KAREN-2026-10-12-groq-tool-call-type-field-duplicated.md` -- the specific failure that prompted this fix to be requested.

## References

- Files: `karen-desktop/src-tauri/src/pipeline.rs`, `Persona.md` (tone/accuracy source for the spoken lines)

---

**Resolved By:** Claude (Claude Code)
**Time to Resolution:** ~20 min
