# Sign-out left the address bar stuck at the old URL (Node-version-dependent race)

**Date:** 2026-11-25
**Project:** ZIMPHOS
**Environment:** Real bug in app code, surfaced as a CI-only test failure (Node 24); not reproducible on local dev (Node 22)
**Severity:** High (real user-facing bug, not just a test artifact)
**Status:** Resolved

## Summary
`SignOutButton` navigated to `/` from the logout mutation's `onSettled`
callback. But the mutation's own `onSuccess` already awaits
`resetSession()`, whose `queryClient.resetQueries()` makes `/me` re-fetch
and `RoleGate` swap the whole authenticated tree out for `<SignedOut/>` —
unmounting the button — *before* `onSettled` runs. Whether the now-late
`navigate('/')` call still won against that swap depended on JS engine/
scheduling: it reliably won on local Node 22, and reliably lost on CI's
Node 24, so every real user hitting this on whatever Node version their
bundler/SSR ran under (irrelevant here, it's client-side, but the same
class of timing bug could resurface anywhere this pattern — navigate from
a callback whose owning component's continued existence isn't guaranteed)
would see the address bar (and, if anything read location, the UI) stuck
on the page they signed out from instead of landing on the sign-in screen
at a clean `/`.

## Symptoms
A test (`RoleGate.test.tsx`, "sign out goes back to the start...")
consistently failed in CI (3/3 real runs) and consistently passed locally
(9+ runs on Node 22), each time with:
```
Error: expect(element).toHaveTextContent()
Expected: /^\/$/
Received: /statement/1/2026-10
```
First suspected as "CI is just slower" (bumped the test's `waitFor`
timeout 3s → 8s); still failed identically at 8s, which ruled that out —
a real timeout difference would eventually pass with enough margin, not
fail at the same spot regardless of how long it waits.

## Investigation Steps

### 1. Initial Diagnosis
Confirmed deterministic, not probabilistic, by running the same CI job
three times: always this exact assertion, never a different one.

### 2. Root Cause Analysis
Reproduced locally inside a Node 24 Docker container (`docker run --rm -v
"$PWD":/repo -w /repo/frontend node:24 sh -c "npx vitest run --coverage
src/app/RoleGate.test.tsx"`) — failed every time, matching CI exactly,
while the same file on host Node 22 passed every time. That pointed at a
genuine Node-version-sensitive race rather than CI infrastructure
flakiness, so the next step was reading `SignOutButton.tsx` and
`useAuth.ts`'s `useLogout()` directly rather than re-running more tests:
```tsx
// SignOutButton.tsx (before)
onClick={() => logout.mutate(undefined, { onSettled: () => void navigate('/', { replace: true }) })}

// useAuth.ts
export function useLogout() {
  return useMutation({
    mutationFn: () => apiPostEmpty<void>('/logout'),
    onSuccess: () => resetSession(queryClient),   // awaited before onSettled runs
  })
}
```
`resetSession()` calls `queryClient.resetQueries()`, which re-fetches
`/me` (now 401) and causes `RoleGate` to render `<SignedOut/>` in place of
the authenticated shell — unmounting `SignOutButton` — all *before*
`onSettled`'s deferred `navigate('/')` call ever runs.

### 3. Key Findings
- The mock-mode branch of the exact same component already called
  `navigate('/')` synchronously in the click handler, not from any
  mutation callback — the asymmetry between the two branches was itself
  a signal that the real branch's approach was the odd one out.
- A tempting first fix (call `navigate('/')` synchronously before
  `logout.mutate()`, mirroring the mock branch) made the originally-failing
  test pass but broke a *different* one: navigating to `/` while the
  session is still technically valid (the mutation hasn't resolved yet)
  let an authenticated-role home-page redirect fire first, landing on
  e.g. `/today` instead of `/`, with nothing to subsequently correct the
  path back to `/` once sign-out actually completed.

## Root Cause
Navigating from a callback whose owning component is not guaranteed to
still be mounted when that callback actually runs — a React/async
ordering bug, not a test issue. `--coverage` instrumentation (and Node
24's scheduling) happened to make the "component already unmounted before
onSettled" ordering the reliable one; Node 22 locally happened to make the
opposite ordering reliable. Neither ordering is something application code
should depend on.

## Prevention / Rule
**Guardrail:** when a side effect (navigation, a toast, anything keyed to
"we are now in state X") needs to happen *because* a component rendered,
trigger it from that component's own effect, not from an imperative
callback fired by whatever caused the state transition. `SignedOut`'s own
`useEffect` only runs once `<SignedOut/>` is actually on screen — there is
no unmount race left to lose, by construction. Code review for any
`navigate()`/`toast()`/similar call inside a `mutate(...)` callback should
ask: "is the component that registered this callback guaranteed to still
exist when it fires?" — if the answer depends on another async chain
(like a query invalidation) racing it, move the effect to the component
that actually represents the target state instead.

## Solution

### Immediate Fix
Removed `navigate()` entirely from `SignOutButton` (both branches no
longer need it). Added to `SignedOut`:
```tsx
useEffect(() => {
  navigate('/', { replace: true })
}, [])
```
This only runs once `SignedOut` is genuinely rendered — regardless of why
(real sign-out, session expiry, a 403 mid-session) — which also made the
fix more correct than the original "only sign-out resets the path"
behavior, consistent with the component's own existing comment ("next
person opens on their own home screen, not this one").

### Verification
- `vitest run --coverage` of the affected files, repeated 10+ times on
  host Node 22: zero failures (previously would occasionally need the
  fix to not regress other tests, like the home-redirect one above).
- Directly inside a Node 24 Docker container (matching CI exactly): zero
  failures, where the pre-fix code failed 3/3.
- Full suite (280 tests): passes.
