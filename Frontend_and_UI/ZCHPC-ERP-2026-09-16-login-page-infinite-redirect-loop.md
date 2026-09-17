# Login Page Infinite Redirect Loop

**Date:** 2026-09-16
**Project:** ZCHPC-ERP
**Environment:** Production
**Severity:** Critical
**Status:** Resolved

## Summary
The login page for the ERP portal (ZCHPC-ERP) entered an infinite redirect loop. The application attempted to redirect the user to `/login` repeatedly when checking authentication status without verifying if the user was already on the login page.

## Symptoms
- The login page auto-refreshed very quickly.
- No user error was displayed, and the page flashed repeatedly.
- The browser developer console was inaccessible due to rapid reloads.

## Environment Details
- **Server/Host:** `erp-vm`
- **Services Affected:** `zchpc_portal` / Frontend Application
- **Related Components:** `AuthContext.tsx`, `auth.services.tsx`
- **Time First Observed:** 2026-09-16

## Investigation Steps

### 1. Initial Diagnosis
Searched the codebase for the login text ("Welcome Back") to identify the exact page being rendered (`zchpc-erp-synergy-main/src/pages/LoginPage.tsx`).

### 2. Root Cause Analysis
Checked the `AuthContext.tsx` where global authentication status is managed. The `logout()` function performed `window.location.href = "/login";`.

### 3. Key Findings
- In `useEffect()`, the `checkAuthStatus()` function tries to fetch the user profile if a token exists in local storage.
- If the token was invalid or an error occurred during profile fetch, it fell back to calling `logout()`.
- Since `logout()` unconditionally reassigned `window.location.href`, if an unauthenticated user or an invalid token state hit the login page, it forced a hard reload back to the same page, restarting the loop.

## Root Cause
The global `logout()` function performed a hard redirect (`window.location.href = "/login"`) without first checking if the current route was already `/login`, causing an infinite page reload loop if the logout condition was repeatedly met while on the login page.

## Prevention / Rule
**Guardrail:** Enforce a navigation check `if (window.location.pathname !== "/login")` inside global logout utilities that utilize direct `window.location.href` modifications.

Adding this check explicitly avoids recursive redirects to the same page which can trap users when an unexpected authentication error or expired token triggers a logout hook on the login page itself.

## Solution

### Immediate Fix
Updated `logout` inside `AuthContext.tsx` to conditionally redirect to `/login` only if the application is not already on that path.

```typescript
  const logout = () => {
    authService.clearTokens();
    setUser(null);
    if (window.location.pathname !== "/login") {
      window.location.href = "/login";
    }
  };
```

### Long-term Fix
Adopt a declarative routing approach for handling unauthenticated states instead of hard modifying `window.location.href`.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- N/A

## References
- React Context Authentication Best Practices

---

**Resolved By:** Antigravity
**Time to Resolution:** 10 minutes
