# Storefront Had No Security Headers, and Every Page Reported the Homepage's Canonical URL

**Date:** 2026-09-18
**Project:** chemglee-concept-site
**Environment:** Production
**Severity:** High (zero HSTS/CSP on the customer-facing origin; a real SEO/duplicate-content bug on every page)
**Status:** Resolved (merged to `main` via PR #4)

## Summary
Django sets real security headers on the API and admin origins
(`config/settings/production.py`), but never serves the storefront origin —
that's a static Vite build behind Caddy. Nobody had ever added the
equivalent headers there, so `chemgleeonline.com` shipped with no HSTS, no
CSP, and no Referrer-Policy at all — the asymmetry meant the site's most
public-facing origin was its least protected. Separately, every route
reported the *homepage's* canonical URL (a copy-paste default that was
never made per-route), telling search engines the cart, the policies, and
the shop front were all the same page — a real duplicate-content signal.
Product/Offer/Breadcrumb/LocalBusiness structured data and a real sitemap
(vs. a static `sitemap.xml` that had to be hand-edited) didn't exist either.

## Root Cause
Security headers and SEO metadata were treated as "a backend concern" and
implemented only where Django directly served a response — nobody
inventoried what the storefront's *own* origin (a separately-served static
SPA) was missing until this audit looked at it directly.

## Solution
- `Caddyfile.prod`: a reusable `(security_headers)` snippet (HSTS, CSP,
  X-Content-Type-Options, Referrer-Policy, Permissions-Policy, X-Frame-Options,
  hides the `Server` header) applied to the storefront; a origin-specific CSP
  (script-src 'self' only — Vite emits no inline scripts; style-src needs
  'unsafe-inline' for Tailwind/inline styles; connect-src scoped to the admin
  API host and Paynow). The admin origin gets the shared headers but no CSP
  (Django admin/Unfold need inline scripts).
  `encode zstd gzip` added — nothing on this origin was compressed before.
- Per-route canonical URLs (`usePageMetadata`), Product/Offer/Breadcrumb/
  LocalBusiness structured data built from the live catalogue
  (`useStructuredData`), and `/sitemap.xml` now generated server-side from
  the real catalogue (proxied through Caddy to the backend) instead of a
  static file — listing only indexable pages.

## Prevention
- [ ] Consider a periodic header-check (e.g. Mozilla Observatory / securityheaders.com
      style check) against the storefront origin specifically, not just the
      API — this gap existed because nobody was checking that origin at all.

## References
- Commit `c224bb6` ("Say only what we can back up, and link where every
  claim leads"), merged to `main` in this session's PR #4 merge (`8bcc3dd`).
- `Caddyfile.prod`, `frontend/src/hooks/usePageMetadata.ts`,
  `frontend/src/hooks/useStructuredData.ts`, `backend/apps/catalog/sitemap.py`
- **Action needed on the VPS**: this Caddy config isn't live until
  `sudo cp Caddyfile.prod /etc/caddy/Caddyfile && sudo caddy reload` is run
  on the next deploy (same manual step this repo's
  `chemglee-concept-site-2026-09-11-www-subdomain-cors-misconfiguration-served-stale-catalog.md`
  entry already required, in `Frontend_and_UI/`).

---

**Resolved By:** winstonjthinker + Claude Opus 5 (1M context), PR #4
**Time to Resolution:** N/A (site audit)
