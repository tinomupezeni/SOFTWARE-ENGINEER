# GNOME Wayland Perception Design and Portal Limitations

**Date:** 2026-10-09
**Project:** Karen
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
In Stage 4 of Phase 2, the goal was to implement a Permission-Aware Desktop Perception layer for the Karen voice assistant on Ubuntu 26.04 (GNOME 50.1 Wayland). During the investigation of available desktop APIs to capture screen context and active foreground-window metadata, we encountered strict security limitations in GNOME Wayland that require careful architectural choices.

## Symptoms
- DBus interfaces like `org.gnome.Shell.Introspect` are restricted or missing entirely on modern GNOME Wayland.
- Standard accessibility buses (AT-SPI) do not reliably expose the active/foreground window class or title without an explicit extension to bridge the Wayland compositor state.
- Screen capture requires an explicit user-interactive portal (`org.freedesktop.portal.Screenshot`) rather than silent programmatic access.

## Environment Details
- **Server/Host:** Ubuntu 26.04.1 LTS (Resolute Raccoon)
- **Services Affected:** Desktop Perception Layer (`src/desktop_context.rs`)
- **Related Components:** Wayland, GNOME Shell 50.1, xdg-desktop-portal
- **Time First Observed:** 2026-10-09

## Investigation Steps

### 1. Initial Diagnosis
Checked Wayland and GNOME versions:
```bash
cat /etc/os-release
echo $XDG_SESSION_TYPE
gnome-shell --version
```
Verified that the session was running Wayland.

### 2. Root Cause Analysis
Investigated the availability of `xdg-desktop-portal` and AT-SPI on the user DBus session:
```bash
busctl --user list | grep portal
busctl --user introspect org.gnome.Shell /org/gnome/Shell
```
Found that `org.freedesktop.portal.Screenshot` is available and functioning, allowing interactive screenshots. However, `org.gnome.Shell` lacks an exposed introspection or window-list API, meaning `wayland-0` isolates window data by design.

### 3. Key Findings
- `org.freedesktop.portal.Screenshot` safely allows user-consented desktop capture and is the standard way to retrieve images. We successfully integrated it using the `ashpd` Rust crate.
- LLM vision APIs (Groq Vision) will be used to extract text and analyze the screenshot locally/remotely instead of installing heavy local OCR dependencies like Tesseract (which require sudo/root).
- **Foreground window awareness cannot be cleanly implemented without a GNOME Shell Extension**, as Wayland inherently prevents clients from knowing about other clients.

## Root Cause
Wayland's security model strictly sandboxes applications, preventing any client from querying global window states or capturing the screen silently. 

## Prevention / Rule
**Guardrail:** Use `xdg-desktop-portal` (`ashpd` crate) for all Wayland screen captures, and NEVER attempt to bypass portal security prompts by querying `/dev/fb0` or attempting X11 fallback mechanisms on Wayland sessions.

This ensures the user remains explicitly in control of what visual context the AI assistant observes, respecting the sovereign computing philosophy.

## Solution

### Immediate Fix
- Implemented `DesktopContext` service via `ashpd` to request screenshots interactively through the Wayland portal.
- Hooked `capture_desktop_context` into the LLM's tool registry.
- Documented that foreground window metadata requires further permissions.

### Long-term Fix
**Recommendation on GNOME Extension:** A minimal GNOME Shell extension is **justified and necessary** for the next stage if active-window metadata is required. Since Wayland deliberately obscures this, an extension that reads the Mutter window manager state and exposes only the active window title/class via a secure, unprivileged DBus endpoint is the only architecturally sound workaround.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## References
- xdg-desktop-portal documentation
- ashpd Rust crate
- GNOME Shell Wayland architecture

---

**Resolved By:** Antigravity
**Time to Resolution:** 20 minutes
