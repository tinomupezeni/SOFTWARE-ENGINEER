# Lifecycle E2E chat-connect assertion too tight for CI, intermittently failing on main

**Date:** 2026-11-24
**Project:** MARITCHO
**Environment:** CI (GitHub Actions, `ubuntu-latest`)
**Severity:** Medium
**Status:** Resolved

## Summary
`e2e/lifecycle/job-lifecycle.spec.ts`'s "both sides chat live" step asserts
`"Connected · messages arrive instantly"` becomes visible using Playwright's
default 10s expect timeout. That text only appears once `useChatSocket`'s
WebSocket has fetched a socket token, opened, and been authenticated by the
backend — racing a cold, just-built (`next build && next start`) production
server on a shared CI runner. This was already causing intermittent
failures on `main` before PR #14 (confirmed via `gh run list` history going
back to 2026-11-16), and failed deterministically (both the initial run and
its retry) on PR #14's CI.

## Symptoms
- `Job lifecycle against docker-compose backend` CI check fails with:
  `Error: expect(locator).toBeVisible() failed — Locator:
  getByText('Connected · messages arrive instantly') — Timeout: 10000ms`
- Confirmed the identical failure (same locator, same line) on `main` CI
  runs from 2026-11-16 through 2026-11-18, well before this session or
  PR #14 existed.
- Not consistently failing on `main` historically (some runs passed), but
  consistently failing (2/2 attempts) on PR #14's CI run on 2026-11-24.

## Environment Details
- **Server/Host:** GitHub Actions, `ubuntu-latest` runner (not containerized
  for this job, unlike the `visual` job)
- **Services Affected:** `Job lifecycle against docker-compose backend` CI
  check
- **Related Components:** `frontend/e2e/lifecycle/job-lifecycle.spec.ts`,
  `frontend/src/features/messaging/hooks.ts` (`useChatSocket`)
- **Time First Observed:** Pre-existing since at least 2026-11-16; escalated
  to deterministic failure on PR #14 (2026-11-24)

## Investigation Steps

### 1. Initial Diagnosis
PR #14's CI run failed on this exact assertion on both its first attempt
and its automatic retry (`retries: 1` in `playwright.config.ts`), which
ruled out a one-off scheduling fluke.

### 2. Root Cause Analysis
Checked `gh run list --workflow=frontend-e2e.yml --branch main` and found
the same `lifecycle` job already failing on the identical locator/line on
multiple `main` runs well before PR #14, confirming this predates the PR.
Read `useChatSocket` in `hooks.ts`: the "Connected" state only flips to
`true` in `onopen`, after an async `fetch("/api/session/socket-token")`
plus a full WebSocket handshake and backend auth — several round trips
against a server that just finished a cold `next build` moments earlier,
on a runner with no guaranteed CPU headroom.

### 3. Key Findings
- This is not caused by PR #14's feature work (pricing modes, GPS location,
  vetting) directly, but the app has grown since the last time this was
  reliably passing, plausibly pushing an already-marginal timing budget
  over the edge more often.
- The lifecycle suite already uses a 180s overall test timeout and a
  `untilAfterReload` helper elsewhere for similarly slow-to-settle UI, so
  a generous explicit timeout on this one assertion is consistent with how
  the rest of the suite already handles CI-speed variance.

## Root Cause
A fixed 10s expect timeout on an assertion that depends on a full
WebSocket connect-and-auth round trip against a cold production server,
with no margin for CI runner variance.

## Prevention / Rule
**Guardrail:** any E2E assertion gating on a WebSocket's first connect (not
just a REST response) should use an explicit, generous timeout rather than
the suite's default — the default is sized for UI state changes, not a
multi-step async handshake against a freshly started server.

## Solution

### Immediate Fix
Raised the two `"Connected · messages arrive instantly"` assertions in
`job-lifecycle.spec.ts` from the default 10s to an explicit 30s timeout.

### Long-term Fix
If this still flakes at 30s, the next step would be instrumenting
`useChatSocket`'s connect path with timing (or pre-warming the Next.js
server with a request before the suite starts) rather than raising the
timeout further.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (done, commit 65f2142 on branch `experimental`)

## Related Issues
- GitHub PR Rest-creator/MARITCHO#14
- `main` CI runs 44261099891, 44254210037, 44114967644, 43937050988 (and
  others) show the same pre-existing failure

## References
- Commit 65f2142 on branch `experimental`

---

**Resolved By:** Claude Code (code review follow-up + fix)
**Time to Resolution:** Same session
