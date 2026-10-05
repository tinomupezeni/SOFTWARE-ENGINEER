# Discover tab caches its club list forever — newly-public clubs never appear without a category-chip toggle

**Date:** 2026-10-05
**Project:** CLUBZERO
**Environment:** Development (physical Android test device + local backend)
**Severity:** Medium
**Status:** Investigating

## Summary

The mobile app's Discover tab fetches the public-club list exactly once and caches it in `_discoverable` for the rest of the screen's lifetime. Switching between MY CLUBS and DISCOVER does not refetch (`if (_discoverable == null) _loadDiscoverable()`), and there is no pull-to-refresh. So any club made public *after* the user first opened Discover — e.g. creating `take1`, opening Discover (empty), then flipping `take1` to public — never appears until something else incidentally triggers a reload (toggling a category chip). Reported as "my public club doesn't appear in discovery"; the backend correctly returns it.

## Symptoms

- User created club `take1`, set it `public`, opened the DISCOVER tab: `take1` not listed.
- Backend `GET /clubs/discover` (verified via curl as a non-member, no filter) correctly returns `take1` with `seats_open: 3`.
- DB confirms `take1.visibility = 'public'`.
- No error anywhere — backend right, app shows a confident empty state ("No open public clubs right now").

## Environment Details

- **Server/Host:** Local dev backend (`127.0.0.1:8001`, healthy) + physical test phone (SM-S906U1, wireless ADB)
- **Services Affected:** Flutter mobile app, Clubs tab → DISCOVER
- **Related Components:** `club_zero_mobile/lib/screens/clubs_screen.dart` (`_discoverable`, `_loadDiscoverable`, DISCOVER tab callback ~line 226–229)
- **Time First Observed:** 2026-10-05, user report during on-device testing

## Investigation Steps

### 1. Initial Diagnosis

Checked the data path bottom-up: DB row → endpoint → app, instead of assuming the endpoint was broken.

### 2. Root Cause Analysis

```bash
# DB: take1 IS public
docker exec club-zero-backend-db-1 psql -U postgres -d clubzero \
  -c "SELECT name, visibility, category FROM clubs;"
# take1 | public | (null)

# Endpoint as non-member: correct
curl /clubs/discover -H "Authorization: Bearer $TOKEN"
# [{"name":"take1",...,"seats_open":3}]
```

- App code: DISCOVER tab callback only loads `if (_discoverable == null)`; `_loadDiscoverable` is otherwise reachable only via category-chip change. No `RefreshIndicator`, no `didChangeDependencies`/focus refetch.
- Client-side `where` filter is search-text only (empty query matches everything) — not the cause.
- Compounding (not-the-bug but relevant): the reporter is `take1`'s creator/member, and the endpoint deliberately excludes own clubs (`if club.id in my_club_ids: continue`, by design per DEVLOG §7 step 12). Even with fresh data, the creator will never see their own club in Discover — verification must use a second/non-member account.

### 3. Key Findings

- Backend + DB fully exonerated by direct curl proof; this is a client caching bug.
- The empty state is misleading in exactly this scenario: it asserts "no open public clubs" when the truth is "list fetched before the club went public."
- Secondary data-shape note: `take1.category` is NULL. With the "All" chip (default, `category: null` → no server filter) this is harmless, but selecting any category chip hides all uncategorized clubs server-side (`Club.category == category` never matches NULL). Worth a product decision, not changed here.

## Root Cause

Discover results are fetched once per screen lifetime and never invalidated — no refetch on tab revisit, no manual refresh affordance — so the list goes stale the moment any club's visibility changes after first load.

## Prevention / Rule

**Guardrail:** Any screen showing server-derived lists that change due to out-of-band actions (another device, another tab, a settings change) must refetch on every revisit or expose pull-to-refresh — add it to the mobile UI checklist (alongside the empty/loading/error states the Stats tab already has per DEVLOG §4). A screen with only load-once + confident empty-state copy will always produce this exact false report.

## Solution

### Immediate Fix

Not yet applied (reported during testing; fix offered, awaiting owner direction since the reporter's own view is also affected by the by-design own-club exclusion). Minimal options, smallest first:

```dart
// clubs_screen.dart, DISCOVER tab callback — always reload on revisit:
tab("DISCOVER", _showDiscover, () {
  setState(() => _showDiscover = true);
  _loadDiscoverable();  // was: if (_discoverable == null) _loadDiscoverable();
});
```

Better (slightly larger): wrap the discover list in a `RefreshIndicator` calling `_loadDiscoverable`, keeping the cached-first paint.

### Long-term Fix

- Invalidate `_discoverable` after any local visibility change (the app knows when the user flips a club public — it can drop the cache then).
- Product call: creator's own public clubs in Discover (currently excluded by design), and whether uncategorized clubs should match every category filter or none.

## Prevention

- [ ] Refetch-on-revisit or pull-to-refresh for Discover (fix above)
- [ ] Decide NULL-category filter semantics (all vs. none)
- [ ] Two-account verify: creator + non-member, per DEVLOG §7 step 12, before closing

## Related Issues

- `Frontend_and_UI/CLUBZERO-2026-10-05-seats-row-orphan-fragment-build-failure.md` — same app, same day (build was broken before this could even be observed)
- `Backend_and_API/CLUBZERO-2026-10-05-*.md` (4 entries) — backend was down/un-startable; Discover correctness could only be verified after those fixes

## References

- `SharedHQ/club_zero_mobile/lib/screens/clubs_screen.dart` lines 47–53, 226–229, 392–410
- `SharedHQ/club-zero-backend/app/routers/clubs.py` `discover_clubs` (lines 48–99; own-club exclusion at 78–79)
- `SharedHQ/DEVLOG.md` §7 step 12 (two-account Discover verification script)

---

**Resolved By:** (pending — root cause proven, fix offered)
**Time to Resolution:** ~20m investigation
