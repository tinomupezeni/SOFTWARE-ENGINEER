# Missing Sitemap and Suboptimal SEO Meta Tags

**Date:** 2026-09-30
**Project:** HBCA (savanna-learning)
**Environment:** Production/Development
**Severity:** High
**Status:** Resolved

## Summary
The Savanna Learning frontend (`hbca.tech`) lacked a `sitemap.xml` for search engine indexing, and the canonical URLs and meta descriptions needed alignment with the new domain and messaging.

## Symptoms
- The site might not be properly indexed by Google without a sitemap.
- The title and description were somewhat generic and the canonical URL pointed to an old domain (`hbca-learning.zw`).

## Environment Details
- **Services Affected:** Frontend SEO (Vite SPA in `savanna-learning`)
- **Related Components:** `index.html`, `public/sitemap.xml`

## Investigation Steps

### 1. Initial Diagnosis
User requested implementing standard SEO checklists and adding a sitemap for the new domain `hbca.tech`.

### 2. Root Cause Analysis
- The project is a Vite application where static SEO meta tags in `index.html` were pointing to an old domain and lacked the targeted marketing copy.
- No automated or static sitemap was present.

### 3. Key Findings
- `public/sitemap.xml` did not exist.
- Meta tags needed to be aligned with the marketing message.

## Root Cause
No step was implemented to generate sitemaps or update generic titles for SEO in the root directory.

## Prevention / Rule
**Guardrail:** Enforce a CI check or build-step plugin to generate a sitemap for the application, or require manual validation of SEO meta tags before deploying public-facing entry points.

## Solution

### Immediate Fix
- Updated `<title>`, `<meta name="description">`, canonical URLs, and Open Graph tags in `index.html` to target "HBCA | Zimbabwe's Heritage Based Curriculum Assistant" on `hbca.tech`.
- Created a static `public/sitemap.xml` containing the main route (`/`).

### Long-term Fix
- Implement `vite-plugin-sitemap` in the build pipeline to auto-generate the sitemap as new routes are added.

## Prevention
- [ ] Code changes required (Add automated sitemap generation plugin)

---

**Resolved By:** Antigravity
**Time to Resolution:** 5m
