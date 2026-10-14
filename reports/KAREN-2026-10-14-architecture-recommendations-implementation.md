# Karen Architecture Recommendations Implementation

**Date:** 2026-10-14
**Project:** Karen / Friday
**Type:** Architecture Refactor / Research Implementation
**Status:** Completed with deferred benchmark evidence

## Summary

Implemented the seven ordered architecture recommendations derived from the
GitHub reference research. Karen now exposes explicit capability contracts,
structured STT benchmark telemetry, policy metadata for confirmation and
provenance, a separate artifact ledger, audited gesture actions, and safer MCP
browser classification. The Rust test suite and React production build pass.

The remaining evidence gap is comparative STT quality benchmarking: the
runtime now emits the measurements needed for a model matrix, but alternate
Whisper model files and a fixed utterance corpus were not available during
this session.

## Context / Trigger

The project requested implementation of seven engineering recommendations:

1. Capability/skill boundaries.
2. VAD and quantized Whisper benchmarking.
3. Policy-driven tool confirmations.
4. Separation of memory domains.
5. Semantic gesture-event integration.
6. Semantic and provenance-aware browser automation.
7. Verification and documentation.

## Scope

Included:

- Native and MCP capability metadata.
- Tool lifecycle, risk, contracts, confirmation previews, cancellation, and
  argument-constraint metadata.
- STT measurement instrumentation.
- Artifact persistence and screenshot registration.
- Gesture audit events.
- MCP provenance and untrusted-content markers.
- Browser navigation confirmation classification.
- Architecture documentation and focused/full verification.

Excluded:

- Selecting a final Whisper model based on WER.
- Adding a new VAD dependency.
- Replacing the current SQLite memory engine with Mem0/Letta.
- Implementing a new browser automation server.
- Rewriting the existing React HUD or unrelated pre-existing changes.

## Method

Inspected the existing runtime and test surfaces first, then changed the
smallest existing seams:

- `brain/tools.rs` remains the native registry and now owns canonical
  capability metadata.
- `stt.rs` records structured per-inference measurements.
- SQLite receives an `artifacts` table and artifact methods.
- `gesture.rs` records semantic sidecar actions.
- `mcp.rs` carries provenance and marks external result content untrusted.
- `ARCHITECTURE.md` records the new contracts and boundaries.

Each change was followed by focused tests, then the complete Rust suite and
frontend build.

## Decisions & Findings

### Capability and policy boundary

`CapabilitySpec` is now the canonical source for native and MCP tool source,
lifecycle, risk, confirmation preview, cancellability, argument constraints,
input, output, and failure contracts. Unknown capabilities are rejected before
argument parsing or execution. The same metadata is attached to
model-visible `x-capability` fields and included in confirmation/audit text.

### STT measurement

Each Whisper transcription emits `STT_BENCHMARK` with model name, audio
duration, audio context, thread count, inference milliseconds, and realtime
factor. This enables controlled comparisons across `KAREN_WHISPER_MODEL`
values. A quality benchmark remains deferred until fixed audio fixtures and
alternate model files are available.

### Memory and artifacts

Conversations, memories, tasks, events, and artifacts are now explicit
domains. Successful screenshot-like tool results are recorded in `artifacts`
with kind, path, metadata, and timestamp. Artifact records are intentionally
not injected into prompts automatically.

### Gestures

The sidecar remains a semantic sensor running with `--dry-run`; Karen owns
actuation and now records each gesture action as a `gesture_action` event.
Only the existing safe media/volume allowlist is actuated.

### Browser/MCP safety

MCP results now include `mcp://server/tool` provenance and an
`untrusted_content` marker. Browser snapshots, screenshots, console/network
inspection, tab listing, and bounded waits remain read-only. Navigation and
other state-changing browser actions require confirmation, reducing exposure
to navigation-driven prompt injection and unintended state changes.

## Changes Made

Karen source changes:

- `ARCHITECTURE.md`
- `karen-desktop/src-tauri/src/brain/tools.rs`
- `karen-desktop/src-tauri/src/stt.rs`
- `karen-desktop/src-tauri/src/memory/database.rs`
- `karen-desktop/src-tauri/src/memory/mod.rs`
- `karen-desktop/src-tauri/src/memory/artifacts.rs`
- `karen-desktop/src-tauri/src/gesture.rs`
- `karen-desktop/src-tauri/src/mcp.rs`

The Karen worktree also contains unrelated pre-existing modifications and
untracked dataset/training artifacts; they were preserved.

## Verification

- `cargo test --manifest-path karen-desktop/src-tauri/Cargo.toml`
  - 76 tests passed.
- `cd karen-desktop && npm run build`
  - TypeScript build and Vite production bundle passed.
- `git diff --check`
  - No whitespace errors reported.
- Focused capability, STT, memory, gesture, and MCP tests passed during
  iteration.

Existing compiler warnings remain in unrelated/pre-existing areas, including
unused imports and dead-code warnings.

## Follow-ups / Deferred

1. Collect a fixed utterance corpus covering quiet speech, noise, technical
   terms, and wake/cancel phrases.
2. Run the corpus against tiny/base/small and quantized Whisper variants,
   comparing transcript quality, inference milliseconds, and realtime factor.
3. Add artifact retrieval as an explicit, permissioned tool if the HUD needs
   to display or reuse captured files.
4. Add per-tool structured schemas for confirmation previews instead of the
   current contract strings.
5. Add adversarial browser tests covering prompt injection in page content and
   navigation results.

## References

- `ARCHITECTURE.md`
- `karen-desktop/src-tauri/src/brain/tools.rs`
- `karen-desktop/src-tauri/src/stt.rs`
- `karen-desktop/src-tauri/src/mcp.rs`
- `karen-desktop/src-tauri/src/gesture.rs`
- `karen-desktop/src-tauri/src/memory/`
- `SOFTWARE-ENGINEER/reports/KAREN-2026-10-14-github-reference-research.md`

---

**Completed By:** Copilot
**Duration:** Approximately 45 minutes
