# Blocking Audio Capture Design Flaw

**Date:** 2026-10-09
**Project:** Karen
**Environment:** Development
**Severity:** Medium
**Status:** Workaround Applied (Gate 2 Paused)

## Summary
The current voice pipeline for Karen halts microphone audio capture entirely as soon as Voice Activity Detection (VAD) triggers silence. The capture stream remains blocked and stopped until the Text-to-Speech (TTS) response finishes playing. This prevents safe barge-in (interruption) by the user and delays subsequent queries.

## Symptoms
- Microphone does not capture audio while Karen is thinking (LLM processing) or speaking (TTS playback).
- The user cannot interrupt the assistant while it speaks.
- The audio capture channel is blocked during inference.

## Environment Details
- **Server/Host:** Local desktop application
- **Services Affected:** `pipeline::run`, `audio::spawn_audio_worker`, `tts::wait_all`
- **Related Components:** `src/lib.rs`, `src/audio.rs`
- **Time First Observed:** 2026-10-09

## Investigation Steps

### 1. Initial Diagnosis
Checked `src/lib.rs` and `src/audio.rs` for the audio capture integration.

### 2. Root Cause Analysis
In `src/lib.rs` line 156-180, we observed that `speech_rx` loop deliberately issues `AudioCommand::Stop` to the audio thread. It then awaits the entire processing pipeline `pipeline::run(app_handle.clone(), samples, format).await;` and `crate::tts::wait_all().await;` before issuing `AudioCommand::Start`.

### 3. Key Findings
- The application stops the audio stream before processing.
- Voice Activity Detection (VAD) dictates when to stop capture rather than just segmenting it.
- Lack of continuous capture prevents early processing and overlap.

## Root Cause
The audio stream lifecycle was unnecessarily coupled with the processing and playback stages, forcing a sequential turn-taking process rather than continuous listening.

## Prevention / Rule
**Guardrail:** Enforce a strict decoupling of the audio input thread from the processing/TTS thread by utilizing a continuous ring-buffer for audio samples and asynchronous message passing for state transitions, ensuring `cpal::Stream` remains open and running at all times.

This guardrail prevents the capture loop from being blocked by synchronous inference or TTS playback, resolving the barge-in capability issue.

## Solution

### Immediate Fix
Implemented explicit turn state abstractions in `turn.rs` to clearly manage utterance boundaries, IDs, and states independent of the audio thread. 

### Long-term Fix
Execution was paused at Phase 6 Gate 2 to plan a broad rewrite of the audio capture loop to support continuous capture and an echo-cancellation mechanism.

## Prevention
- [x] Code changes required (TurnManager implemented)
- [ ] Overhaul `audio.rs` for continuous capture
- [ ] Implement echo cancellation for TTS playback

---

**Resolved By:** Antigravity
**Time to Resolution:** Ongoing
