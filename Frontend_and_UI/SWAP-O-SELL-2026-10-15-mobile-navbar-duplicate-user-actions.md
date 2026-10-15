# Mobile navbar duplicated profile actions and overflowed destinations

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
The storefront mobile navbar rendered two profile/user controls in the top bar. Notifications were only available in the bottom destination bar, and the bar used fixed minimum item widths that caused horizontal scrolling on narrow screens.

## Symptoms
- Two user/profile icons appeared in the mobile top navbar.
- Users had to find Notifications in the bottom bar.
- The bottom navigation could overflow horizontally, requiring scrolling.

## Environment Details
- **Server/Host:** Local Vite storefront
- **Services Affected:** React storefront navigation
- **Related Components:** `swappify-social-hub/src/components/Navbar.tsx`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Inspected the responsive branches in `Navbar.tsx` and compared the mobile header with the fixed bottom destination bar.

### 2. Root Cause Analysis
The mobile header contained two separate profile buttons. The shared navigation list included Notifications in both desktop and mobile render paths, while each mobile item had `min-w-[76px]`, making the total width exceed narrow phone viewports.

### 3. Key Findings
- The duplicate profile controls were rendered consecutively in the mobile header.
- Notifications already had a valid route and icon but was not exposed in the mobile top bar.
- Five bottom actions can fit when they use equal flexible widths rather than fixed minimum widths.

## Root Cause
The responsive navbar reused desktop destination definitions without separating the mobile information architecture, and the mobile profile markup had been duplicated during earlier navigation refactoring.

## Prevention / Rule
**Guardrail:** Keep mobile-only navigation actions in one explicit responsive render path and verify that the bottom navigation uses `flex-1 min-w-0` items without horizontal overflow.

This keeps the mobile header and bottom bar responsibilities distinct and prevents duplicate account controls or viewport-dependent scrolling from being introduced by shared navigation changes.

## Solution

### Immediate Fix
- Removed the duplicate mobile profile button.
- Added a Notifications link to the mobile top bar beside Search and Profile.
- Excluded Notifications from the bottom navigation.
- Replaced fixed minimum widths with flexible widths so all bottom actions fit without scrolling.

### Long-term Fix
Future mobile navigation changes should preserve the top-bar versus bottom-bar split: utility/account actions stay at the top, while primary destination actions stay in the fixed bottom bar.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- None

## References
- `swappify-social-hub/src/components/Navbar.tsx`

---

**Resolved By:** Copilot
**Time to Resolution:** Same session
