# Admin Backend's /media/ 404'd Unconditionally Outside Local Dev

**Date:** 2026-09-29
**Project:** HBEC
**Environment:** Staging (found live; identical code runs in production)
**Severity:** Medium
**Status:** Resolved

## Summary
While wiring up the new email-branding feature's logo (served from Admin
Backend's `/media/` mount), the configured `logoUrl` returned a 404 on
staging despite the file genuinely existing in the container's media
volume. Root cause: `ADMIN/adminBackend/config/urls.py` gated Django's
media-serving route behind `if settings.DEBUG:` — but
`django.conf.urls.static.static()`, the helper used there, **already has
its own internal `if not settings.DEBUG: return []` check** baked into
Django itself. The external guard was redundant, and in `DEBUG=False`
(staging and production both), the inner check meant **no `/media/`
route existed in urls.py at all** — every request to it 404'd, silently,
in every environment except local dev, for as long as this pattern has
existed.

## Symptoms
- Any URL under `/media/` returns 404 on staging or production, even
  though nginx correctly proxies the request to Admin Backend and the
  file genuinely exists in the `admin_media_staging`/production media
  volume.
- `ADMIN/adminFrontend/nginx.conf`'s own comment on the `/media/` block
  says "Uploaded files (paper PDFs, mark schemes, logos) — Django serves
  from MEDIA_ROOT" — an assumption that was never actually true outside
  local dev.

## Environment Details
- **Server/Host:** hbca-vps, `hbec-admin-backend-staging` (production's
  `hbec-admin-backend` runs the identical, still-unfixed code until its
  own next deploy)
- **Services Affected:** Admin Backend's media serving — affects any
  feature relying on a public `/media/...` URL, not just this one
- **Related Components:** `ADMIN/adminBackend/config/urls.py`,
  `ADMIN/adminFrontend/nginx.conf`'s `/media/` location block
- **Time First Observed:** 2026-09-29, while verifying the email-branding
  feature's logo URL

## Investigation Steps

### 1. Initial Diagnosis
Placed a real file at the expected path
(`/app/media/branding/logo.svg`, a named Docker volume mounted into the
container) and requested its public URL directly — `curl` returned 404
with an HTML body, not the SVG.

### 2. Root Cause Analysis
Checked nginx's proxy for `/media/` (`adminFrontend/nginx.conf`) —
correctly forwards to `admin-backend:8000`. Checked Admin Backend's own
`config/urls.py`:
```python
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
```
Confirmed `settings.DEBUG` is `False` on staging (and production, by the
same settings module). Read Django's own `static()` implementation
(`django/conf/urls/static.py`): it returns `[]` immediately unless
`settings.DEBUG` is `True` — a safety mechanism specifically to stop
this shortcut being used carelessly in production. The external `if
settings.DEBUG:` check here was checking the same condition the helper
already checks internally — doubly redundant, and in the `False` case,
totally silent: no error, no log line, just an empty urlpatterns
contribution and a 404 for anyone hitting `/media/anything`.

### 3. Key Findings
- This is not new to the email-branding feature — it's a pre-existing
  gap that nothing had exercised in production/staging before, since
  question/diagram assets are deliberately served through dedicated
  endpoints backed by Postgres-stored bytes (see CLAUDE.md's own notes
  on `question_assets`/`revision_infographics`), not raw `MEDIA_ROOT`
  files. This feature was the first to actually need a plain
  `/media/`-served static file.
- Django's own documentation explicitly names `django.views.static.serve`
  as the supported way to keep serving media through Django itself
  outside `DEBUG`, when a real front-end server (nginx here) is the one
  proxying to it — exactly this deployment's shape.

## Root Cause
`config/urls.py` never actually wired up a `/media/` route for any
environment where `DEBUG=False`, because the `static()` helper used
there refuses to do anything outside `DEBUG` regardless of the
surrounding conditional.

## Prevention / Rule
**Guardrail:** any future addition that needs Admin Backend to serve a
static file publicly (another branding asset, an exported report, etc.)
now has a real, tested `/media/` route to rely on — `django.views.static
.serve`, wired unconditionally. Before adding a *new* Django URL helper
that's documented as "development only" (this class of helper is
usually named or documented as such), check whether it has its own
internal environment gate before also wrapping it in one — the
double-gate here is what made the failure completely silent instead of
at least being an obviously-intentional "disabled everywhere" choice.

## Solution

### Immediate Fix
Replaced the `static()`-based conditional with a direct,
unconditional `django.views.static.serve` route:
```python
urlpatterns += [
    re_path(r"^media/(?P<path>.*)$", serve, {"document_root": settings.MEDIA_ROOT}),
]
```
Verified live on staging: placed the real logo file in the media volume,
confirmed `https://staging-admin.hbca.tech/media/branding/logo.svg`
returns `200` with `content-type: image/svg+xml` and the correct file
content, after rebuilding and recreating `hbec-admin-backend-staging`.
Full `apps/system_settings` test suite (34 tests) still passes.

### Long-term Fix
None needed beyond the fix itself — acceptable at this app's actual media
volume (admin-uploaded documents and branding assets, not high-volume
public traffic), matching Django's own documented guidance for this
exact deployment shape.

## Prevention
- [x] Configuration changes needed — none beyond the URL fix
- [ ] Monitoring/alerts to add — none; any future regression here is a
  plain, immediately visible 404
- [x] Documentation to update — inline comment at the fix site explains
  the double-gate and why it was silent
- [x] Code changes required — done, staging verified; production still
  needs its own next Admin Backend deploy to pick this up

## Related Issues
- Found while implementing and verifying the email-branding feature (no
  separate report filed for that feature alone — it's a single, cohesive
  piece of work, this bug is incidental to it).

## References
- `ADMIN/adminBackend/config/urls.py`
- `ADMIN/adminFrontend/nginx.conf` (`/media/` location block)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session as discovery; staging verified,
production still needs its own deploy
