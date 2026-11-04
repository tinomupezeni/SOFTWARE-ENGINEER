# Bare hbca.tech/vlabs (no trailing slash) showed the landing page's own 404

**Date:** 2026-11-04
**Project:** LEC Virtual Labs
**Environment:** Production (`hbca-vps`), reported live by the user minutes after go-live
**Severity:** Medium (the exact URL most people would actually type/share was broken; every
in-app link and the curl verification done before cutover used a trailing slash, so this
was missed)
**Status:** Resolved

## Summary
Right after `hbca.tech/vlabs` went live (see `ADR-004-vps-bluegreen-deployment.md`), the
user reported `hbca.tech/vlabs` (no trailing slash) showing "Oops! Page not found." The
Caddy routing added for VLabs used `handle_path /vlabs/*`, which requires a literal
trailing slash after `vlabs` to match at all — the bare path doesn't match it, and fell
through to the catch-all `handle {}` block that proxies to the HBCA landing page. That
landing page is *itself* a client-routed SPA: it has no `/vlabs` route either, so its own
router rendered its own 404 component — while the server still returned a plain `200`,
making it a soft 404 that every status-code-only check (including this session's own
pre-cutover `curl -o /dev/null -w '%{http_code}'` checks, which all used a trailing slash)
would miss.

## Symptoms
- User visited `https://hbca.tech/vlabs` and saw the HBCA landing page's "Oops! Page not
  found. Return to Home" screen, not VLabs.
- `curl -I https://hbca.tech/vlabs` returned `200`, masking the problem until the actual
  response body was inspected — it was the landing page's `index.html`
  (`<title>HBCA — Learn Your Heritage...</title>`), not VLabs'.

## Environment Details
- **Server/Host:** `hbca-vps`, shared `hbec-gateway` Caddy container
- **Services Affected:** VLabs only, and only for URLs with no trailing path segment after
  `/vlabs` — `/vlabs/`, `/vlabs/login`, `/vlabs/dashboard`, etc. were all already correct
- **Related Components:** `HBEC/scripts/deploy/render-caddyfile.sh` (the shared Caddyfile
  generator), the HBCA landing page container (a separate SPA, `172.17.0.1:1577`)
- **Time First Observed:** 2026-11-04, minutes after cutover, reported directly by the user

## Investigation Steps

### 1. Initial Diagnosis
Re-ran the exact same checks from the pre-cutover verification, this time against the
bare path instead of the trailing-slash one: `curl -s https://hbca.tech/vlabs | head -c
2000` showed HBCA's own landing-page markup, not VLabs'.

### 2. Root Cause Analysis
Caddy's `handle_path /vlabs/*` matcher requires the request path to literally start with
`/vlabs/` — a bare `/vlabs` (no trailing slash, no further segments) does not match a
`/vlabs/*` glob. Caddy's `handle` blocks are mutually exclusive and evaluated in
declaration order, so a non-matching request simply falls through to the next one — in
this case, the unconditional `handle {}` catch-all that proxies to the landing page.

### 3. Key Findings
- This session's own pre-cutover verification used `https://hbca.tech/vlabs/` (with
  trailing slash) throughout — a reasonable default, but it meant the one broken variant
  was never actually exercised before going live.
- The landing page returning `200` for its own unmatched route is itself unremarkable
  (completely normal SPA behavior) — the bug was entirely in VLabs' own Caddy routing not
  accounting for the no-trailing-slash form of its own URL.

## Root Cause
`handle_path /vlabs/*` has no companion rule for the bare `/vlabs` path, so that one exact
URL variant silently fell through to an unrelated app's own catch-all.

## Solution

### Immediate Fix
Added `redir /vlabs /vlabs/ 308` to the `hbca.tech, www.hbca.tech` block in
`HBEC/scripts/deploy/render-caddyfile.sh`, placed before the VLabs `handle`/`handle_path`
blocks (Caddy's default directive order runs `redir` before `handle`, so this is
unconditionally evaluated first). Committed and pushed in the HBEC repo, applied to the
live `/opt/hbec` checkout via a scoped `git checkout <commit> -- <path>` (the user declined
a blind `git pull`/cherry-pick here, correctly, given `/opt/hbec`'s working tree already
carries unrelated uncommitted work — only this one file was touched), then re-ran
`render-caddyfile.sh` and verified: `curl -I https://hbca.tech/vlabs` → `308` →
`/vlabs/` → real VLabs content. All `*.hbca.tech` domains and the `/labs/*` passthrough
reconfirmed unaffected.

### Long-term Fix
None needed beyond the one-line `redir` — this is now correct for every path shape.

## Prevention
- [x] `render-caddyfile.sh` now redirects the bare path before any `handle` matching
- [ ] Future pre-cutover verification for any path-prefixed route should explicitly test
      the bare prefix (no trailing slash) in addition to the prefix-with-slash and a
      deeper sub-route, not just the one form that happens to be convenient to curl

## Related Issues
- Same deploy session as `LEC-2026-11-04-nginx-xforwardedproto-redirect-loop.md` and
  `LEC-2026-11-04-backend-healthcheck-disallowedhost.md` — all three are instances of the
  same lesson: a status-code-only check can miss a soft failure (wrong body, wrong app)
  that a full response inspection catches immediately.

## References
- `HBEC/scripts/deploy/render-caddyfile.sh`
- `LEC_virtual_labs/intelligent_memory_management/decisions/ADR-004-vps-bluegreen-deployment.md`

---

**Resolved By:** Claude Sonnet 5 (Claude Code session)
**Time to Resolution:** <15 minutes from user report to verified fix live.
