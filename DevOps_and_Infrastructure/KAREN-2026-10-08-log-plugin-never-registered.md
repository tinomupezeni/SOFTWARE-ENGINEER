# `tauri-plugin-log` was a declared dependency but never registered as a plugin - all logging was silently a no-op

**Date:** 2026-10-08
**Project:** KAREN (karen-desktop, Tauri 2 + React desktop voice-assistant widget)
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
`src-tauri/Cargo.toml` already listed `tauri-plugin-log = "2"` as a
dependency, and the codebase used `log::info!`/`log::error!`/`log::debug!`
throughout (shortcut registration, mic capture start/stop, stream errors).
None of it was ever visible, because the crate's logger was never installed
- `tauri_plugin_log::Builder` was never constructed or passed to
`.plugin(...)` in `lib.rs`. The Rust `log` crate is a facade: without an
installed logger, every `log::*!` call is silently dropped at the call
site. Separately, `app.global_shortcut().register(...)` errors were being
discarded with `let _ = ...`, so even a real registration failure (like the
Wayland one in the companion entry) would never have surfaced anywhere.

## Symptoms
- No log output at all from the Tauri backend, in any terminal, regardless
  of log level or build mode - not a filtering issue, nothing was ever
  emitted.
- This directly delayed diagnosing
  `Architecture_and_Design/KAREN-2026-10-08-global-shortcut-unsuited-to-wayland.md`:
  the shortcut-registration failure for that bug would have been invisible
  even after adding `log::error!` calls, if this gap hadn't been fixed in
  the same pass.

## Environment Details
- **Server/Host:** Local development machine only.
- **Services Affected:** All backend logging (`log::*!` call sites across
  `src-tauri/src/lib.rs`).
- **Related Components:** `src-tauri/Cargo.toml`, `src-tauri/src/lib.rs`.
- **Time First Observed:** 2026-10-08, while instrumenting the global
  shortcut handler to find out why registration appeared to silently do
  nothing.

## Investigation Steps

### 1. Initial Diagnosis
Added `log::error!` calls around `app.global_shortcut().register(...)` and
ran the app expecting to see output on registration failure - saw nothing
at all, success or failure.

### 2. Root Cause Analysis
Read `src-tauri/src/lib.rs`'s `tauri::Builder` chain top to bottom: no
`.plugin(tauri_plugin_log::Builder::...)` call existed anywhere, despite
the crate being a declared `Cargo.toml` dependency. The `log` crate
requires an explicit `log::set_logger` call (which `tauri_plugin_log`
performs when its plugin is registered) before any macro call does
anything; with no logger installed, every `log::info!`/`log::error!`/
`log::debug!` call is a no-op by design, not a bug in those call sites
themselves.

### 3. Key Findings
- The dependency being present in `Cargo.toml` without being wired into the
  `Builder` is exactly the kind of "looks configured, isn't" gap worth
  checking for on any new instrumentation pass - `cargo check` cannot catch
  it, since an unused dependency only warns if nothing in the crate
  references its types, and here `log::*!` macros compiled fine on their
  own regardless.
- `let _ = app.global_shortcut().register(...)` was independently
  discarding a `Result` that, per the companion entry, does carry a real,
  actionable error (`HotKey already registered`, or would carry a genuine
  platform failure) - fixed alongside the logger gap since both blocked
  the same diagnosis.

## Root Cause
A dependency was added to `Cargo.toml` in anticipation of using it, but the
actual `.plugin(...)` registration step was never completed - and nothing
in the build enforces that "declared in Cargo.toml" implies "wired into the
app."

## Prevention / Rule
**Guardrail:** When adding a Tauri plugin crate, the PR/commit that adds it
to `Cargo.toml` should include its `.plugin(...)` registration in the same
change - never split "add the dependency" from "use the dependency" across
sessions. A quick self-check: grep the plugin's crate name in `lib.rs`'s
`Builder` chain before considering the integration done.

This closes the gap directly: the failure mode here was exactly "declared
but not wired up," and requiring the registration in the same change
removes the window where that drift can happen.

## Solution

### Immediate Fix
Registered the plugin and set an explicit level filter:
```rust
.plugin(
    tauri_plugin_log::Builder::new()
        .level(log::LevelFilter::Debug)
        .build(),
)
```
Also replaced the silently-discarded shortcut-registration results with
explicit `log::error!` logging on failure.

### Long-term Fix
None needed beyond the fix above; this was a one-time wiring gap, not a
recurring pattern elsewhere in the codebase (only one `tauri::Builder`
chain exists in this project).

## Prevention
- [x] Code changes required (done this session)
- [ ] Monitoring/alerts to add (n/a - local dev logging only, no deployed
      service yet)

## Related Issues
- `Architecture_and_Design/KAREN-2026-10-08-global-shortcut-unsuited-to-wayland.md`
  (the bug this logging gap was initially hiding)

## References
- `tauri-plugin-log` v2 docs (`Builder::new().level(...).build()`)

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~5 minutes
