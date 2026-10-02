# Chat WebSocket hardcoded ws:// - blocked as mixed content on the live https:// site

**Date:** 2026-10-02
**Project:** tese-marketplace (BFF architecture, customer-store / admin-dashboard)
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
`ConversationContext.tsx`'s WebSocket fallback URL hardcoded `ws://`
unconditionally (`` `ws://${window.location.host}/api/chat/ws` ``), and
the subsequent "upgrade to wss:// if needed" check only ran when the URL
did *not* already start with `ws://` - so the hardcoded fallback bypassed
its own upgrade logic entirely. Since `VITE_WS_URL` is never actually
set in the real production build, this fallback is what the live
`https://tesemarket.com` site has always used, and the browser correctly
blocked it as mixed content. A real user hit this immediately after the
same-day buyer-seller messaging fix made `/messages` actually reachable
for the first time.

## Symptoms
- Browser console, pasted by a real user (Tino,
  mupezeni2001@gmail.com):
  ```
  Mixed Content: The page at 'https://tesemarket.com/messages' was
  loaded over HTTPS, but attempted to connect to the insecure WebSocket
  endpoint 'ws://tesemarket.com/api/chat/ws?token=...'. This request has
  been blocked; this endpoint must be available over WSS.
  Uncaught SecurityError: Failed to construct 'WebSocket': An insecure
  WebSocket connection may not be initiated from a page loaded over HTTPS.
  ```

## Environment Details
- **Server/Host:** Production (`tesemarket.com` and
  `admin.tesemarket.com`, both served over HTTPS)
- **Services Affected:** Real-time chat delivery (new messages wouldn't
  arrive without a manual refresh) in both `customer-store`'s
  `/messages` and `admin-dashboard`'s chat/support-ticket features
- **Related Components:**
  `apps/customer-store/src/features/messages/components/ConversationContext.tsx`,
  `apps/admin-dashboard/src/features/chat/hooks/useChat.ts`,
  `apps/admin-dashboard/src/hooks/useChatWebSocket.ts`
- **Time First Observed:** 2026-10-02 (though the underlying bug almost
  certainly predates this session - it's unconditional, not something
  introduced by the same-day messaging fixes)

## Investigation Steps

### 1. Initial Diagnosis
The error message named the exact failure mode and URL
(`ws://tesemarket.com/...`) - no ambiguity about what was wrong, only
where.

### 2. Root Cause Analysis
Read the WS URL construction in `ConversationContext.tsx`:
```ts
let wsUrl = import.meta.env.VITE_WS_URL || `ws://${window.location.host}/api/chat/ws`;
if (!wsUrl.startsWith("ws://") && !wsUrl.startsWith("wss://")) {
  const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
  wsUrl = `${protocol}//${wsUrl}`;
}
```
The fallback branch already produces a string starting with `ws://`, so
the upgrade check's condition is false and it never runs for the
fallback case - only for a hypothetical `VITE_WS_URL` set to a bare host
with no scheme. Confirmed `VITE_WS_URL` is never actually set anywhere
in the real deploy: `docker-compose.vps.yml` passes no `VITE_*` build
args for either frontend, and both Dockerfiles declare the `ARG`s with
no default values - meaning the fallback is unconditionally what
production has always run.

### 3. Key Findings
- Grepped both frontends for the same `ws://` literal pattern rather
  than assuming this was isolated to customer-store, and found the
  identical bug live in `admin-dashboard`'s `features/chat/hooks/useChat.ts`
  (used by `ChatPage.tsx`) - hardcoded in *both* its `VITE_WS_URL` and
  fallback branches, so it would always be wrong regardless of whether
  that env var was ever set.
- Also found it in `admin-dashboard`'s `hooks/useChatWebSocket.ts`
  (used by `SupportDashboard.tsx`), which additionally pointed at a
  stale `/api/messaging/ws` path - a leftover from before chat was
  consolidated into a single module (`/api/chat/ws` is the real route).
- `customer-store`'s own `src/hooks/useChatWebSocket.ts` has the exact
  same bug pattern but zero callers anywhere in the app - left alone as
  dead code, not an active issue.

## Root Cause
The fallback URL was written as a literal `ws://` string instead of
deriving its protocol from `window.location.protocol` the same way the
"upgrade" branch does - an oversight that made the upgrade logic
dead code for the one case (no env var set) that production actually
exercises.

## Prevention / Rule
**Guardrail:** Never hardcode `ws://` (or `http://`) as a literal in a
browser-side fallback URL - always derive the scheme from
`window.location.protocol` at the point the fallback is constructed,
not as a separate "fix it up afterward" step that can be bypassed by
how the literal was written in the first place.

## Solution

### Immediate Fix
```ts
// apps/customer-store/.../ConversationContext.tsx
const wsProtocol = window.location.protocol === "https:" ? "wss:" : "ws:";
let wsUrl = import.meta.env.VITE_WS_URL || `${wsProtocol}//${window.location.host}/api/chat/ws`;
if (!wsUrl.startsWith("ws://") && !wsUrl.startsWith("wss://")) {
  wsUrl = `${wsProtocol}//${wsUrl}`;
}
```
Applied the equivalent fix to `admin-dashboard`'s `useChat.ts` (both
branches) and `useChatWebSocket.ts` (also corrected its stale
`/api/messaging/ws` path to `/api/chat/ws`).

```bash
npx tsc --noEmit                      # clean, both apps
pnpm --filter customer-store build    # clean
pnpm --filter admin-dashboard build   # clean
```

Verified with a real headless-Chrome session against production
(injecting a real logged-in session into `localStorage`, same as
`authStorage` would): confirmed a `WebSocket` is created at
`wss://tesemarket.com/api/chat/ws?token=...` (correct scheme), stays
open with no `socketerror`/unexpected `close` events, and the browser
console shows no mixed-content or `SecurityError` messages - confirming
both the fix itself and that the `api-gateway` nginx container
correctly proxies the WebSocket upgrade.

### Long-term Fix
None needed - this closes the gap for every current WebSocket-URL
construction site in both apps.

## Prevention
- [x] Code changes required (done this session)

## Related Issues
- `Frontend_and_UI/tese-marketplace-2026-10-02-messages-double-api-prefix-404.md`
  (the fix immediately preceding this one, same feature, found by the
  same user testing the same page)

## References
- `apps/customer-store/src/features/messages/components/ConversationContext.tsx`
- `apps/admin-dashboard/src/features/chat/hooks/useChat.ts`
- `apps/admin-dashboard/src/hooks/useChatWebSocket.ts`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~20 minutes from report to verified fix in production
