# "Learn More About Wifing Out Loud" Button Linked to the Homepage, Not the About Page

**Date:** 2026-10-27
**Project:** Wifing Out Loud (WOL)
**Environment:** Production (single environment, no staging)
**Severity:** Low (Broken Navigation Intent)
**Status:** Resolved

## Summary
ProjectFlow task "Learn More" ("Link to about page"): the closing CTA button
on the Wise Wives page, labeled "Learn More About Wifing Out Loud," linked to
`/` (the homepage) instead of `/about`.

## Symptoms
- A visitor clicking "Learn More About Wifing Out Loud" on the Wise Wives
  page's closing section landed back on the homepage, not the About page —
  despite the button's own label promising more information about the
  organisation.

## Root Cause
`frontend/src/lib/page-content.ts`'s `ww_closing` CTA section had
`{ label: "Learn More About Wifing Out Loud", to: "/" }`. A working `/about`
route (`frontend/src/routes/about.tsx`, `page-content.ts` slug `"about"`)
already existed; the button simply pointed at the wrong internal path.

## Solution
Changed the button's `to` from `"/"` to `"/about"`.

Verified with `tsc --noEmit`, `eslint` (clean), and a direct HTTP check
against the rebuilt production container
(`curl .../wise-wives | grep 'href="...about...'`) confirming the link now
resolves to `/about`.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (one `to` value in `page-content.ts`)

---

**Resolved By:** Tinotenda Mupezeni (with Claude Code)
**Time to Resolution:** ~10 minutes
