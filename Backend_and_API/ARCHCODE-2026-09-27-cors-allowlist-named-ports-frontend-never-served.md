# CORS allowlist named ports the frontend does not serve from

**Date:** 2026-09-27
**Project:** ArchCode
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
`api/app.py` allowed `http://localhost:{5173,3000}`. Neither port is used by anything. The
frontend dev server runs on **8080**, pinned with `strictPort` by the vendored
`@lovable.dev/vite-tanstack-config`, so the allowlist rejected the only origin that exists while
looking entirely reasonable. Found while auditing frontend-to-backend wiring; the two sides had
never been run against each other, so the mismatch had no way to surface.

## Symptoms
No error anywhere. A browser `fetch` from `http://localhost:8080` to the API fails with:

```
Access to fetch at 'http://127.0.0.1:8000/healthz' from origin
'http://localhost:8080' has been blocked by CORS policy: No 'Access-Control-Allow-Origin'
header is present on the requested resource.
```

Indistinguishable, from the browser console, from the API being down.

## Environment Details
- **Server/Host:** local dev
- **Services Affected:** FastAPI runner API (all cross-origin callers)
- **Related Components:** `runner/api/app.py`, `runner/archcode/settings.py`,
  `@lovable.dev/vite-tanstack-config`
- **Time First Observed:** 2026-09-27, during a frontend-to-backend wiring audit

## Investigation Steps

### 1. Initial Diagnosis
The allowlist looked defensible: two ports, both localhost, both common. Nothing about it reads as
a placeholder, which is why it survived review and CI.

### 2. Root Cause Analysis
The port was assumed rather than read. The frontend never used a Vite default:

- `vite.config.ts` sets no port at all — the port comes from the vendored shared config
  `node_modules/@lovable.dev/vite-tanstack-config/dist/index.js`, which pins
  `{ host: "::", port: 8080, strictPort: true }` for the sandbox branch and `8080` otherwise.
- `strictPort: true` means the dev server will not fall back to the next free port, so 8080 is
  not merely the default — it is the *only* port that ever serves.
- 5173 is Vite's stock default, which this project overrides. 3000 appears in two stale frontend
  locations: `scripts/capture.mjs:24` (screenshot target) and
  `src/integrations/supabase/previewAuthStorage.ts:24,29` (cookie-domain allowlist).

So **every** entry in the allowlist was a phantom origin, and the real one was absent. The list was
inverted relative to reality.

### 3. Key Findings
- An allowlist is a positive assertion: every entry should be a port something actually serves.
  A list of plausible-but-wrong origins is worse than an empty one, because it reads as
  deliberate.
- The failure was invisible without a browser. HTTP and the test suite both pass, since neither
  sends an `Origin` header. This is the same shape as the `ATTEMPT_BUDGET_MS` `LazySettings`
  defect: the code path that only executes under the real caller is the code path nobody tests.
- Two independent stale references to port 3000 in the frontend suggest 3000 was once real and
  was never cleaned up when the sandbox port changed.

## Root Cause
The frontend's dev-server port was assumed to be a common default instead of read from the
vendored config that actually sets it, and the assumption was never tested against a browser
origin.

## Prevention / Rule
**Guardrail:** Any cross-origin allowlist must be verified by issuing a real preflight with an
`Origin` header, against the port the client actually listens on. CORS is enforced only by
browsers, so HTTP-level tests and the test suite cannot catch it.

Origins are now `settings.CORS_ORIGINS` rather than a literal in `app.py`, so a port change is an
environment variable rather than a code change. Three tests cover it, including a
refuses-an-unlisted-origin case — without that one the positive test would pass just as well
under `allow_origins=["*"]`.

## Solution

### Immediate Fix
```python
cors_origins: list[str] = [
    "http://localhost:8080",
    "http://127.0.0.1:8080",
]
```
read via `allow_origins=list(dj_settings.CORS_ORIGINS)`.

### Long-term Fix
Regression tests in `tests/test_api.py`:
`test_cors_allows_the_origin_the_frontend_actually_serves_from`,
`test_cors_refuses_an_unlisted_origin`, and
`test_cors_allowlist_comes_from_settings_not_a_literal`.

## Prevention
- [x] Real dev origin (8080) allowed, verified by live preflight
- [x] Phantom origins 5173 and 3000 now refused
- [x] Allowlist promoted to settings
- [x] Positive and negative tests added
- [x] Full containerised stack re-verified after the change
- [ ] Add a browser-origin preflight to CI once CI exists
- [ ] Clean up the two stale port-3000 references in the frontend

## References
- `reports/ARCHCODE-2026-09-27-runner-stack-and-repository.md`
- Vite `strictPort` semantics: the dev server fails rather than incrementing the port

---

**Resolved By:** Claude (opencode)
**Time to Resolution:** ~20 minutes
