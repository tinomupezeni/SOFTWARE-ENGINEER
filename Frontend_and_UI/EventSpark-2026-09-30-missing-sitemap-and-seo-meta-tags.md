# Missing Sitemap and Suboptimal SEO Meta Tags

**Date:** 2026-09-30
**Project:** Event Spark (Wifing Out Loud)
**Environment:** Production/Development
**Severity:** High
**Status:** Resolved

## Summary
The Event Spark frontend (`wifingoutloud.co.zw`) lacked a `sitemap.xml` for search engine indexing and was using suboptimal title and meta description tags, hindering organic search discovery.

## Symptoms
- The site might not be properly indexed by Google without a sitemap.
- The title ("Wifing Out Loud") and description ("Sisterhood gatherings, podcast and shop.") did not optimize for high-value search queries ("A Christ-Centered Community for Wives").

## Environment Details
- **Services Affected:** Frontend SEO (TanStack Start SPA in `frontend`)
- **Related Components:** `frontend/src/routes/__root.tsx`, `frontend/public/sitemap.xml`

## Investigation Steps

### 1. Initial Diagnosis
User requested implementing standard SEO checklists and adding a sitemap.

### 2. Root Cause Analysis
- The project is a TanStack Start application where static SEO meta tags in `__root.tsx` were default/generic.
- No automated or static sitemap was present.

### 3. Key Findings
- `frontend/public/sitemap.xml` did not exist.
- Meta tags needed to be aligned with the marketing message.

## Root Cause
No step was implemented to generate sitemaps or update generic titles for SEO in the `frontend/` directory.

## Prevention / Rule
**Guardrail:** Enforce a CI check or build-step plugin to generate a sitemap for the React application, or require manual validation of SEO meta tags before deploying public-facing entry points.

## Solution

### Immediate Fix
- Updated `<title>` and `<meta name="description">` in `frontend/src/routes/__root.tsx` to target "Wifing Out Loud | A Christ-Centered Community for Wives".
- Created a static `frontend/public/sitemap.xml` containing the main route (`/`).

### Long-term Fix
- Implement a sitemap generation plugin in the build pipeline to auto-generate the sitemap as new routes are added.

## Prevention
- [ ] Code changes required (Add automated sitemap generation plugin)

---

**Resolved By:** Antigravity
**Time to Resolution:** 5m
