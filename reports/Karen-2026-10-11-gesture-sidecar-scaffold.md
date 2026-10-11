# Friday gesture sidecar v1 scaffold (Python + MediaPipe, decoupled)

**Date:** 2026-10-11
**Project:** Karen (Friday gesture sidecar)
**Type:** New Service Scaffold
**Status:** Completed

## Summary

Scaffolded `friday-gesture/`, a standalone hand-gesture service decoupled from the Friday Tauri backend: webcam → MediaPipe Tasks HandLandmarker → rule-based classifier → stabilization → NDJSON gesture events on stdout (+ optional HTTP POST) → Linux action executors. Smoke-tested live on the room camera: detects hands, classifies gestures, emits well-formed events with cooldowns respected. No Friday code was touched.

## Context / Trigger

User request: give Friday camera-based hand control as a separate module/service; survey similar GitHub projects first (done in prior turn), then begin. Chose Python + MediaPipe Tasks for v1 speed, with the event protocol designed so a later Rust rewrite is drop-in.

## Scope

Included: tracker, classifier, stabilizer, Linux actions (MPRIS media, pactl volume/mute), main loop with preview overlay, dry-run mode, JSON event protocol, config file. Excluded: Friday-side consumer (no Tauri endpoint yet), cursor control, continuous pinch-volume, custom trained gestures.

## Method

Environment-first: probed for Python/MediaPipe/camera/action tooling before writing code, and let findings drive decisions (Python 3.12 via uv because only 3.14 is system-installed; D-Bus MPRIS + pactl because no sudo/playerctl).

## Decisions & Findings

- **Python 3.12 venv via uv** (`.venv`, requirements.txt): system Python is 3.14-only with no pip; uv already had a 3.12.8 runtime. Deps: opencv-python, mediapipe 1.1.0, numpy.
- **MediaPipe Tasks `hand_landmarker.task`** (float16, auto-downloaded to `models/`), VIDEO running mode, 2 hands — not legacy `mp.solutions.hands`.
- **Rule-based classifier** on 21 landmarks (fist, open_palm, peace, thumbs_up, scale-normalized pinch) + Stabilizer (5-frame hold, 1200ms cooldown, refire needs fresh hold). Geometry over ML, per the gesture-lenet finding that landmarks→gesture is a lightweight problem.
- **Actions need no new packages:** MPRIS over dbus-send (PlayPause/Next/Previous to all players), volume/mute over pactl. playerctl unavailable (no sudo) and unnecessary.
- **Event protocol:** NDJSON on stdout (`type: gesture|status|warn`) + best-effort `--post-url`; Friday backend can consume either later.
- **Bug found in smoke test:** MPRIS player-name parsing grabbed garbage (`"]: ok"`); fixed with a strict `"...org.mpris.MediaPlayer2..."` regex. Verified clean afterward.
- **Live detections across two runs** (open_palm/Left, then fist/Right, cooldown-spaced) are consistent with the user moving their hand in front of the camera during testing — still needs explicit confirmation it wasn't background false-positives.

## Changes Made

- New: `friday-gesture/{main.py, hand_tracker.py, gestures.py, actions.py, config.json, requirements.txt}` (+ `.venv/`, `models/hand_landmarker.task` fetched artifacts).
- Default bindings: fist→play_pause, peace→next_track, open_palm→prev_track, pinch→toggle_mute. Dry-run default-safe posture (detection without action until `--dry-run` is dropped).

## Verification

- `main.py --dry-run --no-preview --max-frames 60/30`: camera opens, model loads, 60+30 frames processed, stable gesture events emitted, clean `stopped` status. Cooldown spacing confirmed in timestamps.
- Unit-level logic (classifier geometry, stabilizer) exercised live; no test suite yet (deferred — service is pre-v1).

## Follow-ups / Deferred

- Confirm detections were the user's real hand, not background false positives; add a no-hand baseline run if needed.
- Live action test (drop `--dry-run`, verify MPRIS/pactl actuation) + visual preview check (`--dry-run` with preview, `q` quits).
- Friday-side consumer: Tauri sidecar or `--post-url` endpoint mapping gesture events into the existing tool/confirmation system.
- v2: cursor control, continuous pinch-volume, custom trained gestures (HaGRID-style MLP).

## References

- Service: `friday-gesture/` in the Karen repo (untracked scaffold).
- Survey: prior-turn shortlist (Mizuna737/gesturecontrol, Abhi-desig/Gesture, Handigo, Nexus_Link, gesture-lenet-showcase, Kazuhito00, PINTO0309).

---

**Completed By:** Muse Spark (OpenCode)
**Duration:** ~35 min
