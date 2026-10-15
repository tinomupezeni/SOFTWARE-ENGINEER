# Missing Home Navigation Icon

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary

The primary left navigation item routed users to the marketplace feed but
displayed a search icon instead of a home icon. This weakened the visual
mapping between the navigation destination and its purpose.

## Symptoms

- The left rail and mobile navigation showed a search glyph for the Feed item.
- Users had no clear home icon for returning to the marketplace landing feed.

## Environment Details

- **Server/Host:** Local Docker frontend at `http://localhost:8080`
- **Services Affected:** React/Vite frontend
- **Related Components:** `Navbar.tsx`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis

Reviewed the navigation definition in `swappify-social-hub/src/components/Navbar.tsx`.

### 2. Root Cause Analysis

The `Feed` navigation item used the imported `Search` icon even though its
destination represented the home/feed surface.

### 3. Key Findings

- The route and active-state logic were correct.
- Only the icon mapping was incorrect.
- The same navigation definition drives desktop and mobile navigation, so one
  change corrected both surfaces.

## Root Cause

The Feed item was configured with `icon: Search`, creating a misleading
navigation affordance.

## Prevention / Rule

**Guardrail:** Navigation items must use icons whose semantic meaning matches
their destination, and UI changes must include a visual smoke check of both
desktop rail and mobile navigation.

This directly prevents route/icon mismatches from passing unnoticed when the
same navigation configuration is reused across responsive surfaces.

## Solution

### Immediate Fix

Changed the Feed navigation item to use Lucide's `Home` icon.

### Long-term Fix

Keep destination labels, routes, and icon assignments together in the shared
navigation definition and review them as one semantic unit.

## Prevention

- [x] Configuration/code change completed
- [ ] Monitoring/alerts needed
- [x] Documentation updated through this issue log
- [ ] Additional code changes required

## Related Issues

- None

## References

- `swappify-social-hub/src/components/Navbar.tsx`

---

**Resolved By:** Copilot
**Time to Resolution:** Same session
