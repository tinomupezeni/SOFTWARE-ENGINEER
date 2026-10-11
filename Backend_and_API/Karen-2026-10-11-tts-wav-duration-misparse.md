# Friday TTS wav_summary misreported Groq WAV duration as 0.00s

**Date:** 2026-10-11
**Project:** Karen (Friday voice assistant)
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary

The playback diagnostic `wav_summary` in `tts/mod.rs` assumed the WAV `data` chunk always starts at byte 40. Groq's Orpheus WAVs insert a `LIST/INFO` chunk between `fmt ` and `data` and use `0xFFFFFFFF` streaming placeholder sizes, so the startup-greeting log reported a 207 KB WAV as `0.00s` — making real successful playbacks look corrupt and undermining the "plausible duration" playback check.

## Symptoms

- Log line: `Playback starting: player="/usr/bin/pw-play", wav=207430 bytes; 1ch 24000Hz 16-bit; 0.00s` while `pw-play` then played 5.2s and exited 0.
- Any operator reading the log would conclude the WAV was empty/corrupt when it was fine.

## Environment Details

- **Server/Host:** garden (Linux, PipeWire 1.6.2)
- **Services Affected:** `karen-desktop` TTS playback diagnostics (`tts/mod.rs`)
- **Related Components:** Groq Orpheus TTS (`canopylabs/orpheus-v1-english`, 24 kHz mono)
- **Time First Observed:** 2026-10-11 (live `tauri dev` log)

## Investigation Steps

### 1. Initial Diagnosis

Synthesized a reference WAV directly from the Groq API with curl (all 4 rotated keys returned HTTP 200) and inspected its header.

### 2. Root Cause Analysis

```bash
xxd -l 80 /tmp/groq-test-1.wav
# RIFF....WAVE fmt (16) ... LIST(26) INFO ISFT Lavf61.7.100 ... data FFFFFFFF
```

Chunk walk: `fmt `(16) at 12, `LIST`(26) at 36, `data` at 70 with size `0xFFFFFFFF`. The fixed-offset parser read bytes 40–43 (inside `LIST`/`INFO`) as the data length.

```bash
# Audio content verified real (not silence): peak 13416/32767, RMS ~1646
```

### 3. Key Findings

- Groq WAV layout: extra `LIST/INFO` chunk + placeholder sizes; `fmt ` itself is standard (channels/rate/bits parsed correctly by luck).
- WAV audio content is genuine speech-level signal — output silence reports are not corrupt synthesis.
- Piper WAVs use standard 44-byte headers and were unaffected.

## Root Cause

Fixed-offset WAV parsing (data length assumed at bytes 40–43) breaks on any WAV with extra chunks or streaming placeholder sizes.

## Prevention / Rule

**Guardrail:** code-review checklist item for audio code — never parse RIFF with fixed offsets; always walk chunks to `data` and derive duration from the actual file size when chunk sizes are placeholder (`0xFFFFFFFF`).

## Solution

### Immediate Fix

Rewrote `wav_summary` in `karen-desktop/src-tauri/src/tts/mod.rs` to walk chunks, skip unknown chunks with word-alignment padding, and compute duration from `file_len - data_start` when size is `0xFFFFFFFF`. Verified live: greeting now logs `131232 bytes; 1ch 22050Hz 16-bit; 2.97s` (Piper) and the miss-reply `122950 bytes; 1ch 24000Hz 16-bit; 2.56s` (Groq).

```bash
cargo check --manifest-path karen-desktop/src-tauri/Cargo.toml  # pass, no new warnings
cargo test --manifest-path karen-desktop/src-tauri/Cargo.toml   # 46 passed
```

### Long-term Fix

None needed beyond the rewrite; parser now handles both Piper-style and Groq-style headers.

## Prevention

- [x] Code changes required (done)
- [ ] Documentation to update (none — internal diagnostic only)

## Related Issues

- `Backend_and_API/Karen-2026-10-11-stt-silent-discard-no-logging.md` (same diagnostic session)
- Report: `reports/Karen-2026-10-11-friday-live-test-voiced-miss.md`

## References

- `karen-desktop/src-tauri/src/tts/mod.rs` (`wav_summary`)
- Reference file: `/tmp/groq-test-1.wav` (Groq Orpheus, LIST header)

---

**Resolved By:** Muse Spark (OpenCode)
**Time to Resolution:** ~20 min
