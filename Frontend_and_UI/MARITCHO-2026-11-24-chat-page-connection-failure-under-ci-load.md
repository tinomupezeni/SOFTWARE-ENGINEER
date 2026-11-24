# Lifecycle E2E chat page hits a real connection failure under CI load, intermittently failing on main

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
- Raising the timeout to 30s, then 60s, still didn't fix it on PR #14's CI
  run — same failure both times. That ruled out "just needs more time."
- Downloaded the failed run's `lifecycle-report` artifact
  (`gh run download <id> -n lifecycle-report`) and read the Playwright
  error-context snapshot for the failing assertion. It showed the
  browser's own **"This page couldn't load" / "Reload" / "Back"**
  interstitial — a genuine navigation/connection failure, not a chat
  screen that was merely slow to show "Connected." This was the actual
  root cause; the earlier timeout-based fixes were treating a symptom.
- This points to the single Next.js dev-ish production server (`next
  start`) occasionally refusing/dropping a connection when both browser
  contexts (buyer and worker) navigate around it concurrently under CI's
  constrained CPU, not a WebSocket-specific problem.
- The suite already has a helper, `untilAfterReload`, built for exactly
  this class of "needs a reload to recover" flake elsewhere in the same
  spec — the fix was to reuse that pattern instead of inventing a new one
  or keeps padding a timeout that was never the actual constraint.

## Root Cause
An occasional real connection failure navigating to the chat page under
CI's constrained CPU/concurrency (confirmed via the browser's own
error interstitial in the failure screenshot), not a slow WebSocket
handshake — so no timeout, however large, would have reliably fixed it.

## Prevention / Rule
**Guardrail:** before raising a timeout on a flaky E2E assertion a second
time, pull the failure's actual artifact (screenshot / error-context /
trace), not just the assertion's own timeout message — it can reveal the
page never got as far as the state you're waiting on. For "needs a reload
to recover" flakes specifically, reuse this suite's existing
`untilAfterReload` helper rather than adding a new one-off retry/timeout
pattern.

## Solution

### Immediate Fix
Raised the two `"Connected · messages arrive instantly"` assertions in
`job-lifecycle.spec.ts` from the default 10s to 30s (commit 65f2142), then
to 60s (commit 4898a4c) — neither fixed it, which is what prompted
downloading the artifact and finding the real cause. Switched both
assertions to `untilAfterReload` (commit b8e9b95), reloading until the
socket comes up instead of waiting once with a bigger number. Verified
locally against docker-compose: the full lifecycle suite passes
end-to-end.

### Long-term Fix
If this still flakes, the next step is reducing concurrent load on the
single `next start` dev server during this step (e.g. not having both
browser contexts navigate at the same moment) rather than adding more
retries.

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
- Commits 65f2142, 4898a4c, b8e9b95 on branch `experimental`

---

**Resolved By:** Claude Code (code review follow-up + fix)
**Time to Resolution:** Same session
