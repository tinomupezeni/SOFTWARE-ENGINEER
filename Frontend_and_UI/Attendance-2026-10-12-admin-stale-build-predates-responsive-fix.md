# Admin dashboard sidebar rendered above the content, not beside it — the compiled CSS bundle predated the "mobile responsive" fix by two days

**Date:** 2026-10-12
**Project:** Attendance (Verified Attendance Platform)
**Environment:** Development
**Severity:** High — the entire dashboard layout (sidebar + header + content) was visibly broken for every page
**Status:** Resolved

## Summary
The admin dashboard's sidebar was rendering stacked above the hero/content
area instead of beside it, as a vertical block spanning the full width. The
layout markup itself (`resources/views/layouts/app.blade.php`) was correct —
it uses a flex container with the sidebar as a flex child (`md:relative
md:translate-x-0`) — but the compiled CSS in `public/build/` was built
2026-10-04, two days *before* commit `8e43f1a` ("Make the admin dashboard
mobile responsive", 2026-10-06) that introduced this exact flex/responsive
layout. The container serving the dashboard (`admin/Dockerfile`, dev image)
never runs `npm run build`; it just serves whatever static bundle happens to
be sitting in the volume-mounted `public/build/` directory, so the browser
was loading CSS from before the responsive rewrite — missing the utility
classes the current markup depends on.

## Symptoms
- Dashboard pages (reported from the login/dashboard area) showed the
  sidebar navigation displayed above the main content instead of as a
  left-hand column alongside it — effectively unstyled block stacking.
- No errors in Laravel logs or FastAPI backend logs; this was a pure
  front-end asset staleness issue, invisible to server-side log inspection.

## Environment Details
- **Server/Host:** Local dev, `attendance-admin-1` Docker container
  (Laravel dev server, volume-mounted source).
- **Services Affected:** `admin/public/build/` (compiled Vite bundle),
  `admin/resources/views/layouts/app.blade.php` (consumer of the bundle).
- **Time First Observed:** 2026-10-12, reported while using the dashboard
  live during this session's mobile app testing.

## Investigation Steps

### 1. Initial Diagnosis
Read `layouts/app.blade.php` first, since the report described a layout
bug — the flex/sidebar markup looked correct on inspection, which ruled out
a markup logic error and pointed at the compiled CSS not matching the
markup.

### 2. Root Cause Analysis
```
$ ls -la admin/public/build/        # mtime: 2026-10-04 17:47
$ git log --oneline -5 --date=format:"%Y-%m-%d %H:%M"
8e43f1a 2026-10-06 19:57 Make the admin dashboard mobile responsive
```
The compiled bundle predates the commit that introduced the responsive
layout classes it's supposed to style. `admin/Dockerfile` (the dev image
used by `docker-compose.yml`) only runs `php artisan serve`; it never runs
`npm run build`, and relies entirely on whatever static files are already
in the volume-mounted `public/build/` directory.

### 3. Key Findings
- This is a build-pipeline gap, not a code bug: nothing in the dev
  workflow (or this container) rebuilds front-end assets when Blade/Tailwind
  source changes, so a stale bundle can silently outlive the markup changes
  it no longer matches.
- Running `npm run build` locally (assets are volume-mounted into the
  container) immediately fixed the rendering — confirming the markup itself
  was never the problem.

## Root Cause
`public/build/`'s compiled CSS/JS was two days older than the Blade layout
changes that depend on it, and nothing in the dev container or workflow
rebuilds Vite assets automatically when template/Tailwind source changes.

## Prevention / Rule
**Guardrail:** Add a `npm run build` (or `vite build --watch` for local dev)
step to whatever onboarding/dev-up script or `docker-compose.yml` command
brings up the admin service, so compiled assets can't drift from the
templates that reference their generated class names. At minimum, document
in `admin/README.md`/`CLAUDE.md` that `npm run build` must be re-run after
any `resources/` change, since the dev Docker image does not do this
automatically.

This closes the gap because the previous failure mode (silent staleness,
no error anywhere) only shows up as a visual regression — there is no log
line or exception to catch it mechanically without either a build step or
a documented habit.

## Solution

### Immediate Fix
Ran `npm run build` in `admin/` (host side, volume-mounted into the
container), producing a fresh `app-HVEbFXsQ.css` bundle reflecting the
current responsive layout. Verified via `curl -s http://localhost:8080/login
| grep -o 'app-[A-Za-z0-9]*\.css'` that the served page now references the
newly built hash.

### Long-term Fix
Add an `npm run build` step to the admin service's startup (entrypoint
script) or document it as a required step after pulling template/CSS
changes in local dev. Not done in this pass — the production
`docker-entrypoint.production.sh`/`Dockerfile.production` path should be
checked separately to confirm production deploys do run the build step
(this bug was specific to the dev `Dockerfile`).

## Prevention
- [x] Rebuild the stale asset bundle
- [ ] Add an automatic asset-build step to the dev Docker workflow
- [ ] Document the manual `npm run build` requirement in `admin/README.md`

## Related Issues
- None filed yet.

## References
- `admin/resources/views/layouts/app.blade.php`
- `admin/public/build/`
- `admin/Dockerfile`

---

**Resolved By:** Claude (Sonnet 5), found and fixed same-session for tinotendamupezeni@thuthuka.tech.
**Time to Resolution:** Same session as discovery, 2026-10-12.
