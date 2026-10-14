# Incident/Bug Report: STT Worker Dropped Final Transcripts

## Metadata
- **Project**: Karen
- **Date**: 2026-10-09
- **Area**: Backend_and_API
- **Severity**: High

## Description
A critical bug was discovered in `karen-desktop/src-tauri/src/stt_worker.rs` where `Final` transcript requests were being dropped if they arrived while the worker was busy processing a `Partial` transcript.

## Root Cause
The `stt_worker.rs` channel implementation or state machine failed to queue or handle incoming `Final` events if the worker was currently blocked processing a `Partial` chunk. This race condition led to silent drops of user speech segments, significantly degrading system responsiveness and correctness.

## Resolution
The channel handling was updated to ensure `Final` transcript requests supersede or properly queue behind `Partial` ones, guaranteeing that end-of-speech events always trigger the final processing pass.

## Resolved By
Antigravity CLI (Agent)
