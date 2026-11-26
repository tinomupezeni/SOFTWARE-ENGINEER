# SWAP-O-SELL — Frontend Hooks / Non-obvious Implementation Notes

**Last updated:** 2026-11-26

## Admin SPA under `/admin/` base path needs an Nginx config that serves real asset paths, not blanket SPA-fallback
The admin production image previously fell back to `index.html` for *any*
unmatched path, including requests for its own JS/CSS asset files under
`/admin/assets/...` — the server returned HTTP 200 with
`Content-Type: text/html` for a `.js` request, which the browser then
refused to execute as a module (`Unexpected token '<'`), producing a blank
page. If re-touching the admin Nginx config, the SPA fallback (`try_files
... /index.html`) must not catch real built asset paths. See
`DevOps_and_Infrastructure/SWAP-O-SELL-2026-11-04-admin-spa-blank-page-under-admin-base-path.md`.

## Favicon resolution falls back to the domain root, not just the current app
Any app with no explicit `<link rel="icon">` (the admin SPA, historically)
will have the browser implicitly fetch `/favicon.ico` from the domain
root — which, behind a shared reverse proxy routing `/admin/*` and `/*` to
different containers, actually resolves to whatever the storefront serves
at its root, not anything admin-specific. The storefront still had the
original Lovable.dev scaffold favicon sitting in
`swappify-social-hub/public/favicon.ico`, so the admin app silently
inherited it. Fixed by giving the admin app (and replacing the storefront)
its own explicit icon. See
`Frontend_and_UI/SWAP-O-SELL-2026-11-04-admin-inherits-lovable-favicon-via-domain-root-fallback.md`.

## `ProductDetail.tsx` has no static/demo fallback by design
Do not reintroduce a `sampleProducts`-style static fallback here — a
missing/failed API response must render an explicit loading/not-found
state. This was a deliberate removal during the UUID migration, not an
oversight to "fix" by restoring it.
