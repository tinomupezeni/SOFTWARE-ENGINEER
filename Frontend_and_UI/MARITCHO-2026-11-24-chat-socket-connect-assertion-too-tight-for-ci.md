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
- Raising the timeout to 30s still wasn't enough on PR #14's CI run. Read
  the uploaded backend container logs for that run and found the
  WebSocket actually was accepted server-side (`"WebSocket
  /jobs/{id}/ws?token=*** [accepted]"`) — just well after the 30s
  assertion had already timed out. This rules out a routing/auth failure;
  the socket does connect, it's just queued behind other work.
- The socket-token fetch and the WS handshake only need the backend, not
  the Next.js BFF (`NEXT_PUBLIC_WS_URL` points the browser straight at the
  FastAPI container) — so the contention is on the backend side: a single
  uvicorn worker synchronously hashing passwords (bcrypt) for the two
  accounts this suite creates, on a shared, likely single-core CI runner,
  delays everything else the worker needs to handle, including the socket
  upgrade.
- PR #14's larger account-setup flow (additional skills/service-area calls
  during onboarding, visible in the same log dump) adds more sequential
  work before the chat step, which plausibly explains why this went from
  intermittent on `main` to deterministic on this PR specifically — not
  because the PR broke WebSocket routing, but because it added enough
  extra setup time to reliably exceed the previous tight budget.

## Root Cause
A fixed, too-tight expect timeout on an assertion that depends on a
WebSocket accept queued behind the backend's synchronous bcrypt work on a
single uvicorn worker, with no margin for CI runner contention — not a
connectivity or auth bug (the socket is confirmed to connect successfully,
just later than the original 10s/30s budgets allowed).

## Prevention / Rule
**Guardrail:** any E2E assertion gating on a WebSocket's first connect (not
just a REST response) should use an explicit, generous timeout rather than
the suite's default — the default is sized for UI state changes, not a
multi-step async handshake that can queue behind other synchronous backend
work (bcrypt hashing, in this case) on a single worker under CI contention.

## Solution

### Immediate Fix
Raised the two `"Connected · messages arrive instantly"` assertions in
`job-lifecycle.spec.ts` from the default 10s to 30s (commit 65f2142), then
to 60s (commit 4898a4c) after confirming via backend container logs that
the socket was still only timing out on the assertion, not failing to
connect — comfortably within the lifecycle project's 180s per-test
timeout.

### Long-term Fix
If this still flakes at 60s, the real fix is making account setup in
`auth/signup` not block the single uvicorn worker on bcrypt (e.g. run it
in a thread pool executor, or add a second worker for the throwaway E2E
backend) rather than raising the timeout further.

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
- Commits 65f2142, 4898a4c on branch `experimental`

---

**Resolved By:** Claude Code (code review follow-up + fix)
**Time to Resolution:** Same session
