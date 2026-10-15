# Frontend production bundle exceeds Vite warning threshold

**Date:** 2026-10-15  
**Project:** Swap-O-Sell  
**Environment:** Development build  
**Severity:** Low  
**Status:** Investigating

## Summary
The production frontend build succeeds, but Vite reports that the main JavaScript chunk is approximately 542 kB after minification, above the default 500 kB warning threshold. This is not currently blocking deployment, but the growing route surface makes code-splitting a future performance concern.

## Symptoms
- `npm run build` completes successfully.
- Vite emits a chunk-size warning for the main JavaScript bundle.

## Environment Details
- **Server/Host:** Local Docker Compose
- **Services Affected:** React/Vite storefront build
- **Related Components:** `swappify-social-hub/src/App.tsx`, route imports
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Ran the production Vite build after adding the marketplace homepage.

### 2. Root Cause Analysis
The application statically imports a large set of routes and UI dependencies into the main bundle. The new homepage adds UI surface but does not introduce a separate dependency package.

### 3. Key Findings
- Build output remains successful.
- The main chunk is above Vite's advisory threshold.
- No runtime failure was observed in the rebuilt Docker-served frontend.

## Root Cause
The storefront currently uses eager route imports instead of route-level code splitting.

## Prevention / Rule
**Guardrail:** Treat a Vite chunk-size warning above 500 kB as a performance backlog item and require route-level lazy loading before the main bundle exceeds an agreed production budget.

This keeps the warning visible while avoiding a misleading configuration-only fix that would hide growing bundle cost.

## Solution

### Immediate Fix
No functional fix was required; the build and deployed frontend were verified successfully.

### Long-term Fix
Convert route imports in `App.tsx` to `React.lazy` with a shared loading fallback, then measure the main chunk and key route chunks.

## Prevention
- [ ] Code splitting implementation
- [x] Warning documented
- [ ] Performance budget automation

## References
- `swappify-social-hub/src/App.tsx`
- Vite production build output
- Related report: `reports/SWAP-O-SELL-2026-10-15-amazon-inspired-marketplace-home.md`

---

**Resolved By:** Copilot  
**Time to Resolution:** Not resolved; tracked for follow-up
