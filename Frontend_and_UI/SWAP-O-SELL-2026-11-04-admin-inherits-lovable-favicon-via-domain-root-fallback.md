# Admin app silently inherited the storefront's leftover Lovable scaffold favicon

**Date:** 2026-11-04
**Project:** SWAP-O-SELL
**Environment:** Production/Development
**Severity:** Low
**Status:** Resolved

## Summary
The user reported the admin app showing "the lovable icon" in the browser
tab. The admin app has no favicon of its own and never referenced one —
the icon it was showing came from a leftover `favicon.ico` in the
storefront app's `public/` folder (the default favicon shipped by the
Lovable.dev scaffold this project was originally bootstrapped from), which
browsers fetch implicitly from the domain root whenever a page has no
explicit `<link rel="icon">`.

## Symptoms
- Browser tab for the admin app (served at `/admin/` behind a shared
  reverse proxy with the storefront) showed a heart/flame gradient icon
  instead of any Swap-O-Sell branding.

## Environment Details
- **Server/Host:** any deployment routing storefront + admin behind the
  same domain (mywealth-vm, confirmed; same applies to restk-vps)
- **Services Affected:** `admin`
- **Related Components:** `admin/index.html` (no icon link),
  `swappify-social-hub/public/favicon.ico` (leftover Lovable asset)
- **Time First Observed:** 2026-11-04, reported by the user after visiting
  the admin app

## Investigation Steps

### 1. Initial Diagnosis
```bash
grep -ril lovable . | grep -v node_modules
# -> swappify-social-hub/package.json, package-lock.json, README.md, vite.config.ts
```
No "lovable" string anywhere in `admin/`. So the icon wasn't coming from
admin's own code.

### 2. Root Cause Analysis
```bash
cat admin/index.html   # no <link rel="icon"> at all
```
Browsers that find no icon `<link>` on a page fall back to requesting
`/favicon.ico` at the site root. Under the new shared reverse-proxy setup
(domain root → storefront container, `/admin/` → admin container),
`/favicon.ico` at the domain root is served by the **storefront**
container, not admin's own. Checked what that file actually was:
```python
from PIL import Image
Image.open('swappify-social-hub/public/favicon.ico').save('/tmp/preview.png')
```
It rendered as the Lovable.dev logo (heart/flame gradient) — an unused
leftover from when the storefront project was scaffolded via Lovable,
never replaced with real branding, and never referenced explicitly by
`swappify-social-hub/index.html` either (which does correctly set its own
icon via `<link rel="icon" href="/logo.png">`, overriding the implicit
fallback for itself only).

### 3. Key Findings
- The storefront was never visibly affected, because its own explicit
  `<link rel="icon">` always wins over the implicit domain-root fallback.
- Admin was affected purely because it had no icon link of its own, so it
  fell through to the implicit browser fallback, which under the new
  shared-domain routing resolved to a different app's leftover asset.
- This would not have been visible before the two apps were routed under
  one shared domain (previously admin was on its own port/origin with its
  own implicit-fallback 404, not a cross-app leak).

## Root Cause
`admin/index.html` never declared an icon, relying on implicit
browser/CDN fallback behavior that happened to resolve to an unrelated
app's unused scaffold asset once both apps shared a domain.

## Prevention / Rule
**Guardrail:** Every app with its own `index.html` must declare an
explicit `<link rel="icon">` — never rely on the implicit `/favicon.ico`
browser fallback, since its resolution target depends on whatever else is
mounted at the domain root, which is reverse-proxy topology, not something
the app controls.

## Solution

### Immediate Fix
- Generated a new brand icon (gradient "S" mark matching the existing
  `Logo.tsx` wordmark palette) and used it as both apps' `favicon.ico` /
  `logo.png`.
- Added an explicit `<link rel="icon" href="/admin/logo.png">` (and
  `apple-touch-icon`) to `admin/index.html`, matching admin's `/admin/`
  base path so it resolves correctly rather than depending on domain-root
  fallback.
- Replaced the leftover Lovable `favicon.ico` in
  `swappify-social-hub/public/` with the same new brand icon, so even the
  implicit fallback (for any future page that forgets its own icon link)
  resolves to real branding instead of scaffold leftovers.
- Rebuilt and redeployed both apps to mywealth-vm; verified locally that
  `admin/dist` places the icon at `/admin/logo.png` matching the
  production container's served path.

### Long-term Fix
Applied as the immediate fix.

## Prevention
- [x] Code changes required — `admin/index.html`, both apps' favicon/logo
      assets
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a
- [ ] Documentation to update — n/a

## Related Issues
- Same session as the `/admin/` base-path blank-page fix
  (`DevOps_and_Infrastructure/SWAP-O-SELL-2026-11-04-admin-spa-blank-page-under-admin-base-path.md`)
  — both are consequences of admin never having its own explicit,
  base-path-aware asset references.

## References
- `admin/index.html`
- `swappify-social-hub/public/favicon.ico`, `swappify-social-hub/index.html`
- `swappify-social-hub/src/components/Logo.tsx` (brand palette source)

---

**Resolved By:** Claude (session with tinomupezeni)
**Time to Resolution:** ~20 minutes
