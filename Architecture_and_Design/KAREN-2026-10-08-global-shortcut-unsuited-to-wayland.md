# Global wake/mute hotkeys silently failed to fire under GNOME Wayland

**Date:** 2026-10-08
**Project:** KAREN (karen-desktop, Tauri 2 + React desktop voice-assistant widget)
**Environment:** Development
**Severity:** Medium
**Status:** Workaround Applied

## Summary
Karen registers two OS-wide hotkeys (`Ctrl+Space` wake, `Ctrl+Alt+M` mic
toggle) via `tauri-plugin-global-shortcut`. The user reported "keybinds are
not working." The plugin's underlying `global-hotkey` crate only ships a
real backend for Windows, macOS, and **X11** - on Linux there is no
Wayland-native implementation at all. The user's session is GNOME on
Wayland, so the hotkeys registered successfully at the X11 level (via
XWayland) but the Mutter compositor only forwards key events into XWayland
when an XWayland-backed window currently has focus - which almost never
happens on a modern GNOME/Wayland desktop. The grabs were real but
functionally dead for most of the user's actual workflow.

## Symptoms
- User: "nope keybinds are not working" - `Ctrl+Space` and `Ctrl+Alt+M` had
  no visible effect on the Karen widget.
- No error was visible anywhere, because the registration call itself
  returns `Ok(())` - the failure mode is events never arriving, not a
  rejected registration.

## Environment Details
- **Server/Host:** User's desktop, Ubuntu, GNOME session.
- **Services Affected:** Karen's wake (`Ctrl+Space`) and mic-toggle
  (`Ctrl+Alt+M`) global shortcuts only.
- **Related Components:** `src-tauri/src/lib.rs`,
  `tauri-plugin-global-shortcut` (`global-hotkey` crate, v0.8.0).
- **Time First Observed:** 2026-10-08, first manual test of the shortcuts
  after they were wired up earlier the same session.

## Investigation Steps

### 1. Initial Diagnosis
Checked the session type directly, since global-hotkey implementations are
notoriously platform-specific on Linux:
```bash
echo "$XDG_SESSION_TYPE"   # wayland
loginctl show-session <id> -p Type   # Type=wayland
```

### 2. Root Cause Analysis
The existing code swallowed registration errors (`let _ =
app.global_shortcut().register(...)`), so there was no visibility into
whether registration itself had failed. Added explicit error logging and a
`tauri_plugin_log` sink (see companion entry
`DevOps_and_Infrastructure/KAREN-2026-10-08-log-plugin-never-registered.md`
for why logs weren't appearing at all before this), then ran the app:
```
[ERROR] failed to register Ctrl+Space shortcut: HotKey already registered: ...
```
That specific error only happens when a *previous* registration of the same
combo already succeeded - proving the X11 grab itself works. Read the
`global-hotkey` crate source directly:
```bash
find ~/.cargo/registry/src -iname "global-hotkey-*" -type d
cat .../global-hotkey-0.8.0/README.md
```
```
Platforms-supported:
- Windows
- macOS
- Linux (X11 Only)
```
`src/platform_impl/mod.rs` confirms there is no `cfg` branch for Wayland -
Linux always compiles the X11 backend (`x11rb` + `XGrabKey` against
whatever `DISPLAY` points at, i.e. XWayland here), falling back to a
no-op manager only on completely unsupported OSes.

### 3. Key Findings
- The grab succeeds against the X server, but Mutter (the Wayland
  compositor) only routes keyboard input into XWayland for XWayland-backed
  clients that currently have focus. A native-Wayland window (which is most
  GNOME apps today, including GNOME Terminal and Firefox under Wayland)
  never routes its keypresses through X11 at all, so the grab never sees
  them.
- This is a known, by-design limitation of `global-hotkey`/
  `tauri-plugin-global-shortcut` - there is no XDG Desktop Portal
  (`org.freedesktop.portal.GlobalShortcuts`) backend implemented as of
  v0.8.0, which is the actual Wayland-native mechanism GNOME 44+ supports
  for this.

## Root Cause
`tauri-plugin-global-shortcut` was used as if it provided true OS-wide
global hotkeys on Linux, but its only Linux backend is X11-based and does
not work reliably once the desktop session itself is Wayland-native - which
is now Ubuntu/GNOME's default. The library choice assumed a platform
guarantee (global, focus-independent key capture) that doesn't hold on the
target OS/session combination.

## Prevention / Rule
**Guardrail:** Before relying on any "global"/system-wide capability in a
cross-platform desktop crate, check its own platform-support table (not
just that it compiles) for the specific display-server/session-manager
combination the app will actually run under - Linux is not one platform
for this purpose; X11 and Wayland are different capability surfaces, and a
crate that says "Linux" without separately naming Wayland should be
assumed X11-only until proven otherwise.

This directly closes the gap here: the crate's own README states "Linux
(X11 Only)" in plain text - reading it before wiring up the feature would
have surfaced this immediately instead of after a confusing "it just
doesn't work" report.

## Solution

### Immediate Fix
Added an in-app clickable control (the orb itself) that calls a new
`toggle_mic_command` Tauri command directly - bypassing the OS shortcut
layer entirely for the primary interaction. The keyboard shortcuts are left
registered as a best-effort fallback (they do work when an XWayland window
has focus) but are no longer the only way to control listening state.

### Long-term Fix
If true hands-free, focus-independent activation is required later (e.g.
for a wake-word flow), the correct fix on Linux/Wayland is to call the
`org.freedesktop.portal.GlobalShortcuts` XDG portal directly (e.g. via the
`ashpd` crate) instead of `tauri-plugin-global-shortcut`, or to document
that Karen requires an X11 session (`Xorg` login option) for global-hotkey
activation. This was raised to the user as a decision point; not
implemented this session (button workaround chosen instead).

## Prevention
- [x] Code changes required (done this session - toggle button)
- [ ] Decide later whether to implement the GlobalShortcuts portal path for
      true Wayland-native global activation

## Related Issues
- `DevOps_and_Infrastructure/KAREN-2026-10-08-log-plugin-never-registered.md`
  (the logging gap that initially hid the registration error entirely)

## References
- `global-hotkey` crate README (v0.8.0): "Platforms-supported: Windows,
  macOS, Linux (X11 Only)"
- `global-hotkey-0.8.0/src/platform_impl/mod.rs`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~20 minutes from report to workaround
