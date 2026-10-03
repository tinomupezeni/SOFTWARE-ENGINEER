# Missing Sitemap and Suboptimal SEO Meta Tags

**Date:** 2026-09-30
**Project:** HBEC
**Environment:** Production/Development
**Severity:** High
**Status:** Resolved

## Summary
The HBEC Student Portal (`student.hbca.tech`) lacked a `sitemap.xml` for search engine indexing and was using suboptimal title and meta description tags, hindering organic search discovery.

## Symptoms
- The site might not be properly indexed by Google without a sitemap.
- The title ("HBCA Assistant") and description did not optimize for high-value search queries ("HBEC - The Best Exam Prep in Zimbabwe").

## Environment Details
- **Services Affected:** Frontend SEO (React SPA in `STUDENT/Frontend`)
- **Related Components:** `STUDENT/Frontend/index.html`, `STUDENT/Frontend/public/sitemap.xml`

## Investigation Steps

### 1. Initial Diagnosis
User requested implementing standard SEO checklists and adding a sitemap.

### 2. Root Cause Analysis
- The project is a React SPA where static SEO meta tags in `index.html` were default/generic.
- No automated or static sitemap was present.

### 3. Key Findings
- `STUDENT/Frontend/public/sitemap.xml` did not exist.
- Meta tags needed to be aligned with the marketing message.

## Root Cause
No step was implemented to generate sitemaps or update generic titles for SEO in the `STUDENT/Frontend/` directory.

## Prevention / Rule
**Guardrail:** Enforce a CI check or build-step plugin to generate a sitemap for the React application, or require manual validation of SEO meta tags before deploying public-facing entry points.

## Solution

### Immediate Fix
- Updated `<title>` and `<meta name="description">` in `STUDENT/Frontend/index.html` to target "HBEC - The Best Exam Prep in Zimbabwe".
- Created a static `STUDENT/Frontend/public/sitemap.xml` containing the main routes (`/` and `/login`).

### Long-term Fix
- Implement `vite-plugin-sitemap` or a similar tool in the build pipeline to auto-generate the sitemap as new routes are added.

## Prevention
- [ ] Code changes required (Add automated sitemap generation plugin)

---

**Resolved By:** Antigravity
**Time to Resolution:** 5m
