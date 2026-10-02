# Stale Static sitemap.xml Resurrected, Shadowed by the Dynamic One

**Date:** 2026-10-02
**Project:** Chem-Glee (chemglee-concept-site)
**Environment:** Production/Development
**Severity:** Low
**Status:** Resolved

## Summary
On 2026-09-17 the storefront sitemap was deliberately moved from a static
`frontend/public/sitemap.xml` file to a Django view generated from the live
catalogue (`backend/apps/catalog/sitemap.py`), with Caddy rewriting
`chemgleeonline.com/sitemap.xml` to that view so it always lists every active
product. On 2026-09-30, an unrelated SEO commit re-created
`frontend/public/sitemap.xml` as a static file again (5 hardcoded URLs, no
products), apparently without realizing the dynamic version already existed.
The re-added file was never actually served in production — Caddy's rewrite
takes `/sitemap.xml` before it ever reaches the frontend container — but it
sat in the repo as a convincing, wrong answer to "what does our sitemap
contain," which is exactly where the user went looking when the site didn't
show up in Google search yet.

## Symptoms
- User reported the sitemap "added 2 days ago" wasn't getting the site
  indexed by Google.
- Reading `frontend/public/sitemap.xml` in the repo suggested the sitemap
  only listed 5 static routes and no products — looked incomplete/broken.
- The actual live `https://chemgleeonline.com/sitemap.xml` was in fact
  correct and complete (confirmed via `curl`): all static pages, policy
  pages, and every active product with `lastmod`.
- `HEAD https://chemgleeonline.com/sitemap.xml` returned `405 Method Not
  Allowed` (GET worked fine) — the Django view used `@require_GET`.

## Environment Details
- **Services Affected:** Storefront SEO / sitemap
- **Related Components:** `frontend/public/sitemap.xml` (dead file),
  `backend/apps/catalog/sitemap.py` (the real view), `Caddyfile.prod`
  (`handle /sitemap.xml { rewrite * /api/sitemap.xml; reverse_proxy ... }`)

## Investigation Steps

### 1. Initial Diagnosis
Compared the repo's `frontend/public/sitemap.xml` against the live URL.

### 2. Root Cause Analysis
```bash
git log --oneline --all -- frontend/public/sitemap.xml
# e06de39 SEO: Update meta tags, add sitemap, ... (2026-09-30, re-added it)
# 5d30e9f Give every product its own page ...   (2026-09-17, deleted it)
git show 5d30e9f --stat | grep sitemap
# backend/apps/catalog/sitemap.py | 71 ++ (added)
# frontend/public/sitemap.xml    | 58 -- (deleted)
curl -sI https://chemgleeonline.com/sitemap.xml      # GET: 200, full catalogue
curl -sI -X HEAD https://chemgleeonline.com/sitemap.xml  # 405
```

### 3. Key Findings
- The 2026-09-30 commit resurrected a file that a prior commit had
  intentionally removed in favor of a dynamic equivalent — a regression
  introduced by an agent/session that didn't check history before adding a
  file that already looked "missing."
- Caddy's routing masked the dead file in production, so nothing was
  actually broken for Google — but the repo no longer reflected reality,
  which is what sent the user down the wrong path while debugging.
- Separately, the real sitemap view only allowed GET (`@require_GET`),
  405ing on HEAD — harmless for Googlebot specifically, but a real gap for
  any other crawler/monitor that probes with HEAD first.

## Root Cause
A previous session re-added a static `sitemap.xml` without checking whether
a sitemap mechanism already existed, because the file's prior, deliberate
deletion wasn't visible without reading git history for that specific path.

## Prevention / Rule
**Guardrail:** Before adding a file that looks "missing" in a working tree,
run `git log --all --oneline -- <path>` for that path when the surrounding
code gives any hint it might have moved (e.g. a sibling comment, a grep for
the old filename's purpose) rather than assuming absence means "never
existed."

This closes the exact gap here: a one-line history check on
`frontend/public/sitemap.xml` would have shown it was deleted eight commits
earlier in favor of `backend/apps/catalog/sitemap.py`, which still exists
and is still routed by Caddy.

## Solution

### Immediate Fix
- Deleted `frontend/public/sitemap.xml` (dead file, never served).
- Changed `backend/apps/catalog/sitemap.py` from `@require_GET` to
  `@require_http_methods(["GET", "HEAD"])` so the live endpoint stops
  405ing on HEAD.

### Long-term Fix
No further action: the dynamic sitemap is the sole source of truth and is
already covered by tests (`backend/apps/catalog/tests/test_product_detail.py`).

## Prevention
- [x] Code changes required (dead file removed, HEAD support added)
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Configuration changes needed

## Related Issues
- Supersedes/corrects: `chemglee-2026-09-30-missing-sitemap-and-seo-meta-tags.md`
  (the commit that reintroduced the static file)

## References
- `backend/apps/catalog/sitemap.py`
- `Caddyfile.prod`

---

**Resolved By:** Claude (Sonnet 5)
**Time to Resolution:** 20m
