# Every chat API call 404'd due to a doubled "/api" prefix

**Date:** 2026-10-02
**Project:** tese-marketplace (BFF architecture, customer-store)
**Environment:** Production
**Severity:** Critical
**Status:** Resolved

## Summary
`messageServices.tsx` imported `BASE_URL` ("/api") and manually
prepended it to every chat endpoint path (`ENDPOINT_BASE = BASE_URL +
"/chat"`), then called `axiosInstance` - which already has `baseURL:
BASE_URL` configured. Every request became `/api/api/chat/...` and
404'd unconditionally. The user tested the real `/messages` page
immediately after the buyer-seller direct-messaging fix shipped and hit
this on every single action (loading conversations, starting a new one,
sending a message).

## Symptoms
- Browser console, pasted by the user:
  ```
  GET api/api/chat/conversations 404
  Failed to fetch conversations ApiError: Request failed with status code 404
  POST api/api/chat/conversations 404
  Failed to create support ticket ApiError: Request failed with status code 404
  Failed to start product inquiry ApiError: Request failed with status code 404
  ```

## Environment Details
- **Server/Host:** Production (`tesemarket.com`, `tese-customer-store`
  container)
- **Services Affected:** The entire `/messages` feature - every chat
  API call, with no exception
- **Related Components:**
  `apps/customer-store/src/features/messages/services/messageServices.tsx`
- **Time First Observed:** 2026-10-02, immediately after the same-day
  buyer-seller direct messaging fix was deployed

## Investigation Steps

### 1. Initial Diagnosis
The failing URL in the user's console output (`api/api/chat/conversations`)
named the bug almost on its own - a doubled path segment.

### 2. Root Cause Analysis
Fetched the actual deployed JS bundle and grepped the minified source
directly rather than guessing from the unminified code:
```bash
grep -o 'je=qe\.create({baseURL:ar' bundle.js   # axiosInstance's own baseURL
grep -o '[a-zA-Z_$]*="/api"' bundle.js          # confirms BASE_URL compiled to "/api"
grep -o 'yl=[a-zA-Z_$.]*+"/chat"' bundle.js     # confirms messageServices re-prepends it
```
Confirmed: `axiosInstance` is created with `baseURL: "/api"` (`VITE_API_URL`
isn't set at this build's build-args, falling back to the relative
default). `messageServices.tsx` then builds its own
`ENDPOINT_BASE = BASE_URL + "/chat"` ("/api/chat") and passes that
relative path into calls already going through an instance whose
`baseURL` is also "/api" - axios concatenates a relative `url` onto
`baseURL`, producing the doubled path.

### 3. Key Findings
- This explains why the buyer-seller routing fix shipped earlier the
  same session appeared to "not work" when the user actually tried it -
  my own verification of that fix used `curl` directly against the
  backend API, which bypasses the frontend's URL construction entirely.
  The bug was real and present the whole time; it just wasn't visible
  from a backend-only test.
- Found the identical pattern in `src/core/api/userService.tsx`
  (`updateUserProfile`/`getUserProfile`, both manually prefixing
  `BASE_URL` the same way) - left unfixed since `grep` confirmed zero
  callers anywhere in the app; noted as a future cleanup, not an active
  bug.
- Every other service in the app calls `axiosInstance` with a bare
  relative path (e.g. `axiosInstance.post("/auth/applications", ...)`),
  confirming `messageServices.tsx` was the outlier, not the convention.

## Root Cause
`messageServices.tsx` duplicated a path prefix that `axiosInstance`
already applies via its own `baseURL` configuration - a copy-paste-style
inconsistency with the rest of the codebase's service files, never
caught before because, per the companion report, this was very likely
the first time the messaging feature was exercised through the real
frontend rather than tested against the backend directly.

## Prevention / Rule
**Guardrail:** Never import `BASE_URL` directly in a service file that
also uses the shared `axiosInstance` - `axiosInstance`'s `baseURL`
already supplies it. Any `axiosInstance.<verb>(\`${BASE_URL}...\`)` call
pattern found anywhere in the codebase is this exact bug; a grep for
`BASE_URL` imports alongside `axiosInstance` usage (as done here) is the
direct way to find every instance of it.
**Verification rule:** A fix to a feature's request-path behavior isn't
verified until it's exercised through the actual deployed frontend
(real browser, real bundle) - testing the backend alone, even
end-to-end with curl, cannot catch a client-side URL construction bug.

## Solution

### Immediate Fix
```ts
// apps/customer-store/src/features/messages/services/messageServices.tsx
// Before:
import { BASE_URL } from "../../../core/api/api";
const ENDPOINT_BASE = BASE_URL + "/chat";
// After:
const ENDPOINT_BASE = "/chat"; // relative to axiosInstance's own baseURL
```

```bash
npx tsc --noEmit                     # clean
pnpm --filter customer-store build   # clean production build
```

Verified this time via an actual headless-Chrome session (not curl):
injected a real logged-in session into `localStorage` the same way
`authStorage` does, navigated to `/messages`, and confirmed zero failed
network requests and zero console errors while the conversation list
correctly loaded and displayed the real seller's name ("Engine
Consolidation Test Farm") instead of 404ing.

### Long-term Fix
Fix (or remove, if still unused) `userService.tsx`'s identical pattern
in a future pass.

## Prevention
- [x] Code changes required (done this session)
- [ ] Audit `userService.tsx` for removal or fix

## Related Issues
- `Frontend_and_UI/tese-marketplace-2026-10-02-messages-hardcoded-to-tese-support-only.md`
  (the fix this bug was discovered immediately after testing)

## References
- `apps/customer-store/src/features/messages/services/messageServices.tsx`
- `apps/customer-store/src/core/api/userService.tsx` (same bug, dead code)

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~15 minutes from report to verified fix in production
