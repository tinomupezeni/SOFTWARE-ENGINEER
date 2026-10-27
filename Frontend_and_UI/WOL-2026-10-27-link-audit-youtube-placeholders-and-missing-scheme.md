# Link Audit: Placeholder YouTube Links, and a Live Broken Outbound Link from a Missing URL Scheme

**Date:** 2026-10-27
**Project:** Wifing Out Loud (WOL)
**Environment:** Production (single environment, no staging)
**Severity:** Medium (Broken Outbound Links)
**Status:** Resolved

## Summary
ProjectFlow task "Link Audit" ("comprehensive audit of all links across the
site and app, including social media and outbound links"). Found two
distinct problems: three hardcoded placeholder YouTube links that never
pointed at the actual channel/show, and — found only by checking the real
production data — a live, currently-broken "Listen on YouTube" button
caused by a stored admin setting missing its URL scheme.

## Symptoms
- The "Watch Episodes" button on the Podcasts page, and the "YouTube
  Channel" button on the Rudo neKutenda page, both pointed at the bare
  `https://youtube.com` homepage rather than the actual show.
- The sitewide "Listen on YouTube" button (rendered from the
  `podcast_platforms` admin setting via `PlatformLinks.tsx`) silently did
  *not* leave the site at all: its stored URL was
  `"www.youtube.com/@WIFINGOUTLOUD"` with no `https://` prefix, so the
  browser resolved it as a path relative to the current page
  (`https://wifingoutloud.com/www.youtube.com/@WIFINGOUTLOUD`) — a 404 on
  the site's own domain, not a trip to YouTube.

## Root Cause
1. Three placeholder values in `frontend/src/lib/page-content.ts` and
   `frontend/src/lib/site-settings.ts`'s `DEFAULT_PODCAST_PLATFORMS` were
   never replaced with the real URLs.
2. The admin's Podcast Platforms settings editor
   (`frontend/src/routes/admin.tsx`, `PodcastPlatformsEditor`) has a plain
   free-text field for each platform's URL with no validation or
   normalization on save — an admin typing the address without `https://`
   (a completely reasonable thing to type) produced a value that renders
   fine in the editor but silently breaks on the public site, since
   `PlatformLinks.tsx` drops it straight into `href` with no scheme check.

## Solution
1. Updated the three placeholder links to the real URLs (main channel,
   "Wifing Out Loud Podcast" video/playlist, "Rudo neKutenda" playlist) —
   supplied in the ProjectFlow task description.
2. Added `normalizeUrl()` (`frontend/src/lib/site-settings.ts`): assumes
   `https://` for anything that isn't already an absolute URL, a same-page
   anchor, a site-relative path, or a `mailto:`/`tel:` link. Applied it in
   two places:
   - `visiblePlatforms()`, so every consumer of the podcast-platform list
     (the public "Listen on" buttons) gets a safe URL regardless of what's
     stored — fixes the *already-broken* production data without needing a
     second admin edit.
   - The admin editor's `save()`, so the stored value itself gets corrected
     going forward and an admin re-opening the settings page sees the real,
     working URL rather than the scheme-less one they originally typed.
3. Confirmed via direct SQL read against production
   (`site_settings` table, `podcast_platforms` key) that the live YouTube
   entry was indeed missing its scheme (Instagram's was fine, already
   stored with `https://`).

## Prevention / Rule
**Guardrail:** `normalizeUrl()` is applied at the one point every stored
platform URL passes through before reaching an `href` (`visiblePlatforms`),
so no future admin-entered or AI/migration-written URL can reach the public
site unscheme'd, regardless of how it got into storage. The admin editor's
`save()` also normalizing closes the gap for what's shown back to an admin
on reload.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (3 placeholder links + `normalizeUrl` guard in
  2 places)
- Worth a broader pass if other free-text URL fields exist elsewhere in the
  admin (e.g. page `buttons[].to`, site-wide social links if any are added
  later) — `normalizeUrl` is written generically enough to reuse.

---

**Resolved By:** Tinotenda Mupezeni (with Claude Code)
**Time to Resolution:** ~50 minutes
