# school_dashboard's production image runs the Vite dev server, not a built app

**Date:** 2026-11-16
**Project:** HBEC
**Environment:** Development source review
**Severity:** Medium
**Status:** Investigating — deliberately not fixed this session

## Summary
`SCHOOLS/school_dashboard/Dockerfile`'s `CMD` is
`["npm", "run", "dev", "--", "--host", "0.0.0.0"]`, i.e. the production
image runs Vite's development server, not a production build. `package.json`
has `"build": "vite build"` and `"preview": "vite preview"` scripts that are
never used anywhere in the image.

## Symptoms
- None reported — found while adding a `healthcheck:` to this service
  (`HBEC-2026-11-16-schools-deploy-verification-gaps.md`) and reading the
  Dockerfile to pick a target port.

## Environment Details
- **Server/Host:** Local checkout.
- **Services Affected:** DevOps/Infrastructure, Frontend/UI (production
  serving characteristics of the school dashboard).
- **Related Components:** `SCHOOLS/school_dashboard/Dockerfile`,
  `SCHOOLS/school_dashboard/package.json`,
  `SCHOOLS/school_dashboard/vite.config.ts` (uses
  `@lovable.dev/vite-tanstack-config` with TanStack Start's `nitro` builder,
  default preset `cloudflare`).

## Investigation Steps

### 1. Initial Diagnosis
Read the Dockerfile while wiring a Docker healthcheck for this service and
noticed `CMD` runs `npm run dev`, unlike every other frontend's Dockerfile
in this repo (which build then serve a static/SSR bundle).

### 2. Root Cause Analysis
Not fully investigated — this app is TanStack Start (SSR, built via Nitro)
scaffolded by Lovable, and `vite.config.ts`'s own comment notes the bundler
plugin defaults Nitro's build target to the `cloudflare` preset. Whether
`vite build` out of the box produces a Node-servable artifact for this
Dockerfile's `node:22-alpine` base, or needs an explicit Nitro preset
override first, was not verified.

### 3. Key Findings
- A dev server is slower, serves unminified assets, and is not the
  artifact this app's own `README`/scripts imply should ship
  (`build`/`preview` exist and are unused).
- Changing `CMD` without first confirming the Nitro build target produces a
  servable artifact on this exact base image risks breaking the one
  dashboard a school's non-technical staff use, with no way to verify the
  fix in this review (no access to actually build/run the image).

## Root Cause
Not fully determined — plausibly an artifact of this app being Lovable-
scaffolded and never adjusted for the Dockerfile it was given, but the
Nitro/Cloudflare-preset question above needs answering before concluding
that `vite build` + `preview`/a Node entry is a safe drop-in replacement.

## Prevention / Rule
**Guardrail:** none implemented yet — this needs someone who can actually
build and run the image (or a CI job that does) to verify a production
`CMD` change before it ships, given the Nitro preset uncertainty above.

## Solution

### Immediate Fix
None. Flagged rather than changed, to avoid guessing at a production
runtime change for an app whose build artifact shape couldn't be verified
in this environment.

### Long-term Fix
Determine whether `vite.config.ts`'s `tanstackStart.server.entry: "server"`
(pointing at `src/server.ts`) combined with `vite build` produces a
Node-servable Nitro output on `node:22-alpine`, update the Dockerfile to
build then run that artifact (or `vite preview` if SSR isn't required),
and verify in a real container build before merging.

## Prevention
- [ ] Determine the correct production `CMD` for this TanStack Start app.
- [ ] Add a CI job that builds this image and smoke-tests the result, so a
      regression here is caught automatically going forward.

## Related Issues
- `HBEC-2026-11-16-schools-deploy-verification-gaps.md` — found while
  closing a related gap on the same service.

## References
- `SCHOOLS/school_dashboard/Dockerfile`
- `SCHOOLS/school_dashboard/package.json`
- `SCHOOLS/school_dashboard/vite.config.ts`

---

**Resolved By:** Not yet resolved — flagged for follow-up
**Time to Resolution:** Pending
