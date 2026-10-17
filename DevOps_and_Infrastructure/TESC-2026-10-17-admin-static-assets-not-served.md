# Admin Static Assets Not Served Through Staging Gateway

**Date:** 2026-10-17
**Project:** TESC
**Environment:** Staging
**Severity:** Medium
**Status:** Resolved

## Summary

The newly deployed Django admin dashboard loaded through the staging gateway,
but its custom CSS returned HTTP 404. Nginx proxied `/static/` requests to
Gunicorn, which does not serve Django static files, and the backend static
directory was not mounted into nginx.

## Symptoms

- `GET https://tesc-staging.zchpc.ac.zw/admin/login/` returned 200.
- `GET https://tesc-staging.zchpc.ac.zw/admin/operations/` correctly redirected
  unauthenticated users to the login page.
- `GET /static/admin/tesc_admin.css` returned 404.
- The admin page therefore rendered without the intended white/blue theme.

## Environment Details

- **Server/Host:** staging `10.50.1.37`
- **Services Affected:** `tesc-nginx-1`, Django admin frontend
- **Related Components:** `nginx/nginx.conf`, `docker-compose.prod.yml`,
  Django `STATIC_ROOT`
- **Time First Observed:** 2026-10-17

## Investigation Steps

### 1. Initial Diagnosis

Ran the admin route and static asset smoke checks after deploying the
dashboard. Confirmed the CSS file existed after `collectstatic` inside the
backend container, while the public URL still returned 404.

### 2. Root Cause Analysis

The nginx configuration routed `/static/` to `backend:8000`. Gunicorn served
application requests but did not serve static files. The nginx container had
only its configuration mounted and could not read the backend
`staticfiles/` directory.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' \
  https://tesc-staging.zchpc.ac.zw/static/admin/tesc_admin.css
```

## Root Cause

Static-file serving was configured as an upstream proxy rather than as a
read-only nginx filesystem alias, and the static build output was not shared
with nginx.

## Prevention / Rule

**Guardrail:** Every deployment smoke test must request one known custom static
asset through the public gateway and require HTTP 200 with the expected
content type before the release is considered verified.

This catches the exact failure mode where application routes are healthy but
the deployed UI is missing its CSS or JavaScript.

## Solution

### Immediate Fix

- Ran `python manage.py collectstatic --noinput`.
- Mounted `./backend/staticfiles` read-only into nginx.
- Changed nginx `/static/` handling to an `alias` for the mounted directory.
- Recreated nginx and verified its configuration with `nginx -t`.

### Long-term Fix

- Add the public static-asset check to the staging deployment verification
  script or CI release gate.
- Keep static output generation and nginx sharing explicit in the Compose
  deployment contract.

## Prevention

- [x] Add a deployment-window static asset smoke check
- [x] Serve collected assets from nginx
- [ ] Add the check to automated staging release verification

## Related Issues

- None.

## References

- `nginx/nginx.conf`
- `docker-compose.prod.yml`
- `backend/core/settings.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same deployment session
