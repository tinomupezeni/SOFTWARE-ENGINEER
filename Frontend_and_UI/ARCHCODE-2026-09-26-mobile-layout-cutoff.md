# ArchCode narrow-window workspace unavailable below 1024px

**Date:** 2026-09-26
**Project:** ArchCode (pixel-perfect-replication scaffold)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
Below 1024px, ArchCode replaced its cockpit with a read-only problem brief and told users that Run and Submit required the full cockpit. This prevented tablet and mobile users from opening the editor or telemetry. A compact workspace now exposes Brief, Editor, and Telemetry views at narrower container widths.

## Symptoms
- Devices and windows below 1024px showed “ArchCode needs a window at least 1024px wide.”
- The user could read the exercise brief but could not access the editor or seeded telemetry views.

## Environment Details
- **Server/Host:** Local Vite development server
- **Services Affected:** ArchCode frontend
- **Related Components:** `src/routes/index.tsx`, responsive workspace and container-query gates
- **Time First Observed:** 2026-09-26

## Investigation Steps

### 1. Initial Diagnosis
Read the route layout and the current narrow-window fallback.

### 2. Root Cause Analysis
The route rendered the three-pane cockpit only when its container reached 1024px, and rendered a brief-only notice below that threshold. The size requirement was implemented as an explicit product gate.

### 3. Key Findings
- Scenario and editor state are already shared and can feed a compact layout.
- The collision timeline and EXPLAIN plan benefit from a horizontally scrollable canvas.
- A browser automation tool was unavailable in this environment.

## Root Cause
The responsive fallback was designed to remove the cockpit entirely below 1024px instead of adapting it for touch-sized screens.

## Prevention / Rule
**Guardrail:** Keep the narrow-container branch wired to the same editor, scenario, and telemetry state as the desktop cockpit.

This makes the responsive branch a functional workspace rather than a static brief and prevents the size warning from removing core surfaces.

## Solution

### Immediate Fix
Added a compact Brief / Editor / Telemetry navigation, reused existing app state, and gave telemetry a horizontally scrollable 760px content canvas.

### Long-term Fix
No additional long-term change was required for this scope.

## Prevention
- [x] Code changes required
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Related Issues
- [ARCHCODE-2026-09-26-narrow-window-state.md](../reports/ARCHCODE-2026-09-26-narrow-window-state.md)

## References
- `pixel-perfect-replication/src/routes/index.tsx`
- `WORKING-PROCESS.md`

---

**Resolved By:** Codex
**Time to Resolution:** One session
