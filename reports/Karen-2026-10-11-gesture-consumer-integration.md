# Friday gesture consumer: sidecar supervision + safe actions in Rust

**Date:** 2026-10-11
**Project:** Karen (Friday gesture integration)
**Type:** Feature (sensor/actor split)
**Status:** Completed, live-verified

## Summary

Wired the friday-gesture sidecar into Friday: a new `gesture.rs` module supervises the sidecar process, parses its NDJSON gesture events, and executes a fixed allowlist of safe media/volume actions, with HUD feedback via the existing pipeline event. Verified live — real fist gestures flowed end-to-end from camera to action dispatch. Two process-hygiene issues found and fixed along the way.

## Context / Trigger

User chose integration option (b): Friday-side consumer. Sidecar v1 already emitted stable gesture events; nothing consumed them.

## Scope

Included: sidecar supervision (spawn, stream, crash backoff, quit cleanup), event parsing, gesture→action mapping, direct safe actuation, HUD events, tests. Excluded: cursor control, LLM-tool routing for gestures, HUD toggle for the sidecar (env flag only).

## Method

Kept the sensor/actor split strict: sidecar always runs `--dry-run` (detects, never acts); Friday owns policy. Verified with unit tests, then a live run with the user making fists on camera.

## Decisions & Findings

- **Gestures bypass confirmation by design:** a deliberate fist is a direct command like Ctrl+Space or a media key — both act without popups. Only inherently safe, reversible actions are mapped (play/pause, next/prev track, speaker mute toggle, volume +5%). Anything beyond this must use the normal LLM tool + confirmation path. Reasoned in `gesture.rs` header.
- **Direct actuation, not tool-dispatcher routing:** gesture actions shell `dbus-send` (MPRIS) / `pactl` from `gesture.rs` instead of going through `brain::tools::dispatch`, which is built for LLM-proposed calls with confirmation accounting. Small duplication with sidecar `actions.py`, documented as the sensor/actor boundary.
- **HUD reuse:** gesture outcomes emit `karen-pipeline` `running-tool` events ("Gesture: fist → …") — no frontend change needed.
- **Orphaned sidecar squats the camera:** a sidecar outliving its dead backend holds `/dev/video0` exclusively, so the next supervisor generation crash-loops (`can't open camera by index`). Found via `/proc` fd scan. Fix discipline: `gesture::stop()` on quit + kill-by-PID hygiene; supervisor backoff prevents hot-looping meanwhile.
- **pkill/pgrep self-match lesson:** `pkill -f "tauri dev"` matches the invoking shell's own cmdline and kills it (several tool calls died this way). Bracketed patterns (`'target/debug/ap[p]'`) are safe. Worth remembering for any future process management here.
- **Sidecar teardown traceback** (`HandLandmarker.__del__` TypeError on early exit): guarded `close()` with try/except.
- Live result: `Right fist -> play_pause: PlayPause sent to 0/1 player(s)` twice — path works; Chrome exposed MPRIS but accepted nothing with no active media (expected; needs a playing source for a visible pause).

## Changes Made

- New: `karen-desktop/src-tauri/src/gesture.rs` (~250 lines: supervise loop, NDJSON parsing, MPRIS/pactl actions, 4 unit tests).
- `lib.rs`: `mod gesture`, supervisor thread in setup, `gesture::stop()` in quit handler.
- `.env`: `FRIDAY_GESTURE_ENABLED=true`, `FRIDAY_GESTURE_DIR=...` (gitignored; `.env.example` untouched — gesture flags are dev-only for now).
- `friday-gesture/hand_tracker.py`: teardown guard.

## Verification

- `cargo check`: clean. `cargo test`: 52/52 (48 existing + 4 gesture).
- Live: supervisor spawned sidecar as its child process; fist events parsed and dispatched within the same second; sidecar survived 28s+ stable after orphan cleanup.
- Remaining to verify with user: visible media pause (needs actual playing media, then a fist).

## Follow-ups / Deferred

- User live test: play music → fist → confirm pause.
- Optional: HUD toggle + status for sidecar; cursor control; continuous pinch-volume; thumbs_down mapping.
- Optional: Friday speaks a one-line acknowledgement on gesture actions (currently HUD-only).

## References

- Prior report: `reports/Karen-2026-10-11-gesture-sidecar-scaffold.md`
- Code: `karen-desktop/src-tauri/src/gesture.rs`, `friday-gesture/`
- Live log: `~/.local/share/com.tauri.dev/logs/friday.log` (`[gesture]` lines)

---

**Completed By:** Muse Spark (OpenCode)
**Duration:** ~50 min
