# Incident/Bug Report: Duplicate `answer` Emitter Clobbered Streamed Text

## Metadata
- **Project**: Karen
- **Date**: 2026-10-09
- **Area**: Backend_and_API
- **Severity**: Medium

## Description
The `answer` pipeline stage was emitted from two independent places:

1. `brain/mod.rs` during LLM streaming, with the growing accumulated text as
   `detail` (the actual response).
2. `turn.rs` via `TurnState::Speaking`, whose `as_pipeline_event` mapped to
   `("answer", None)`.

Because the second emit had no detail, it overwrote the streamed answer in the
UI with an empty/bare payload, so the user could see the response appear and
then blank out when the turn transitioned to `Speaking`.

## Root Cause
Two sources of truth for one stage. The state machine treated `Speaking` as an
`answer` event even though the streaming emitter already owned that stage;
there was no de-duplication and no ordering guarantee between them.

## Resolution
- `TurnState::Speaking` now maps to **no** pipeline stage. The canonical
  "speaking" signal is the audio-playback lifecycle
  (`karen-speech` / `karen-speech-stop`, plus `speaking-started` /
  `speaking-finished`), which is the only truth for when audio is audible.
- `answer` is emitted solely by the streaming LLM path, now stamped with
  `genId`, and the frontend reducer drops events from stale generations.
- Frontend `reducePipeline` treats `answer` as a content update that never
  downgrades the current stage, removing the double transition.

## Prevention / Rule
**Guardrail:** Each `karen-pipeline` stage has exactly one emitter, recorded
in a comment/registry next to the stage list; a review check rejects a second
`app.emit("karen-pipeline", {stage: <existing>})` call site.

This closes the gap because the bug was a second emitter for an
already-owned stage; making ownership explicit and singular prevents the
reintroduction of a clobbering duplicate.

## Related Issues
- KAREN-2026-10-09-turn-manager-never-dispatched-completion.md

## Resolved By
opencode (agent), Karen Phase 8 Gate 1
