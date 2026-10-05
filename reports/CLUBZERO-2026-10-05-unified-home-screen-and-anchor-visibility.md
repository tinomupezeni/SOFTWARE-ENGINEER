# Club Zero: unified cross-club Home screen + visible anchor affordance

**Date:** 2026-10-05
**Project:** Club Zero
**Type:** Architecture change (navigation/IA restructure) + UX fix
**Status:** Completed — backend verified (new endpoint smoke-tested, full pytest suite green), mobile verified via `flutter analyze` (zero errors) and confirmed working end-to-end on a physical device (the new `GET /clubs/me/habits-today` endpoint was hit successfully, and an anchor edit via the new affordance succeeded, both observed live in backend logs during the user's own on-device testing).

## Summary
Following the same-day habit-anchors feature completion, the user gave
two pieces of direct feedback from actually using the app: (1) the
long-press gesture to edit a habit's anchor had no visible affordance —
nothing on screen hinted it existed — and (2) having to scroll between
separate per-club dashboards to see all of today's habits was the wrong
shape; they wanted every habit across every club unified onto one Home
screen, each tagged with its club, with one combined tracking grid. Both
were implemented this session: a visible "+ Add a cue" prompt replacing
the silent long-press-only affordance, and a full restructure splitting
the old per-club dashboard into a new cross-club Home screen (habit
tracking) and a separate per-club detail screen (seats, stakes,
momentum), reached from the Clubs tab.

## Context / Trigger
Direct user feedback after installing and trying the just-shipped
habit-anchors feature on a physical device: "they should have to long
press, on its should be a need highlighted that they should add it, also
instead of a user on home page having to scroll different clubs let all
club habits be in the same home screen we just kinda tag each with which
club the task is from, and we have 1 grid to track." The seats/stakes/
challenge placement question (what happens to those per-club social
features once Home stops being per-club) was explicitly asked back to the
user before implementing, since it's a real information-architecture fork
with no safe default to guess — user chose moving them to the Clubs tab.

## Scope
**Included:**
- Visible, always-on affordance for adding/editing a habit's anchor
  (`daily_habit_card.dart`), not just a hidden long-press.
- New backend endpoint (`GET /clubs/me/habits-today`) flattening every
  habit across every club the user belongs to, tagged with its club,
  with completion status, personal anchor, and one unified 30-day
  intensity grid.
- New `HomeProvider` + `HomeScreen` — the unified cross-club Home tab:
  load header, one combined momentum grid, the flattened/tagged habit
  list, per-club "4th habit" guidance, a club-picker in the add-habit
  flow, and one "complete all remaining" action spanning every club.
- New `ClubDetailScreen` (reached by tapping the active club in the
  Clubs tab) carrying forward the old per-club dashboard's seats row,
  stakes section, and 30-day momentum grid — `DashboardProvider` trimmed
  to match (habit-tracking state/methods moved to `HomeProvider`).

**Explicitly excluded:**
- Real-time cross-club updates on Home. The old per-club dashboard had a
  live WebSocket connection; Home now has none (connecting to every
  club's socket simultaneously from one unified screen is a bigger lift
  than this pass's scope). Home relies on an explicit fetch on open plus
  pull-to-refresh; `ClubDetailScreen` keeps its own per-club WebSocket
  exactly as before, so ambient awareness (seats lighting up live) is
  unaffected for anyone looking at a specific club's detail page.
- The "Start a Challenge" dialog, already dead/unreachable code before
  this session (no caller wired it up — a pre-existing gap, not
  introduced here). Carried forward as-is into neither new file; flagged
  as a known gap rather than fixed, since restoring or removing it is a
  separate decision from this redesign.
- Per-habit "done by" names on the unified Home list — the new flattened
  endpoint only returns the current user's own completion/anchor data
  (cross-club membership-list fan-out for "who else completed this" was
  out of scope); `DailyHabitCard` on Home always renders "No one
  completed yet" for that line as a result. Noted as a rough edge, not a
  silent gap.

## Method
Read the full current `dashboard_screen.dart` and `dashboard_provider.dart`
before touching anything, to separate the habit-tracking state/UI (moving
to Home) from the social state/UI (staying per-club in the new detail
screen) without losing any working functionality. Grepped for every
reference to the types being renamed/moved (`DashboardScreen`,
`DashboardProvider`) before deleting the old file, to confirm the only
remaining consumer after rewiring was the file itself. Verified the
backend addition with a direct smoke test (two clubs, cross-club fetch,
one completion, re-fetch) before touching any mobile code, so the mobile
rewrite was built against already-confirmed-correct data rather than
guessing the shape would work.

## Decisions & Findings

**Seats/stakes/challenges move to the Clubs tab, not a condensed Home
summary.** Put directly to the user as a fork with no safe default (Home
losing its "who's around" ambient awareness entirely vs. keeping a
condensed version cluttering the new unified list) — user chose the
clean split: Home is now pure personal cross-club habit tracking, the
Clubs tab's existing "tap the active club" interaction (previously a
no-op) now opens the full social detail view.

**One new backend endpoint, not a client-side fan-out across existing
per-club ones.** `GET /clubs/me/habits-today` computes the flattened list
and the unified 30-day grid server-side in two or three queries total.
The alternative — the mobile client calling `GET /clubs/{id}/seats` once
per club and merging client-side — would mean N round trips scaling with
club count and no single source of truth for the "which day was fully
done" intensity math; doing it once, server-side, matches how the
existing per-club `/stats` endpoint already computes its own history.

**The unified grid reuses the per-club intensity scale (0/1/2) and
rounds down on ambiguity.** Per-day intensity = 0 (nothing done), 2 (every
currently-tracked habit done that day), 1 (otherwise) — using the
*current* total habit count as the denominator for all 30 days, same
simplification the existing per-club `/stats` endpoint already makes
(habit counts aren't tracked historically, so a habit added yesterday
can't be distinguished from one added a month ago without a bigger
schema change not in scope here).

**The "4th habit" guidance note is evaluated per club even though the
list itself is unified.** The spec's threshold is about one club's habit
count creeping up, not a cross-club total (that's the separate "6+
across clubs" load-header note) — flattening the list doesn't change
what the note is actually measuring, so `HomeProvider.habitCountByClub`
groups the flattened list back by club internally just for this check.
Only the first qualifying, non-dismissed club's note is shown at a time
to avoid stacking multiple notes on one screen.

## Changes Made
**Backend** (`club-zero-backend/app/routers/clubs.py`): new
`GET /clubs/me/habits-today` endpoint.

**Mobile** (`club_zero_mobile/lib/`):
- New: `providers/home_provider.dart`, `screens/home_screen.dart`,
  `screens/club_detail_screen.dart`.
- Deleted: `screens/dashboard_screen.dart` (fully superseded —
  confirmed via grep that nothing else referenced it before removal).
- Trimmed: `providers/dashboard_provider.dart` (removed habit-list state/
  methods and the cross-club load-header state that both moved to
  `HomeProvider`; kept seats/members/challenge/stakes/momentum/WebSocket).
- Rewired: `screens/main_layout.dart` (Home tab → `HomeScreen`),
  `screens/clubs_screen.dart` (tapping the already-active club now opens
  `ClubDetailScreen` instead of being a no-op).
- `widgets/daily_habit_card.dart`: the anchor subtitle row is now always
  rendered (not conditionally hidden when empty) — shows "→ after
  {anchor}" when set, or a dimmed, italic "+ Add a cue — do this after…"
  prompt when not, independently tappable (not just reachable via the
  card's long-press).

## Verification
- `python3 -m py_compile` clean on the backend; full `pytest` suite
  still 42 passed after the new endpoint was added.
- Direct smoke test of `GET /clubs/me/habits-today`: created two clubs
  with one habit each, confirmed the flattened response correctly tagged
  each habit with its club name, confirmed completing one habit updated
  both its own `completed` flag and the unified `history` grid's final
  day to the correct intensity.
- `flutter analyze lib/` across the whole project: 0 errors; new/touched
  files show only the same pre-existing `withOpacity`-deprecation class
  of info notices already present elsewhere in the codebase.
- Confirmed via `grep` that no remaining code referenced the deleted
  `DashboardScreen`/`DashboardProvider` symbols before and after the
  trim, and that `DashboardSeatsRow` (which reads `DashboardProvider` via
  `Provider.of`) is only ever built inside `ClubDetailScreen`, where that
  provider is actually supplied.
- Live on-device confirmation (the user's own testing, observed via
  backend logs): clean app launch with no crashes, `GET
  /clubs/me/habits-today` called and returned 200, and a `PUT
  .../habits/{id}/anchor` call succeeded — meaning the new Home screen
  loaded real data and the anchor-editing affordance was used
  successfully, not just compiled cleanly.

## Follow-ups / Deferred
- **Real-time updates on Home** — currently fetch-on-open plus pull-to-
  refresh only; no live WebSocket for the unified cross-club view (see
  Scope). Worth revisiting if habit completions from other devices/
  sessions need to appear without a manual refresh.
- **"Done by" names on Home's habit cards** — currently always empty;
  would need the new endpoint to also fan out per-habit club-membership
  completion data, which this pass deliberately kept out of scope to
  keep the query cost down.
- **The orphaned "Start a Challenge" dialog** — still dead code, still
  not this session's to fix, but now living in `club_detail_screen.dart`
  rather than the deleted `dashboard_screen.dart`. Worth a deliberate
  decision (wire it up, or delete it) in a future pass.
- **`DEVLOG.md`** — not updated as part of this report; already flagged
  as significantly stale in the prior habit-anchors report from earlier
  today, and this change adds to that gap rather than closing it.

## References
- `SOFTWARE-ENGINEER/reports/CLUBZERO-2026-10-05-habit-anchors-load-guidance-feature.md`
  — the same-day feature this redesign responds to and builds on.
- Commit on `main`, `Club-Zero` monorepo (pushed same session).

---

**Completed By:** Claude (Sonnet 5), for tinotendamupezeni@thuthuka.tech.
**Duration:** Single session, 2026-10-05, directly following the habit-anchors feature completion earlier the same day.
