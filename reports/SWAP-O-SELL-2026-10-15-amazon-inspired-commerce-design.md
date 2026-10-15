# Amazon-Inspired Commerce Design for Swap-O-Sell

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** Design Implementation / UX Refactor
**Status:** Completed

## Summary
Applied the supplied Amazon.com-inspired design system to the Swap-O-Sell
frontend as a commerce-oriented visual layer. The implementation emphasizes
product-first scanning, trust through legible contrast and borders, clear
commerce actions, compact 4px-grid spacing semantics, and restrained
square-cornered surfaces while retaining Swap-O-Sell's own brand identity and
marketplace workflows.

## Context / Trigger
The user supplied an Amazon.com design-system specification after the
frontend had received an Apple-inspired treatment. The specification favored
trust signals, one clear primary action, speed, blue links, yellow/orange
commerce accents, compact radii, and tokenized states. A full Amazon brand
copy was intentionally avoided because Swap-O-Sell needs its own identity and
the application is a web marketplace rather than Amazon.com.

## Scope
Included the centralized frontend design tokens, semantic Tailwind mappings,
shared card/button/input utilities, and the visual defaults consumed by the
existing navigation, feed, product, search, and messaging surfaces.
Excluded a page-by-page rewrite of business workflows, native Amazon
branding/assets, a new font download, and a full browser-based visual
accessibility audit.

## Method

1. Reviewed the supplied color, typography, spacing, shape, elevation, motion,
   component-state, and accessibility requirements.
2. Read the repository engineering index, HCI guidance, and the prior
   Apple-inspired design report.
3. Converted the supplied palette into semantic CSS variables and mapped the
   commerce colors into Tailwind tokens.
4. Rebalanced shared surfaces toward product-first commerce: compact corners,
   visible borders, restrained elevation, blue links, and yellow primary
   commerce actions.
5. Built the frontend, rebuilt the Docker frontend image, and verified the
   local frontend and proxied API health endpoint.

## Decisions & Findings

- The implementation uses a hybrid product decision: Amazon-style commerce
  clarity replaces the previous visual defaults, while Swap-O-Sell retains
  its own brand name, logo, trust features, and application behavior.
- `#2162A1` is the primary link/action blue; `#FFD814` and `#F08804` are
  reserved for commerce emphasis and primary purchase/swap actions.
- White surfaces, gray borders, small radii, and restrained shadows make
  listing information easier to scan without removing hierarchy.
- The font stack starts with Amazon Ember-compatible names but falls back to
  locally available system fonts; no external proprietary font asset was
  introduced.
- Existing focus-visible and reduced-motion behavior remains part of the
  shared system, preserving the accessibility work from the preceding
  redesign.

## Changes Made

- `swappify-social-hub/src/index.css`
  - Replaced the previous Cobalt/Apple visual defaults with semantic
    Amazon-derived commerce tokens.
  - Added commerce orange/yellow tokens, compact radius, product-card
    borders, restrained shadows, and tokenized button/input treatments.
  - Preserved focus-visible outlines and reduced-motion handling.
- `swappify-social-hub/tailwind.config.ts`
  - Added `commerce.orange` and `commerce.yellow` semantic mappings.

## Verification

- `npm run build` passed.
- `docker compose up --build -d frontend` passed.
- `curl -fsSI http://localhost:8080/` returned HTTP 200.
- `curl -fsS http://localhost:8080/api/health/` returned
  `{"ok": true, "service": "swap-o-sell"}`.
- `git diff --check` passed for the changed design files.
- The existing frontend lint baseline and large JavaScript bundle warning
  remain unresolved and were not expanded by this design work.

## Follow-ups / Deferred

- Run browser-based visual checks at the smallest and largest supported
  breakpoints.
- Audit every interactive component against the complete required state
  matrix: hover, focus-visible, active, disabled, loading, error, and empty.
- Continue replacing page-specific raw values with shared tokens.
- Resolve the pre-existing frontend lint errors and production dependency
  vulnerabilities as separate engineering work.

## References

- User-provided Amazon.com design-system specification.
- `Principal_Engineer/engineering-guides/12. HCI.md`
- `reports/SWAP-O-SELL-2026-10-15-apple-inspired-ui-design.md`
- `/home/shadowe/Projects/swap-o-sell/swappify-social-hub/src/index.css`
- `/home/shadowe/Projects/swap-o-sell/swappify-social-hub/tailwind.config.ts`

---

**Completed By:** Copilot
**Duration:** One implementation session
