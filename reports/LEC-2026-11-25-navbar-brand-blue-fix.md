# Engineering Report: Navbar Background Color Fix to Brand Blue Ink

- **Date:** 2026-11-25
- **Project:** `lec-biotech-ascend`
- **Author:** Antigravity / Engineering Team

---

## 1. Context & Trigger
Following user testing after inverting the storefront navigation bar, the user reported:
> "ok that navbar was wrong background color, its looks grey not blue whats going on there"

Inspection of the rendered storefront confirmed that while the intent was a rich brand navy blue, the navbar background appeared as a neutral, desaturated grey/slate bar.

---

## 2. Root Cause Analysis
1. In `Navbar.tsx`, when `solid` was active (scrolled, open, or on interior catalog/content pages), the background layer used:
   ```tsx
   solid ? cn(glassVariants({ tone: "ink", layer: "chrome" }), "border-x-0 border-t-0") : "bg-ink-deep/40 backdrop-blur-sm"
   ```
2. In `packages/ui/src/glass/glass-variants.ts`:
   - `tone: "ink"` is defined as:
     `bg-[color-mix(in_srgb,var(--ink-deep)_78%,transparent)]`
   - `layer: "chrome"` adds:
     `shadow-[inset_0_1px_0_0_color-mix(in_srgb,var(--paper)_55%,transparent),0_12px_40px_-16px_color-mix(in_srgb,var(--ink)_28%,transparent)] backdrop-blur-xl backdrop-saturate-150`
3. Color definitions:
   - `var(--ink)` is `#17386D` (rich brand navy blue, matching logo mark and brand identity).
   - `var(--ink-deep)` is `#020617` (near-black / charcoal slate, V=9.0%).
4. Combining 78% opacity on `#020617` over a white/light page background, frosted by `backdrop-blur-xl` and washed out by a 55% white inset top shadow (`shadow-[inset_0_1px_0_0_color-mix(in_srgb,var(--paper)_55%,transparent)]`), yielded a muted, washed-out grey instead of the intended vibrant LEC Biotec royal blue.
5. In addition, the mobile drawer was styled with `bg-[var(--ink-deep)]`, causing the open mobile menu to look like dark charcoal grey rather than the brand blue.

---

## 3. Changes Made
1. **Storefront Navbar (`Navbar.tsx`):**
   - Replaced `glassVariants({ tone: "ink", layer: "chrome" })` with a rich, solid brand blue layer:
     `border-b border-[color-mix(in_srgb,var(--paper)_15%,transparent)] bg-[var(--ink)] shadow-[0_4px_24px_-4px_rgba(2,57,122,0.35)]`
   - Updated the hero translucent overlay from `bg-ink-deep/40` to `bg-[var(--ink)]/40`.
   - Updated the mobile flyout drawer from `bg-[var(--ink-deep)]` to `bg-[var(--ink)]`.
   - Cleaned up unused imports (`glassVariants`).

---

## 4. Verification
1. **Navigation Test Suite:**
   - Ran `npm run test --workspace @lec/storefront -- src/features/navigation/` (3 test suites, 22 tests passing).
2. **Lint & Type Checks:**
   - `npm run lint -- --max-warnings 0` passed cleanly with 0 errors and 0 warnings.
   - `npm run typecheck` passed across all workspaces (`storefront`, `admin`, `ui`, `api-client`).
   - `npm run build` succeeded cleanly.
3. **Deployment to Production:**
   - Pushed commit `305347e` to `origin/main`.
   - Executed `deploy.sh` to production VPS (`93.127.143.153`).
   - Verified live container health check:
     `{"status":"healthy","version":"305347e","environment":"production","components":{"database":"up","cache":"up","storage":"up"}}`.
