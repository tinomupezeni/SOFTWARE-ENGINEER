# Incident/Bug Report: Provisional Transcripts Computed But Never Surfaced

## Metadata
- **Project**: Karen
- **Date**: 2026-10-09
- **Area**: Backend_and_API
- **Severity**: Medium

## Description
Partial speech recognition ran continuously (the partial worker in `lib.rs`
calls `stt::transcribe_partial` every VAD tick), and its output was fed to
the `TurnManager` as `TurnEvent::ProvisionalTranscript`. However, no
`karen-pipeline` event ever carried the provisional text: the
`Recognizing`/`Finalizing` states mapped only to a detail-less `transcribing`
stage. The frontend therefore had no way to show what the user was currently
saying before the final transcript landed.

## Root Cause
`dispatch_turn_event` only emitted whatever `TurnState::as_pipeline_event`
returned. `ProvisionalTranscript` changes state but is not itself a state
mapping, so its payload was discarded at dispatch time. The data existed in
memory and was thrown away at the emit boundary.

## Resolution
`dispatch_turn_event` now special-cases `TurnEvent::ProvisionalTranscript` and
emits a dedicated `{stage:"provisional-transcript", detail, genId}` event.
The frontend reducer renders this in a distinct provisional style and clears
it when the final transcript arrives, so in-progress speech is visible without
being mistaken for the committed utterance.

## Prevention / Rule
**Guardrail:** A `karen-pipeline` stage that is produced by the backend must
have a matching consumer in the frontend's `KarenVisualState` union, and the
reverse — enforced by keeping the stage strings in one typed module and
grepping for unconsumed stages in review.

This closes the gap because the defect was a producer/consumer mismatch on a
stringly-typed event channel; a single typed stage list makes an emitted-but-
unconsumed stage visible.

## Related Issues
- KAREN-2026-10-09-turn-manager-never-dispatched-completion.md

## Resolved By
opencode (agent), Karen Phase 8 Gate 1
