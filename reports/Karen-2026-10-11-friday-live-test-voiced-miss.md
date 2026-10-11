# Friday live test: output chain verified, misses now voiced

**Date:** 2026-10-11
**Project:** Karen (Friday voice assistant)
**Type:** Test Session / Small Feature
**Status:** Completed

## Summary

Ran Friday live (`npm run tauri dev`) with the new STT logging and two follow-up changes: missed utterances are now spoken aloud ("Sorry, I didn't catch that", cooldown-gated) per user request, and the WAV duration parser was fixed. Every measurable link in the output chain passes, yet the user still reports no audible sound — the evidence now points at the room/speakers, with two direct listening questions put to the user.

## Context / Trigger

User asked to run Friday and test, then reported (a) still no audible speech and (b) Friday should *say* when she didn't catch something instead of only logging it. HUD showed a `TRANSCRIBING → Didn't catch that → SPEAKING` cycle.

## Scope

Included: live run + full-chain output verification, voiced-miss feature, WAV parser fix, restart with new build. Excluded: VAD retuning for the noisy room (still triggers on background peaks every ~15–30s; deferred until the audibility question is settled).

## Method

Isolated output from input: verified synthesis bytes contain real speech-level audio, traced the player stream live in PipeWire (correct sink, unmuted, 100%), loop-played a reference file for a human audibility check, then observed Friday's own greeting + voiced-miss playbacks in her log.

## Decisions & Findings

- **Output chain is fully healthy:** Groq WAV has real audio (peak 41% FS, RMS ~1646); `pw-play` sink-input appears on the correct analog sink, unmuted at 100%, sink RUNNING; exit code 0. Friday's own greeting (Piper, 2.97s) and voiced miss (Groq, 2.56s) both synthesized and "played" per every observable signal.
- **Voiced-miss works:** `[BLANK_AUDIO]` discard → spoke the reply via Groq TTS → playback exit 0. Cooldown verified in log (suppressed at 15.5s, re-voiced at 33s). Gating: only captures ≥1.0s are voiced; sub-second blips stay silent.
- **WAV parser bug found and fixed** (separate issue entry): Groq's LIST-chunk headers misreported as `0.00s`; now chunk-walks and reports true durations.
- **Remaining unknown is human audibility:** asked the user (1) did the 3x-looped reference play come through the speakers, and (2) was the 07:25 greeting / 07:25:49 "Sorry I didn't catch that" heard. If both are unheard while Chrome audio on the same sink is heard, next step is speaker/hardware inspection, not code.

## Changes Made

- `pipeline.rs`: `maybe_voice_missed_reply` (≥1.0s gate, 30s cooldown, `missed-{millis}` utterance via `speak_chunk`); discard branch calls it before emitting idle.
- `tts/mod.rs`: chunk-walking `wav_summary` with `0xFFFFFFFF` placeholder handling.
- Restarted Friday on the new build (old `tauri dev` + backend processes killed; single-instance lock recovered cleanly).

## Verification

- `cargo check`: pass, no new warnings. `cargo test`: 46/46 pass.
- Live log: greeting `Piper synthesis 1.7s → Playback 2.97s → exit 0`; miss-reply `Groq synthesis 1.0s → Playback 2.56s → exit 0`; cooldown suppression logged as designed.
- All 4 Groq keys return HTTP 200 on direct API test.

## Follow-ups / Deferred

- Await user's audibility answers; if speakers are confirmed working and Friday is still silent, investigate ALSA/hardware layer (everything above it is verified).
- VAD still fires on room-noise peaks (floor ~0.065 RMS, mic at 35%); revisit threshold/gain once audibility is settled.
- Optional HUD notice for repeated all-keys-exhausted (from rotation report).

## References

- Issue: `Backend_and_API/Karen-2026-10-11-tts-wav-duration-misparse.md`
- Prior: `Backend_and_API/Karen-2026-10-11-stt-silent-discard-no-logging.md`, `reports/Karen-2026-10-11-groq-key-rotation-failover.md`
- Live log: `/tmp/friday-dev.log`; persisted: `~/.local/share/com.tauri.dev/logs/friday.log`

---

**Completed By:** Muse Spark (OpenCode)
**Duration:** ~40 min
