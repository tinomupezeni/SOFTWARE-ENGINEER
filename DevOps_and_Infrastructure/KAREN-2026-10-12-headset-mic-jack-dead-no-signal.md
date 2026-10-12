# Headset mic jack delivering no usable signal; internal mic works fine

**Date:** 2026-10-12
**Project:** Karen (Friday voice assistant)
**Environment:** Development (user's workstation)
**Severity:** Critical
**Status:** Workaround Applied

## Summary

Friday could not recognize any speech regardless of VAD/threshold tuning or gain level. A controlled test recording directly from the system's default PipeWire source (bypassing Friday's app entirely) showed the active "headset microphone" port on the combo audio jack produced a flat, unchanging signal whether the room was silent, the user was speaking loudly and repeatedly, or the mic was physically tapped -- i.e. no usable signal was reaching the OS from that port at all. Switching the active port to the laptop's internal microphone immediately produced a clean, correctly-scaled signal that Whisper transcribed correctly on the first try. This is a hardware/cabling issue with the headset or its jack, not a Friday bug.

## Symptoms

- Every spoken utterance produced `[BLANK_AUDIO]`, an empty transcript, or an unrelated hallucinated sentence, regardless of VAD tuning, gain level (tried 15%-100%), or Whisper model (`tiny.en`, `small.en`).
- Ambient-noise RMS and actively-speaking RMS were nearly identical at every gain level tested on the headset mic port (e.g. silence peak 0.030 vs. repeated loud speech peak 0.036) -- the signal was not responding to the user's voice at all.
- Physically tapping the microphone produced no detectable change in captured level.

## Environment Details

- **Server/Host:** garden (Linux, PipeWire)
- **Hardware:** Realtek/Intel "Sunrise Point-LP HD Audio" onboard codec (`alsa_card.pci-0000_00_1f.3`), single sound card with no separate USB or Bluetooth audio device connected
- **Services Affected:** `karen-desktop` Tauri app's CPAL-based mic capture (`audio.rs`), but the root issue sits below the app entirely, at the OS/hardware audio-routing layer
- **Time First Observed:** 2026-10-12, during a live voice-recognition debugging session

## Investigation Steps

### 1. Initial Diagnosis

Multiple rounds of VAD/gain/threshold tuning (see `KAREN-2026-10-12-vad-stuck-state-silently-discarded.md`) improved the app's own detector behavior but speech was still never transcribed correctly. Needed to rule out the app/VAD logic entirely before tuning further.

### 2. Root Cause Analysis

Confirmed via `pactl`/`lsusb`/`bluetoothctl` that only one audio device exists on this machine, with its active input port already set to `analog-input-headset-mic` (the combo 3.5mm jack's headset-mic mode) -- so there was no separate device-selection bug; the system already believed it was listening through the headset.

Wrote a standalone diagnostic (`cargo run --example mic_test`, since removed) that recorded directly from the default PipeWire source via `parecord` (bypassing CPAL/Friday entirely) and ran the result through the same Whisper model/params as `stt.rs`, reporting peak/RMS alongside the transcript:

```bash
timeout <secs> parecord --channels=1 --rate=16000 --format=s16le --raw /tmp/mic_test_capture.raw
```

Results on `analog-input-headset-mic` at multiple gain levels:
- Silence: peak=0.0302, rms=0.0085
- User repeating a phrase for 6s: peak=0.0362, rms=0.0088 (essentially unchanged)
- Physical taps on the mic: peak=0.0341, rms=0.0088 (no detectable transient)

Switched the active port with `pactl set-source-port alsa_input.pci-0000_00_1f.3.analog-stereo analog-input-internal-mic` and reran the identical test:
- A spoken phrase at 30% gain: peak=1.0000 (clipping), rms=0.0655, Whisper correctly transcribed "Testing."
- At 20% gain: peak=0.1476, rms=0.0142, Whisper again correctly transcribed "Testing."
- Silence at 20% gain: peak=0.0140, rms=0.0036 -- a clean ~4x RMS / ~10x peak separation from speech.

### 3. Key Findings

- The headset-mic port is selected and "active" per PipeWire, but delivers no signal that responds to actual sound at all -- not a sensitivity/gain problem, a dead signal path.
- The onboard internal microphone works correctly and gives a clean, usable signal-to-noise ratio once gain is set appropriately (20% for this hardware).
- This was fully decoupled from Friday's own code by testing with `parecord` directly -- the app-level VAD/threshold work in the companion entry was necessary but could never have succeeded while capturing from a dead input.

## Root Cause

The headset's microphone circuit is not delivering signal through the 3.5mm combo jack -- consistent with a bad cable/connector, a wiring mismatch (e.g. a headphone-only TRS plug in a TRRS jack), a muted/disabled inline control on the headset, or a fault in the headset's mic element itself. The specific physical cause was not isolated further within this session; a different headset was not available to test.

## Prevention / Rule

**Guardrail:** when a voice pipeline produces no usable transcriptions despite VAD/gain tuning, verify the raw signal independent of the app (e.g. `parecord` + direct model inference, or at minimum `parecord ... | sox - -n stat` for peak/RMS) *before* tuning app-level thresholds further -- add this as the first step in `FRIDAY_AUDIO_DIAGNOSTIC_HANDOFF.md`'s troubleshooting order, ahead of VAD tuning.

Every statement about dB/dBFS values in this session is derived from the recorded samples' own peak/RMS, not estimated -- treat any future figure here the same way unless it also cites measured values. This guardrail would have surfaced the dead mic port in minutes instead of after extensive VAD rework, since tuning a detector against a signal that doesn't exist can never succeed regardless of threshold values.

## Solution

### Immediate Fix (Workaround)

Switched the system default source's active port to the internal microphone and set input gain to 20%:

```bash
pactl set-source-port alsa_input.pci-0000_00_1f.3.analog-stereo analog-input-internal-mic
pactl set-source-volume @DEFAULT_SOURCE@ 20%
```

This is a runtime-only PipeWire setting, not a Friday app configuration -- it is **not persisted** across reboots/replugs by this change alone. It should be set permanently via the system's Sound settings GUI (or a WirePlumber rule) if the headset mic issue isn't resolved physically.

### Long-term Fix

- Test with a different headset/cable to confirm whether the fault is the cable, the headset's mic element, or the jack itself.
- If the user wants to keep using headset audio output while relying on the internal mic for input, no further app changes are needed -- PipeWire allows independent source/sink selection.
- If a different headset is later connected via USB, it will appear as a separate `lsusb`-visible device and a separate PipeWire source; re-verify with the same `parecord` peak/RMS method before assuming it works.

## Prevention

- [ ] Configuration changes needed: persist the internal-mic port selection via system Sound settings (GUI) or a WirePlumber config, since the current fix is runtime-only
- [ ] Physically test the headset/cable on another device to isolate cable vs. headset vs. jack
- [x] Documentation to update (`FRIDAY_AUDIO_DIAGNOSTIC_HANDOFF.md` should list this signal-verification step first in future audio debugging)

## Related Issues

- `KAREN-2026-10-12-vad-stuck-state-silently-discarded.md` -- the app-level VAD work done in parallel with this diagnosis; necessary but insufficient on its own since it was being tuned against a dead signal for most of the session.
- `FRIDAY_AUDIO_DIAGNOSTIC_HANDOFF.md` -- prior session's handoff document; this finding extends it with a concrete signal-verification method.

## References

- Files: `karen-desktop/src-tauri/src/audio.rs` (unaffected by this finding, but was the focus of parallel tuning)
- Tools used: `pactl`, `parecord`, `lsusb`, `bluetoothctl`

---

**Resolved By:** Claude (Claude Code)
**Time to Resolution:** ~20 min once isolated via a direct signal test (several hours of VAD tuning preceded this, logged separately)
