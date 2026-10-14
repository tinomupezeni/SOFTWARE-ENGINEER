# GitHub Reference Research for Karen/Friday

**Date:** 2026-10-14
**Project:** Karen / Friday
**Type:** Research Spike / Architecture Reference
**Status:** Completed

## Summary

Compared Karen/Friday's voice-first Tauri desktop architecture with ten
high-signal GitHub projects covering voice-assistant runtimes, local speech
processing, desktop IPC, agent execution, memory, browser automation, and
gesture recognition. The strongest references are OpenVoiceOS for modular
skills and lifecycle events, whisper.cpp for low-latency local STT, Piper for
local TTS, Open WebUI for provider/tool/memory boundaries, Open Interpreter for
protocolized execution, and Tauri for privileged desktop integration.

## Context / Trigger

The project requested external engineering references before extending the
codebase. Karen currently combines Rust/Tauri, React, Whisper, Piper/Groq,
streaming LLM tool execution, SQLite memory, MCP browser tooling, and a
MediaPipe gesture sidecar. The objective was to identify proven patterns worth
adapting without importing the scale or assumptions of much larger platforms.

## Scope

Included:

- Voice-assistant runtime and skill architecture.
- Local Whisper/STT and Piper/TTS implementation patterns.
- Tauri desktop IPC and capability boundaries.
- Agentic tool execution, approvals, and protocol boundaries.
- Durable memory and retrieval architecture.
- Browser automation and gesture-event design.
- Repository activity, license, and maintenance caveats.

Excluded:

- Benchmarking Karen against the referenced projects.
- Copying code or selecting dependencies for immediate implementation.
- Security sign-off for browser or desktop automation.
- Full review of every repository's issue tracker and release history.

## Method

Used source-level GitHub repository documentation and repository metadata
available on 2026-10-14. Repositories were selected for architectural
relevance rather than popularity alone, then compared against the actual
Karen layout and runtime described in `README.md`, `ARCHITECTURE.md`,
`karen-desktop/src-tauri/src/`, `karen-desktop/src/App.tsx`, and
`friday-gesture/`.

## Decisions & Findings

### Highest-value references

| Repository | Relevant pattern | Recommended use |
|---|---|---|
| [OpenVoiceOS/ovos-core](https://github.com/OpenVoiceOS/ovos-core) | Central runtime, installable skills, message-bus lifecycle, deterministic skills with LLM fallback | Split Karen's growing tool registry into modular capabilities with explicit discovery, readiness, failure, and unload events |
| [ggml-org/whisper.cpp](https://github.com/ggml-org/whisper.cpp) | Offline inference, VAD, quantized models, hardware backends, offline assistant examples | Evaluate VAD, model-size/quantization selection, and streaming latency improvements while keeping Karen's narrow STT interface |
| [OHF-Voice/piper1-gpl](https://github.com/OHF-Voice/piper1-gpl) | Local neural TTS with separate phonemization, voice assets, CLI, HTTP, and library paths | Preserve Piper behind the existing TTS provider abstraction and keep model assets independently configurable |
| [tauri-apps/tauri](https://github.com/tauri-apps/tauri) | Rust-owned privileged runtime, frontend IPC, tray/bundling/updater facilities, capability permissions | Keep privileged actions in narrowly scoped Rust commands and events rather than exposing broad backend surfaces |
| [open-webui/open-webui](https://github.com/open-webui/open-webui) | Provider adapters, tools/skills/MCP, persistent memory, voice providers, hybrid retrieval, approvals | Separate conversation context, durable memory, artifacts, providers, and tool permissions; consider hybrid FTS/vector retrieval |
| [openinterpreter/openinterpreter](https://github.com/OpenInterpreter/open-interpreter) | Model/harness separation, MCP/skills, protocol-compatible execution backends | Make tools composable through protocol boundaries instead of hard-coding every integration into the brain |

### Focused subsystem references

| Repository | Relevant pattern | Caveat |
|---|---|---|
| [mem0ai/mem0](https://github.com/mem0ai/mem0) | User/session/agent memory, temporal metadata, entity linking, semantic plus keyword retrieval | Managed-platform benchmarks do not automatically describe the open-source path; local SQLite remains simpler for a single-user assistant |
| [letta-ai/letta](https://github.com/letta-ai/letta) | Explicit long-lived agent identity, working context versus durable memory, channels and app-server boundaries | The repository points toward newer active source; use it as a design reference until the current lineage is reviewed |
| [microsoft/playwright-mcp](https://github.com/microsoft/playwright-mcp) | Accessibility-tree observations, semantic locators, deterministic browser actions, persistent browser state | Browser content is an untrusted prompt-injection surface; confirmation and provenance remain mandatory |
| [google-ai-edge/mediapipe](https://github.com/google-ai-edge/mediapipe) | On-device Tasks APIs and platform-independent landmark inference | Use current Tasks APIs rather than legacy MediaPipe solutions |

### Engineering recommendations for Karen

1. Introduce an explicit capability/skill boundary around native tools and
   MCP tools. Each capability should declare its lifecycle, risk, inputs,
   outputs, and failure behavior.
2. Keep deterministic command routing ahead of the LLM where the intent is
   unambiguous, using the model as a fallback for open-ended reasoning rather
   than the sole dispatcher.
3. Preserve the current STT/TTS provider interfaces while evaluating VAD,
   quantized Whisper models, and a worker boundary for blocking TTS processes.
4. Extend the current `ToolRisk` model into policy objects that can describe
   confirmation previews, provenance, cancellation, and per-tool argument
   constraints.
5. Separate conversation history from durable memories, task state, activity
   events, and artifacts. Add temporal/entity metadata before adding a larger
   memory dependency.
6. Treat gesture recognition as a semantic event producer. The gesture sidecar
   should emit debounced events; Karen's normal risk policy should decide
   whether an event may trigger a mutating action.
7. Prefer accessibility-tree browser observations and semantic actions over
   pixel-coordinate automation, while keeping browser execution in an external
   MCP boundary.

### Maintenance and adoption cautions

- Popularity is not proof of fit. Open WebUI, Letta, and Open Interpreter are
  much larger systems than Karen and should contribute boundaries and patterns,
  not wholesale architecture.
- `OHF-Voice/piper1-gpl` is technically relevant but its repository notes a
  maintainer need; monitor upstream health and licensing/model distribution.
- Browser and desktop automation have materially higher risk than ordinary
  chat. Prompt injection resistance, allowlists, confirmation previews,
  cancellation, and audit events must remain first-class.
- `letta-ai/letta` should not be treated as the current implementation source
  without following its pointer to the active project.

## Changes Made

Created this cross-project research report in the shared engineering records
repository. No Karen source files or dependencies were changed.

## Verification

- Compared ten repositories against Karen's documented and implemented
  subsystems.
- Confirmed each recommendation is tied to a primary GitHub repository URL.
- Checked the Karen worktree before and after research; no Karen files were
  modified by this research activity.

## Follow-ups / Deferred

- Create a time-boxed implementation spike for capability/skill boundaries.
- Benchmark VAD and quantized Whisper options against Karen's current
  transcription latency.
- Design a policy schema for confirmation previews and browser provenance.
- Audit the current SQLite memory schema against user/session/agent/temporal
  memory requirements.
- Review current Playwright MCP and Letta successor repositories before
  adopting their interfaces.

## References

- `README.md`
- `ARCHITECTURE.md`
- `karen-desktop/src-tauri/src/brain/mod.rs`
- `karen-desktop/src-tauri/src/brain/tools.rs`
- `karen-desktop/src-tauri/src/pipeline.rs`
- `karen-desktop/src-tauri/src/memory/`
- `karen-desktop/src-tauri/src/tts/`
- `friday-gesture/`
- `SOFTWARE-ENGINEER/Principal_Engineer/engineering-guides/16. AI Agent Orchestration and Delegation.md`
- `SOFTWARE-ENGINEER/Principal_Engineer/engineering-guides/19. Issue-to-Verified-Production Engineering Workflow.md`

---

**Completed By:** Copilot
**Duration:** Approximately 30 minutes
