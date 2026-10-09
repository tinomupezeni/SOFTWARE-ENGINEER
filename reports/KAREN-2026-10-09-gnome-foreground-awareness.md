# GNOME Foreground Awareness (Phase 5)

**Date:** 2026-10-09
**Project:** Karen
**Type:** Architecture Decision / Feature Implementation
**Status:** Completed

## Summary
Implemented Phase 5 of the Karen project, providing GNOME foreground application awareness to the context engine. This allows the LLM to use the active window as an additional signal for project-context reasoning.

## Context / Trigger
User requested an optional, minimal, read-only GNOME Shell extension to identify the current foreground application and improve project-context selection.

## Scope
Included:
- A GNOME Shell extension written in JS using standard GNOME APIs (version 50.1) exporting metadata via a session D-Bus interface.
- A Rust D-Bus client using `zbus` integrated into the `desktop_context.rs` module and `context_engine.rs`.
- System prompt updates in the LLM pipeline (`brain/mod.rs`) to process this signal securely.

Excluded:
- Automatic installation or enablement of the GNOME extension.
- Executing code based on untrusted window titles.

## Method
Developed the GNOME extension to capture `notify::focus-window` events and provide `wm_class` (app_id) and `title`. 
Connected via a `zbus` proxy on the Rust side, falling back gracefully if the D-Bus service is missing (failing closed safely).

## Decisions & Findings
- **D-Bus for IPC:** Selected session D-Bus for IPC as it natively isolates communication to the user's session without requiring open ports or complex authentication.
- **Untrusted Context:** Implemented prompt guidelines instructing the assistant not to use window titles as proof of context but as a hint, and strictly prohibiting file reads solely derived from window titles.

## Changes Made
- Created `gnome-extension/karen-context@karen.local/extension.js` and `metadata.json`.
- Updated `karen-desktop/src-tauri/src/desktop_context.rs` with `zbus` proxy code to fetch metadata.
- Updated `karen-desktop/src-tauri/src/context_engine.rs` to await the D-Bus context and include it in `ContextState`.
- Modified `karen-desktop/src-tauri/src/brain/mod.rs` to append the active window to the context string and update prompt instructions for project inference.

## Verification
- Rust builds successfully.
- Manual verification of failure modes (disconnected D-Bus, missing extension) gracefully ignores the active window context without panicking the system.

## Follow-ups / Deferred
- Testing across different GNOME versions (e.g., Wayland vs X11 behavior for `wm_class`).

## References
- `Phase5_Deliverable.md` in the Karen repo for detailed installation steps.

---

**Completed By:** Antigravity CLI
**Duration:** 1 session
