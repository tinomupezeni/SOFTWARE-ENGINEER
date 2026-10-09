# Incident/Bug Report: Turn Manager Never Dispatched Completion

## Metadata
- **Project**: Karen
- **Date**: 2026-10-09
- **Area**: Backend_and_API
- **Severity**: High

## Description
The `TurnManager` state machine in `karen-desktop/src-tauri/src/turn.rs` is
meant to be the single authoritative source of truth for the voice turn
lifecycle, but no code path ever dispatched `TurnEvent::SpeakingFinished` or
the post-answer `TurnEvent::TurnCompleted`. A turn that had reached
`Reasoning` or `Speaking` therefore had no exit: the state (and any UI driven
from it) could stay stuck in "speaking"/"thinking" indefinitely after audio
had already finished.

## Root Cause
Completion was never wired to the actual audio playback lifecycle. The
playback worker in `tts/mod.rs` knew exactly when playback started and ended
(it toggles `AudioBuffer::set_tts_playing`), but it emitted no turn event on
finish, and nothing in `pipeline.rs`/`lib.rs` dispatched the terminal event.
`TurnState::Speaking`/`Reasoning` were terminal in practice.

## Resolution
- Added a `Wait` barrier to the TTS/playback command channels. After
  `pipeline::run(...)` returns, the caller awaits `tts::wait_all()`, which is
  ordered behind every queued `Speak`/`Play` command for that generation.
- At the barrier the playback worker now emits `speaking-finished` +
  `karen-speech-stop`, dispatches `TurnEvent::TurnCompleted`, then unblocks
  the waiter. Cancel kills the active `aplay` child and emits the same stop
  events.
- `SpeakingFinished` now carries a `generation_id`; a finish for an older
  generation is ignored, and `Speak`/`Play` chunks are dropped when their
  generation no longer matches `CURRENT_GENERATION`.
- `turn.rs` gained transitions out of `Speaking`/`Reasoning`/`ExecutingTools`
  to `Completed`, and unit tests covering stale-generation finishes, the
  no-audio completion path, barge-in, and rapid repeated turns.

## Prevention / Rule
**Guardrail:** Every non-terminal state in `TurnManager` must have at least
one enumerated exit transition exercised by a unit test; the state enum's
`as_pipeline_event`/`utterance_id` helpers force new states to declare how
they map. A CI check that runs `cargo test -p app` on every change to
`turn.rs`/`tts/mod.rs` keeps the contract covered.

This closes the gap because the bug was a missing *exit*, and an enum plus
per-state exit test makes a missing exit a compile-/test-time failure rather
than a runtime hang.

## Related Issues
- KAREN-2026-10-09-provisional-transcript-never-emitted.md
- KAREN-2026-10-09-duplicate-answer-emitter-clobbers-stream.md

## Resolved By
opencode (agent), Karen Phase 8 Gate 1
