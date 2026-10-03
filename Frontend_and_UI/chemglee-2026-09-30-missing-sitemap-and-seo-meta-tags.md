# Missing Sitemap and Suboptimal SEO Meta Tags

**Date:** 2026-09-30
**Project:** Chem-Glee (chemglee-concept-site)
**Environment:** Production/Development
**Severity:** High
**Status:** Resolved

## Summary
The site was missing a `sitemap.xml` for search engine indexing and had suboptimal title and meta description tags which could hinder discovery via Google Search. The LocalBusiness schema address was also outdated compared to the one used for the Google Business Profile.

## Symptoms
- The site might not be properly indexed by Google without a sitemap.
- The search result titles and descriptions would not match the desired target keywords (e.g. "Eco-Friendly Dishwashing Liquid Manufacturer Harare").
- The physical address in JSON-LD structured data did not match the one submitted to Google Business Profile.

## Environment Details
- **Services Affected:** Frontend SEO (React SPA)
- **Related Components:** `frontend/index.html`, `frontend/public/sitemap.xml`

## Investigation Steps

### 1. Initial Diagnosis
The user provided an SEO checklist indicating issues with how Google interprets the site.

### 2. Root Cause Analysis
- The project is a React SPA (Vite). There is no automated Yoast SEO-style plugin to generate a sitemap.
- The `index.html` file contained default/generic titles and descriptions, and an older address ("44 Plymouth Road, Southerton") rather than the new one ("10 Dovedale Lane, Glen Lorne, Harare").

### 3. Key Findings
- `frontend/public/sitemap.xml` did not exist.
- `robots.txt` had `Allow: /` but pointed to a non-existent `sitemap.xml`.
- SEO meta tags needed alignment with business messaging.

## Root Cause
Static SEO meta tags in the SPA's `index.html` were not updated to target high-value local search queries, and no mechanism was in place to automatically build a sitemap.

## Prevention / Rule
**Guardrail:** Include a sitemap generation step in the CI/CD pipeline or explicitly enforce static sitemap creation in the frontend PR checklist for new routes.

Automated sitemap generation (e.g. using a Vite plugin) ensures that any new routes added to the React application are systematically available to search engine crawlers without manual intervention.

## Solution

### Immediate Fix
- Updated `<title>`, `<meta name="description">`, Open Graph, and Twitter tags in `frontend/index.html` to reflect the desired SEO copy.
- Updated the `LocalBusiness` address in the JSON-LD payload to "10 Dovedale Lane, Glen Lorne, Harare".
- Created a static `frontend/public/sitemap.xml` containing the main routes (`/`, `/products`, `/about`, `/contact`, `/become-partner`).

### Long-term Fix
- Consider adding `vite-plugin-sitemap` to auto-generate the sitemap during build based on the TanStack router configuration.

## Prevention
- [ ] Code changes required (Add automated sitemap generation plugin)

---

**Resolved By:** Antigravity
**Time to Resolution:** 10m
