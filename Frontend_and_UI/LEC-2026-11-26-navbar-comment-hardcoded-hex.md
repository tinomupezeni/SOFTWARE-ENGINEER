# Content gate failed on hex colour literals left in Navbar comments

**Date:** 2026-11-26
**Project:** LEC Biotec (lec-biotech-ascend)
**Environment:** Development (caught by `npm run verify`)
**Severity:** Low
**Status:** Resolved

## Summary
`npm run verify`'s content gate failed with "a colour is hardcoded" against
`apps/storefront/src/features/navigation/components/Navbar.tsx`, even
though no component actually used a literal hex value — the matches were
inside two code comments.

## Symptoms
- `scripts/verify/content-gate.sh` reported lines 55 and 65 of `Navbar.tsx`
  as hardcoded colours, blocking `npm run verify`.
- Both flagged lines were comments explaining the brand's `--ink` token,
  written with the hex value `#02397a` in parentheses for reference — left
  over from commit 305347e ("fix(navigation): set navbar background to
  rich brand blue ink").

## Environment Details
- **Related Components:** `apps/storefront/src/features/navigation/components/Navbar.tsx`
- **Time First Observed:** 2026-11-26, while running `npm run verify`
  after an unrelated storefront fix.

## Investigation Steps

### 1. Initial Diagnosis
Ran `npm run verify`; the content gate step failed citing lines 55 and 65.

### 2. Root Cause Analysis
Per this repo's own documented rule (`CLAUDE.md`): "Tailwind scans source
as raw text, including comments. Never write a literal utility class name
in a comment." The content gate's hex-colour check has the same blind spot
— it scans raw file text, not just rendered JSX/class values, so a hex
code written in an explanatory comment trips it exactly like a real
hardcoded colour would.

### 3. Key Findings
- No actual hardcoded colour existed in rendered output; `className`
  values already used `var(--ink)` correctly.
- The gate cannot distinguish a comment from live code, by design
  (deliberately strict, per the content-gate rule rationale), so the
  comments themselves were the defect.

## Root Cause
A documentation comment added in a prior commit referenced the brand hex
value directly instead of only naming the token, which the content gate
(scanning raw text) treats identically to a real violation.

## Prevention / Rule
**Guardrail:** None new needed — this is the content gate working as
designed (per the existing "Tailwind scans as raw text" rule already in
`CLAUDE.md`). Prevention is a review habit, not a new mechanism: never
write a literal hex value in a comment in this codebase; reference the
token name only.

This closes the gap because the gate's existing strictness is correct and
intentional; the fix is to stop writing hex literals in comments, not to
loosen the gate.

## Solution

### Immediate Fix
Removed the literal `#02397a` hex references from both comments in
`Navbar.tsx` (lines 55 and 65), keeping the token name (`var(--ink)`) and
descriptive wording ("rich brand blue", "saturated brand blue").

### Long-term Fix
None required.

## Prevention
- [x] Code changes required (done)
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Related Issues
Found while fixing [[LEC-2026-11-26-facet-panel-label-overflow]] in the
same session — unrelated component, logged separately per convention.

## References
- `apps/storefront/src/features/navigation/components/Navbar.tsx`
- `scripts/verify/content-gate.sh`

---

**Resolved By:** Claude (session with tinomupezeni)
**Time to Resolution:** < 15 minutes
