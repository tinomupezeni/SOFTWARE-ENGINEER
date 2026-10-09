# Karen Phase 8 — Signature Visual Identity (Gates 1–4)

**Date:** 2026-10-09
**Project:** Karen (karen-desktop)
**Type:** Architecture Decision / Implementation checkpoint
**Status:** In Progress (Gates 5–6 remain)

## Summary
Implemented the first four gates of Karen's Phase 8 "Signature Visual
Identity": a canonical, generation-stamped event contract for the voice
pipeline; a polished orb + transcript layer driven by that contract; an
isolated, reversible particle talking-face prototype on top of the
`thinking-orbs` public API; and real speech-visual sync where the mouth follows
the synthesized WAV's RMS amplitude rather than a canned loop. All work is
verified by static checks and 48 passing Rust unit tests; audible/visual tuning
is deferred to a manual smoke (Gate 6).

## Context / Trigger
Phase 8 was authorized to give Karen a distinctive, event-driven visual
presence (particle orb) plus a playback-synchronized talking-face prototype.
The prior runtime emitted ad-hoc, unversioned `karen-pipeline` events with no
generation/utterance identity, so the UI could not reliably distinguish a stale
response from the active one, and there was no path from audio amplitude to a
visual mouth.

## Scope
Included: Gate 1 (runtime event contract), Gate 2 (orb experience +
transcript), Gate 3 (isolated talking-face prototype behind a runtime toggle),
Gate 4 (RMS envelope → mouth aperture). Excluded/deferred: expanding the
200×200 frameless overlay (Gate 5, blocked on an open UI decision), viseme
lip-sync (only amplitude for now, by approval), and the manual smoke/tuning
(Gate 6). No fork of `thinking-orbs`; no new frontend dependencies (no test
runner is installed upstream).

## Method
- Inspect the existing shell, event flow, and TTS path before touching code.
- Model conversation state as an explicit Rust state machine
  (`TurnManager`/`TurnEvent`) and make `dispatch_turn_event` the single emitter
  path, stamping every event with `genId` (+`utteranceId` where meaningful).
- Mirror that contract in a pure frontend reducer so orb, text, and tone all
  derive from one canonical state; drop stale-`genId` events in both layers.
- Build the face only from `thinking-orbs` public exports via its documented
  `frame` escape hatch, so the feature is deletable and inherits the library's
  painter, theme, single rAF loop, reduced-motion static frame, and offscreen
  pause.
- Compute amplitude from the actual synthesized audio (`hound` decode + RMS
  envelope), attached to the playback command and emitted at audible start.

## Decisions & Findings
- **Generation stamping is the anti-race primitive.** Every pipeline event
  carries a monotonic `genId`; both the Rust playback worker and the frontend
  reducer discard stale generations. This fixed two real defects (logged
  separately) where completion was never dispatched and a duplicate answer
  emitter clobbered the stream.
- **`speaking-finished` fires at the `Wait` barrier, not per `aplay` exit**
  (intentional deviation from the §3 proposal): it guarantees one terminal
  transition per generation even across multiple audio chunks.
- **The face runs no animation timer of its own.** Aperture is sampled lazily
  from a module-level `{ envelope, rate, startedAt }` record each time the
  library paints a frame, preserving the "one rAF loop per visible canvas"
  motion budget. Under reduced motion the mouth correctly stays static.
- **Audio is the source of truth for the mouth.** The envelope is decoded from
  the provider WAV (Groq or Piper, both WAV) at 27 frames/s and
  peak-normalized, so the mouth tracks real speech and stops exactly on
  cancel/finish.
- **Reversibility:** deleting `src/face/` and reverting `OrbStage`/`App`
  removes the talking face entirely; the orb path is unchanged.

## Changes Made
Backend: `turn.rs` rewritten (state machine + transition tests); `lib.rs`
(`dispatch_turn_event` stamping, partial-transcript emit, barge-in interrupt,
`tts::wait_all` on stop, `tts::init` with app handle); `tts/mod.rs`
(`Wait` commands, speaking lifecycle, `karen-speech`/`-stop`, envelope on
`PlaybackCommand::Play`); `tts/envelope.rs` (new); `brain/mod.rs` (genId on
streamed answer + tool events); `pipeline.rs` (`is_non_speech_marker_pub`).
Frontend: `src/state/visualState.ts`, `src/state/useKarenVisualState.ts`,
`src/components/OrbStage.tsx`, `src/components/Transcript.tsx`,
`src/components/TalkingFace.tsx`, `src/face/faceFrame.ts` (new), `App.tsx`.
Design log: `karen-desktop/Phase8_Design.md` §10–§13.

## Verification
- `cargo test`: **48 passed** (34 baseline + 10 Gate 1 + 4 envelope), 0 failed.
- `npx tsc -b`, `npx oxlint`, `npx vite build`: all clean.
- Visual/audible behavior not verifiable headless — tracked under Gate 6.

## Follow-ups / Deferred
- **Gate 5 (hybrid window): blocked.** The 200×200 frameless overlay cannot
  host transcript history/panel/settings; expansion requires the one open UI
  decision before coding (stop-and-ask per constraints).
- **Gate 6:** manual smoke of orb, face toggle, and mouth sync; tune face
  geometry/radii and envelope response then.
- Pre-existing `unused_parens` warning in `tts/piper.rs:16` (not introduced
  here) — minor, safe to fix in a cleanup pass.
- Optional later: viseme lip-sync beyond amplitude.

## References
- Design/architecture log: `karen-desktop/Phase8_Design.md` (§10–§13).
- Bug entries: `Backend_and_API/KAREN-2026-10-09-turn-manager-never-dispatched-completion.md`,
  `...-provisional-transcript-never-emitted.md`,
  `...-duplicate-answer-emitter-clobbers-stream.md` (commit `489fdaf`).
- Library: `thinking-orbs` 0.3.2 (npm) / vendored 0.3.1 at `Projects/Karen/thinking-orbs`.

---

**Completed By:** Karen Phase 8 implementation session
**Duration:** Single session (Gates 1–4)
