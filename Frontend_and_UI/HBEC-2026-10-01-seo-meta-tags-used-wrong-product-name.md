# SEO Meta Tags Shipped With The Wrong Product Name ("HBEC" Instead Of "HBCA")

**Date:** 2026-10-01
**Project:** HBEC
**Environment:** Production
**Severity:** Medium
**Status:** Resolved

## Summary
The SEO sitemap/meta-tags commit (`efdfdc36`, shipped as part of the same
day's full-catchup production promotion) set the student frontend's
`<title>`, `meta[name=title]`, `meta[name=description]` and
`meta[name=keywords]` to say "HBEC" — the internal project/repo codename —
while every other piece of branding already in that same `index.html`
(`application-name`, `apple-mobile-web-app-title`, `og:title`,
`twitter:title`, the `<noscript>` fallback) correctly says "HBCA", the
actual public-facing product name. Caught live by the user immediately
after the promotion reached production.

## Symptoms
- Browser tab title, Google search result title/snippet, and search
  description all said "HBEC" instead of the product's real name "HBCA".
- No functional breakage — purely incorrect public-facing branding text.

## Environment Details
- **Server/Host:** Production VPS, student frontend (`student.hbca.tech`)
- **Services Affected:** `STUDENT/Frontend` (static `index.html`, build-time
  only — no backend involved)
- **Related Components:** `STUDENT/Frontend/index.html`,
  `STUDENT/Frontend/public/sitemap.xml`
- **Time First Observed:** 2026-10-01, within minutes of promoting `efdfdc36`
  to production as part of the full-catchup promotion

## Investigation Steps

### 1. Initial Diagnosis
User reported it directly by name: "its now says HBEC, its supposed to be
HBCA." Read `index.html` to confirm the scope of the mistake.

### 2. Root Cause Analysis
Found the file already used "HBCA" consistently in five other places
(`application-name`, `apple-mobile-web-app-title`, `og:title`,
`twitter:title`, `<noscript>`), so the SEO commit's four tags were the
outlier, not the rest of the file. Also found `og:url`/`twitter:url`
pointed at `https://hbec.co.zw/`, a domain that doesn't match
`sitemap.xml`'s or `docker-compose.production.yml`'s actual production
domain (`student.hbca.tech`), confirming that commit introduced more than
one inconsistency at once.

### 3. Key Findings
- "HBEC" is this repository's own/internal project name (see
  `CLAUDE.md`'s title: "HBEC Project"); "HBCA" is the actual branded product
  students and search engines should see. The SEO commit's author used the
  internal name instead of the product name.
- `og:url`/`twitter:url` pointed at an entirely unrelated domain
  (`hbec.co.zw`) never configured anywhere else in the stack.

## Root Cause
The SEO commit introduced new meta tags using the internal project
codename ("HBEC") instead of the established public product name ("HBCA")
already used consistently everywhere else in the same file, and pointed
`og:url`/`twitter:url` at a domain not actually used by this deployment.

## Prevention / Rule
**Guardrail:** Any future change to `index.html`'s SEO/meta tags should be
spot-checked against the file's own existing branding tags
(`application-name`, `og:title`, `twitter:title`) for consistency before
merging — a one-line grep for "HBEC" across `STUDENT/Frontend/public/` and
`index.html` would have caught this immediately, since the correct name
("HBCA") already appears five times in the same file.

This closes the specific gap because the inconsistency was entirely
internal to one file — the correct answer was already present and
contradicted by the new lines, which a same-file consistency check would
surface mechanically without needing any external reference.

## Solution

### Immediate Fix
Corrected all four tags to "HBCA" and both URL tags to
`https://student.hbca.tech/`, rebuilt `student-frontend` on staging,
verified the corrected title live on staging, then promoted the single
image to production using the same digest-pinning discipline as the
earlier full-catchup promotion.

```bash
# Confirmed live on production
curl -s https://student.hbca.tech/ | grep -oE '<title>[^<]*</title>'
# <title>HBCA - The Best Exam Prep in Zimbabwe</title>
```

### Long-term Fix
No code/process change beyond the guardrail above — this was a one-off
content mistake in a single commit, not a systemic gap.

## Prevention
- [x] Code changes required — done, commit `dea79aee`.
- [ ] Consider a CI grep step on `STUDENT/Frontend/index.html` /
      `public/` that fails if "HBEC" appears outside comments/code, given
      the established convention that public-facing text must say "HBCA".
- [ ] Monitoring/alerts to add: none — this class of error has no runtime
      signature.
- [x] Documentation to update: this entry.

## Related Issues
- Shipped alongside: `reports/HBEC-2026-10-01-full-catchup-production-promotion.md`
  (the promotion that introduced this bug via `efdfdc36`).
- Also fixed in the same deploy, found while promoting: `/opt/hbec/.env`'s
  `TAG` had gone stale, tracked separately if logged.

## References
- `STUDENT/Frontend/index.html`
- `STUDENT/Frontend/public/sitemap.xml`
- `docker-compose.production.yml` (confirms `student.hbca.tech` as the real
  production domain)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Minutes — caught by the user immediately after the promotion that introduced it, fixed and redeployed same session.
