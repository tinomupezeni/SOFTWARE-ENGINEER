# Karen Phase 6: Gate 1 and Gate 2 Review

## Gate 1: Complete turn contracts
- **Implementation:** Added `TurnManager` state machine in `turn.rs`. The abstractions correctly enforce transitions: Idle -> Listening -> SpeechDetected -> Transcribing -> Finalized -> Processing -> Responding -> Idle. Explicit utterances IDs and cancellation states are supported.
- **Tests:** State transitions, valid and invalid, are fully tested and pass.
- **Status:** Gate 1 complete in terms of abstractions.

## Gate 2: Restore continuous capture and safe barge-in
- **Findings & Risks:** I have paused execution here due to the mandatory stop-and-review gate criteria: **"Continuous capture cannot be implemented safely with the current audio architecture."**
  - Currently, `audio.rs` creates an audio stream that blocks capture after VAD triggers `on_speech_end`.
  - In `lib.rs`, the code explicitly stops the audio stream, runs the pipeline (`pipeline::run().await`), waits for TTS to finish (`crate::tts::wait_all().await`), and only then restarts the audio stream.
  - To decouple microphone capture from transcription and TTS, we need to completely overhaul the capture loop so the cpal input stream remains open indefinitely. We will need an intermediate ring-buffer (or channel) that handles continuous streaming, and we'll need an explicit echo cancellation strategy to prevent Karen from hearing her own TTS output.

## Decision Needed
To safely restore continuous capture, I need to redesign the audio pipeline to run the CPAL stream indefinitely, feeding a buffer that drops old samples but handles VAD independently of the brain pipeline. Furthermore, handling barge-in (stopping TTS when user interrupts) will require tracking Karen's own playback to ignore it during VAD.

Shall I proceed with a broad rewrite of the audio capture loop in `audio.rs` and `pipeline.rs` to support continuous capture and decoupled barge-in?
