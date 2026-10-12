# Friday: zero-LLM fast path for plain conversational turns

**Date:** 2026-10-12
**Project:** Karen (Friday voice assistant)
**Type:** Architecture Decision / Latency Optimization
**Status:** Completed

## Summary

Added a deterministic reply path for plain conversational turns —
greetings, "are you there" checks, identity questions — that bypasses
`run_agentic`'s LLM call entirely. These turns now reach TTS as soon as
STT finishes, instead of waiting a full LLM round-trip for an answer that
was never going to need reasoning. Surfaced and fixed, in the same pass, a
pre-existing bug where the project's own in-progress deterministic command
router (`router::route`) produced HUD text with no audio at all — logged
separately as `KAREN-2026-10-12-router-routes-never-reached-tts.md`.

## Context / Trigger

User reported Friday "feels slow" and asked to look at a reference repo
(`github.com/Dix01/JARVIS`) for latency techniques. A research pass through
that repo's Python pipeline found one technique with a direct, low-risk
Rust port: a regex/keyword-matched "fast reply" for common utterances that
skips the LLM entirely (`jarvis/core/responses.py::core_reply`). Two other
findings from that repo didn't apply: its non-blocking stream-consumption
pattern (fixing a barge-in bug) was checked against Friday's
`brain::run_agentic` streaming loop and found already handled correctly —
Friday checks `current_gen_id` against the live TTS generation on every
chunk, so cancellation is never blocked on an in-flight LLM stream. Its
deterministic command routing (open app / set volume / etc.) turned out to
already exist in Friday as an uncommitted `brain/router.rs`.

## Scope

**Included:** a new `router::fast_reply` function covering greetings,
presence checks ("are you there"), and identity questions ("who are
you"); wiring it into `run_agentic` ahead of the LLM call; fixing the
TTS-silence bug in the existing `router::route` so both old and new
fast-paths actually speak.

**Excluded:** JARVIS's reply-sanity-check pattern (catching
malformed/echoed LLM output before voicing) — noted as a reasonable future
addition but not implemented this session, since it addresses a different
failure mode (bad LLM output) than the latency goal here. Also excluded:
deterministic intent classification for compound/multi-step commands —
Friday's tool-calling already goes through the LLM for anything beyond the
existing router's simple one-verb commands, and that's intentional scope,
not a gap.

## Method

1. Forked a research pass against the cloned JARVIS repo, scoped to
   latency techniques only, explicitly told to rule out anything
   Python/Electron-specific with no Rust equivalent.
2. Cross-checked each finding against Friday's actual code before acting on
   it (did not assume the reference repo's bugs or wins applied here) —
   confirmed the barge-in concern was already handled, confirmed the
   command-routing idea was already half-built.
3. Added the new fast-path at the same decision point as the existing
   router check (top of `run_agentic`, before the LLM budget/deadline
   setup), so it's obviously part of the same "skip the LLM when we can"
   family of checks rather than a separate mechanism.
4. While wiring the new path to `tts::speak_chunk`, searched for all
   existing call sites first and found the router's routes weren't calling
   it either — fixed at the shared root cause (`speak_now` helper) instead
   of only fixing the new code.

## Decisions & Findings

- Canned replies use small rotating pools (`GREETINGS`, `STATUS_CHECKS`)
  rather than a single fixed string per category, so repeated "hi"s during
  testing/daily use don't sound like a single looping recording. Rotation
  is a simple atomic counter, not randomness — keeps it deterministic and
  testable.
- Identity question ("who are you") is intentionally a single fixed
  string, not rotated — it's a factual answer, not a social nicety, so
  variation there would read as inconsistent rather than natural.
- `StopPlayback` was deliberately left out of the new `speak_now` wiring —
  `pipeline.rs`'s own cancel-command handling already treats "stop" as a
  silent acknowledgement by design (Friday shouldn't talk over a
  barge-in/cancel), so making it speak would be a regression, not a fix.
- Chose not to persist fast-path turns to conversation history
  (`messages` table) — consistent with the existing `router::route`
  behavior, which also returns before the `append_message("user", ...)`
  call. A "hi" / "hello" exchange isn't meaningful context for later
  turns, and skipping the DB round-trip keeps the fast path actually fast.

## Changes Made

- `karen-desktop/src-tauri/src/brain/router.rs`: added `fast_reply`,
  `GREETINGS`/`STATUS_CHECKS`/`IDENTITY` reply pools, rotation helper, and
  5 new tests.
- `karen-desktop/src-tauri/src/brain/mod.rs`: added `speak_now` helper;
  wired `fast_reply`, the background-task acknowledgement, and
  `router::Route::{SystemInfo,SetVolume,OpenApp}` through it.

## Verification

```bash
cargo check --manifest-path karen-desktop/src-tauri/Cargo.toml   # pass, pre-existing warnings only
cargo test --manifest-path karen-desktop/src-tauri/Cargo.toml    # 60 passed, 0 failed
```

Live voice retest (saying "hi", a routed command, and a real question) not
yet done this session — listed as a follow-up.

## Follow-ups / Deferred

- Live retest: confirm "hi" now gets an instant spoken reply, and that a
  routed command (e.g. "open the browser") is now audible where it
  previously wasn't.
- Consider porting JARVIS's malformed/echoed-reply sanity check ahead of
  `speak_chunk` in the streaming path, as a separate initiative — it
  addresses reply quality, not latency, so it doesn't belong in this one.
- `router::fast_reply`'s phrase list is intentionally small and exact-match
  only; if real usage shows common greeting variants falling through to
  the LLM, extend the match list rather than switching to fuzzy matching
  (keeps false-positive risk low on a path that bypasses the LLM
  entirely).

## References

- `KAREN-2026-10-12-router-routes-never-reached-tts.md` — the TTS-silence
  bug found and fixed as part of this work.
- `Karen-2026-10-12-vad-buffer-accumulates-idle-silence.md` — earlier
  this session; a different pipeline stage, same user-visible "Friday
  feels broken" symptom class.
- Reference repo (read-only, not vendored): `github.com/Dix01/JARVIS`.

---

**Completed By:** Claude (Claude Code)
**Duration:** ~45 min (research + implementation + verification)
