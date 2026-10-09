# PROJECT GUIDE ADAPTER — Karen

> Use this file to record how the engineering-guides library was "rewired" into a
> specific project. One adapter per project. It is the bridge between the generic
> guides (in `dev-logs/Principal_Engineer/engineering-guides/`) and the project's
> own `CLAUDE.md` / `ARCHITECTURE.md` / `docs/`.

## Project

- **Name:** Karen
- **Path:** /home/shadowe/Projects/Karen
- **Stack:** Rust (Tauri), React/Vite, Groq API (LLM/TTS), Whisper/Piper (STT/TTS), SQLite
- **Deploys to:** Local Desktop Application

## Guides applied

### 2. Project Documentation
- **Ported sections:** Documentation inventory, audience-first writing, architectural documentation structure.
- **Landed in:** `karen-desktop/README.md`, `karen-desktop/ARCHITECTURE.md`, `karen-desktop/.env.example`, `karen-desktop/docs/adr/`.
- **Adaptation:** As a local desktop client and AI interface rather than a web service, the documentation focuses heavily on latency (TTFT), local hardware capabilities, and async pipeline cancellation rather than HTTP API contracts.
- **Compliance:** [x] `README.md` exists [x] `ARCHITECTURE.md` exists [x] ADRs established for major state decisions

### 16. AI Agent Orchestration and Delegation
- **Ported sections:** Shifting verification to constraints, prompt boundaries.
- **Landed in:** `Persona.md`, `Research.md`, `karen-desktop/src/brain/mod.rs`.
- **Adaptation:** Karen *is* an AI agent running locally. The principles of deterministic tool boundaries and progressive context disclosure are built directly into her execution loop.
- **Compliance:** [x] Tool execution acts through defined Rust functions [x] Persona enforces strict verification against hallucinations

## Open gaps (guides not yet applied)

- [ ] 8. E2E — Currently relies heavily on manual testing and verification; requires a mock STT/LLM environment to automate.
- [ ] 10. Deployment And Maintenance — No automated build/release pipeline yet for the Tauri binaries.

## Review cadence

- **Adapter version:** 0.1
- **Last synced:** 2026-10-09
