# Empty State UX Confusion and Aggressive Browser Caching on Data Intelligence Studio

**Date:** 2026-10-09
**Project:** TESC
**Environment:** Staging
**Severity:** Medium
**Status:** Resolved

## Summary
The user reported that the Data Intelligence Studio page was showing "nothing here" after a recent deployment. Two issues were occurring simultaneously: first, the user's browser was heavily caching the `index.html` file, masking the fact that the staging server had actually been successfully deployed. Second, once the cache was cleared, the UI hid all "Combine Metrics" and "Dimensions & Grouping" fields behind a strictly empty `Select source...` dropdown state, leading the user to believe the features had been removed entirely.

## Symptoms
- User unable to see deployed changes after container recreation (Browser returning 304 Not Modified).
- After hard refresh, the Data Intelligence Studio showed only "Select source..." and "Data Filters", with all metric and dimension builders hidden.
- User perceived the redesign as a total removal of functionality.

## Environment Details
- **Server/Host:** `tesc-staging`
- **Services Affected:** `frontend_client`, Nginx Reverse Proxy
- **Related Components:** `DataIntelligenceStudio.tsx`
- **Time First Observed:** 2026-10-09

## Investigation Steps

### 1. Initial Diagnosis
- Checked local repository to verify if frontend configuration was cached.
- Confirmed staging Nginx logs were returning `304 Not Modified` for `/studio` and frontend assets.
- Inspected the `DataIntelligenceStudio.tsx` component and verified `Combine Metrics` and `Dimensions & Grouping` were conditionally rendered behind `currentSource`.

### 2. Root Cause Analysis
- **Caching:** The frontend's internal Nginx `default.conf` had no `Cache-Control` header for the default `/` location, causing browsers to aggressively cache `index.html`.
- **UX Issue:** The React Query pulling the `schema` array initialized `reportDefinition.source` to an empty string. If no source was selected, all sub-builders were hidden, presenting an empty, confusing screen to the user who expected default population.

### 3. Key Findings
- Nginx requires explicit `Cache-Control` for HTML files in Vite/SPA builds.
- Conditional rendering without empty state guidance or auto-selection causes massive UX friction, especially after UI refactors.

## Root Cause
1. Missing `Cache-Control: no-cache` in Nginx configuration for `index.html`.
2. Lack of default selection or empty state onboarding for dynamic form builders in React.

## Prevention / Rule
**Guardrail:** UI components that depend on an API-fetched schema must auto-select a default schema element if available, or present a clear "Welcome/Get Started" empty state block instead of a partially blank screen. SPAs must enforce `no-store, no-cache` on `index.html`.

This prevents users from staring at blank interfaces and prevents browsers from ignoring production hot-fixes.

## Solution

### Immediate Fix
- Modified `frontend/nginx.conf` to explicitly include `add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";` for the root location block.
- Patched `frontend/src/pages/DataIntelligenceStudio.tsx` to automatically set `reportDefinition.source` to the first available schema source (favoring 'institutions').
- Redeployed `tesc-frontend_client-1` on staging.

### Long-term Fix
- Ensure all future frontend container `nginx.conf` files include standard anti-caching headers for HTML files.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

---

**Resolved By:** Antigravity
**Time to Resolution:** 20 minutes
