# RoleGate Silently Persists Server-Side Role Switch on Route Render

**Date:** 2026-11-18
**Project:** MARITCHO
**Environment:** Development (found in code review of PR #13, pre-merge)
**Severity:** High
**Status:** Resolved

## Summary
`RoleGate.tsx` fires a persisted server-side role switch (`PATCH /users/me`) as a side effect of merely rendering a route for the other role, with no user confirmation. For a dual-capability (buyer+worker) account, visiting a route gated for the role the account isn't currently active in flips the account's active role account-wide.

## Symptoms
- A dual-role account in WORKER mode opens a buyer-only link (bookmark, shared link, stale tab).
- `canActAs(user, role)` evaluates true, so `switchMode.mutateAsync({ role })` fires automatically.
- `current_user.role` is persisted as BUYER server-side via `update_users_me`, with zero explicit user intent — affecting navigation, notifications, and any other concurrent session/tab.

## Environment Details
- **Server/Host:** N/A (frontend component logic)
- **Services Affected:** Account role/mode switching, navigation, notifications
- **Related Components:** `frontend/src/features/accounts/RoleGate.tsx:37`, backend `update_users_me`
- **Time First Observed:** 2026-11-18, during code review of PR #13

## Investigation Steps

### 1. Initial Diagnosis
Code review flagged `RoleGate` calling a mutation during render-path role checks rather than performing a read-only capability check.

### 2. Root Cause Analysis
`RoleGate` conflates "can this account act as role X" (`canActAs`) with "should the account's active role now become X." It treats arriving at a route as implicit intent to switch modes, instead of requiring an explicit user action (e.g. a mode-switch button/confirmation).

### 3. Key Findings
- The switch mutation persists server-side, not just client-side UI state.
- It affects all other open sessions/tabs for the account, not just the current view.
- No confirmation step exists before the switch is committed.

## Root Cause
`RoleGate` uses a capability check (`canActAs`) to drive an irreversible, persisted side effect (mode switch) instead of gating a read-only render decision.

## Prevention / Rule
**Guardrail:** Code-review checklist item — any component that calls a mutation (not a query) from inside a route guard/render path must be flagged and rejected; mutations triggered by navigation require an explicit confirmation step or must be moved out of the render path entirely.

This directly closes the gap: the bug exists because a mutation was allowed to run as a side effect of rendering, which a render-path-mutation check would catch before merge.

## Solution

### Immediate Fix
`RoleGate` no longer calls `switchMode.mutateAsync` automatically from the render-path effect. It now shows a confirmation `Sheet` ("Switch mode?") when the account could switch into the gated role, and only calls the mutation when the person taps "Switch mode"; "Not now" routes them to their current side's home screen instead.

### Long-term Fix
Done — see Immediate Fix.

## Prevention
- [ ] Code changes required (remove implicit mutation from RoleGate; add explicit confirmation flow)
- [ ] Documentation to update (dual-role UX expectations)

## Related Issues
- Related to [[maritcho-2026-11-18-job-party-active-role-vs-capability]] — same PR's broader active-role-vs-capability inconsistency.

## References
- PR #13 (Maritcho, `experimental` -> `main`)

---

**Resolved By:** Pending
**Time to Resolution:** N/A
