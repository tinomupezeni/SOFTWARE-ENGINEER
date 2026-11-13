# React 18 Warned on Image Fetch Priority Attribute

**Date:** 2026-11-13
**Project:** LEC Biotec
**Environment:** Development verification
**Severity:** Low
**Status:** Resolved

## Summary
The storefront media image component passed the camel-cased `fetchPriority` prop to React 18. Its shop-card test emitted a React warning that the prop was not recognized. The image priority hint was therefore not being rendered through the supported React 18 attribute spelling.

## Symptoms
- `shop-card.test.tsx` emitted `React does not recognize the fetchPriority prop on a DOM element`.
- The same component is used for CMS and catalogue images, including above-the-fold images.

## Environment Details
- **Server/Host:** Local Linux checkout
- **Services Affected:** Storefront image rendering
- **Related Components:** `apps/storefront/src/features/content/MediaImage.tsx`, React 18
- **Time First Observed:** 2026-11-13

## Investigation Steps

### 1. Initial Diagnosis
Ran `npm run verify` and inspected the warning emitted by the shop-card test.

### 2. Root Cause Analysis
Compared `MediaImage` with the existing lowercase-attribute pattern in `BackgroundCarousel`. React 18 warns on the camel-cased prop; its warning explicitly calls for lowercase `fetchpriority`.

```bash
rg -n 'fetchPriority|fetchpriority' apps/storefront/src
npm run test --workspace @lec/storefront -- --run src/features/catalogue/shop-card.test.tsx
```

### 3. Key Findings
- `MediaImage` supplied `fetchPriority` directly on `<img>`.
- `BackgroundCarousel` already uses lowercase `fetchpriority` through a spread for React 18 compatibility.
- The focused shop-card suite passed after the change without that warning; storefront typecheck also passed.

## Root Cause
The component used the newer camel-cased React prop spelling while this application runs React 18, which does not recognize it.

## Prevention / Rule
**Guardrail:** For React 18 DOM attributes not declared in its JSX types, use the browser attribute spelling through a typed spread and verify the rendered component produces no React unknown-prop warning.

This keeps image loading hints on the actual DOM element and makes the warning visible during focused component verification.

## Solution

### Immediate Fix
Changed `MediaImage` to spread lowercase `fetchpriority` onto the image.

```bash
npm run typecheck --workspace @lec/storefront
npm run test --workspace @lec/storefront -- --run src/features/catalogue/shop-card.test.tsx
```

### Long-term Fix
Keep image priority attributes aligned with the installed React version when upgrading React or adding image components.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code change applied

## Related Issues
- None.

## References
- `apps/storefront/src/features/content/MediaImage.tsx`
- `apps/storefront/src/features/marketing/components/BackgroundCarousel.tsx`

---

**Resolved By:** Codex
**Time to Resolution:** Same session
