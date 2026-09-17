# Login Button Hangs on Authentication Error

**Date:** 2026-09-16
**Project:** ZCHPC-ERP
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
When a user entered invalid credentials, the login button stayed in a disabled "Authenticating..." state and did not reset. This prevented users from correcting their credentials and retrying without manually refreshing the page.

## Symptoms
- The login form's submit button gets stuck displaying "Authenticating..." and stays disabled.
- No error toast is displayed after the first failed attempt, and subsequent attempts hang.

## Environment Details
- **Server/Host:** `erp-vm`
- **Services Affected:** `zchpc_frontend`
- **Related Components:** `apiClient.ts`
- **Time First Observed:** 2026-09-16

## Investigation Steps

### 1. Initial Diagnosis
Checked the `useLogin.ts` hook. The `handleLogin` function sets `isSubmitting = true` and wraps the login call in a `try...catch`. The `catch` block correctly calls `setIsSubmitting(false)`.

### 2. Root Cause Analysis
Checked the axios interceptor in `apiClient.ts`. When a 401 error is received:
- `isRefreshing` is set to `true`.
- The code checks if `refreshToken` exists in `localStorage`.
- If `refreshToken` does not exist (which is the case on the login page for an unauthenticated user, or after a failed login attempt), the interceptor returns `Promise.reject(error)` but **fails to reset `isRefreshing = false`**.

### 3. Key Findings
- On the first failed login attempt, the promise rejects, and the UI correctly catches it.
- However, `isRefreshing` remains `true` in module state.
- On the second failed login attempt, the interceptor sees `isRefreshing = true` and pushes the request promise into `failedQueue`.
- Since there is no actual token refresh in progress, `processQueue` is never called, and the promise remains unresolved forever.
- This causes the `await login()` call in `useLogin.ts` to hang indefinitely, keeping the button in the disabled state.

## Root Cause
The `apiClient.ts` axios interceptor left the global `isRefreshing` flag as `true` when rejecting a 401 response due to a missing refresh token. This caused subsequent requests to get indefinitely queued in the `failedQueue`.

## Prevention / Rule
**Guardrail:** Ensure stateful flags in interceptors (like `isRefreshing`) are always reset inside a `finally` block or explicitly before all `return` statements that exit the interceptor early.

Enforcing a `finally` block or pre-return cleanup for stateful axios interceptors prevents deadlocks where queued requests wait indefinitely for a signal that will never arrive.

## Solution

### Immediate Fix
Added `isRefreshing = false;` right before the early return inside the `!refreshToken` block in `apiClient.ts`.

```typescript
      const refreshToken = localStorage.getItem('refreshToken');
      if (!refreshToken) {
        isRefreshing = false;
        window.dispatchEvent(new Event('auth:logout'));
        return Promise.reject(error);
      }
```

### Long-term Fix
Refactor the interceptor to use a more robust locking mechanism or ensure all exit paths are covered by a `finally` block for the refresh process.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- N/A

## References
- Axios Interceptor concurrency issues

---

**Resolved By:** Antigravity
**Time to Resolution:** 10 minutes
