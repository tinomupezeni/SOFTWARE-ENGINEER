# Club Zero: per-habit morale/nudge on Home, join-date-fair momentum grid, tappable widget

**Date:** 2026-10-05
**Project:** Club Zero
**Type:** Feature build + correctness fix, both from direct user feedback
**Status:** Completed — backend verified (full pytest suite green, direct smoke tests including a DB-level simulation of a new member joining a 40-day-old club), mobile verified via `flutter analyze` (zero new errors) and confirmed working end-to-end on a physical device (clean launch, widget re-render observed, new endpoints hit successfully in backend logs).

## Summary
Three related pieces of feedback, all from the same continued session on the
just-shipped unified Home screen: (1) show which club members have done a
habit today as a morale signal, and let the user nudge the ones who
haven't — directly from Home, not just from a club's own detail screen;
(2) a real correctness bug — a new member of an already-existing club saw
the days before they joined rendered as *missed*, and was scored against
them in their consistency percentage, which is actively discouraging for
exactly the people the app most needs to retain; (3) the momentum grid
should grow past its 30-day window once someone has more history, instead
of permanently forgetting it — capped at 50 days, per the user's explicit
choice. A fourth, smaller piece was added alongside: tapping the
home-screen widget now opens the app.

## Context / Trigger
Direct, sequential user messages following the unified-Home-screen work
earlier the same day:
1. "so on each habit since its a group/club what if we say a it also
   shows which club member is done with an activity kinda a morale thing,
   also possible to send that nudge from the home screen to other members
   who might not have done already"
2. "the grid itself, if i join an already existing club, my grid has to
   start from 0 cause its starting from the first log by me, also we show
   30 days, but after the 30 days, the grid we should kinda slide to the
   left revealing 2 more 20 days grid, we keep the last 10 days, for kinda
   moral so they dont feel like they are starting over" — clarified via a
   direct question (capped growth vs. unbounded) before implementing,
   since guessing wrong on the growth model would have meant a wasted
   backend + rendering rewrite; user chose capped at 50 days.
3. A follow-up question from the user mid-implementation: "wait so how do
   we handle the percentage on the widget and stats screen, as user goes
   beyond 30 days how then do we calculate" — answered with the
   applicable-days-denominator design before writing code, since this was
   a real design question, not a go-ahead.
4. "proceed also if a user clicks the widget let them get taken into the
   app."

## Scope
**Included:**
- `GET /clubs/me/habits-today` gains per-habit `completed_by` (every
  member who's done it today, not just the viewer) and a `clubs` map of
  member rosters, so the mobile client can compute "who hasn't done this
  yet" without a separate query.
- Home's habit cards now show real "Done by: X, Y" and a row of tappable
  "Nudge {name}" chips for not-yet-done members (excluding the viewer),
  reusing the existing per-day nudge endpoint and its existing
  "already nudged today" guard.
- Grid window grows from 30 to a 50-day cap once there's more than 30
  days of history (`_grid_window_size`, shared by both the unified and
  per-club endpoints).
- The hollow/future-cell cutoff and the consistency-percentage
  denominator both switched from "club creation date" to "the later of
  club creation and this user's own join date" (`since`) — fixes the new-
  member-of-an-old-club problem at its root, in both places it mattered.
- Native Android widget: tapping it now launches the app
  (`HomeWidgetLaunchIntent` → `MainActivity`).

**Explicitly excluded:**
- The widget's own visual grid does **not** grow past 30 cells — it
  always renders a trailing 30-day slice of whatever (possibly longer)
  history it's given, while its percentage still reflects the *full*
  applicable history. Deliberately two different scopes for a small,
  fixed-size glanceable image vs. a percentage that should mean the same
  thing everywhere; flagged to the user as the plan before building it,
  not assumed silently.
- iOS — the widget tap-to-open change is Android-only (`ClubWidgetProvider.kt`);
  no iOS widget target exists yet, consistent with the standing gap.
- Per-day historical accuracy for the habit-count denominator (a habit
  added last week vs. a month ago) — both grid endpoints still use the
  *current* total habit count for every day in the window, the same
  simplification already in place before this pass; not revisited here.

## Method
Before writing any code for the grid-growth ask, asked the user to choose
between capped and unbounded growth — the two have materially different
data/rendering implications (bounded fetch and a fixed-size trailing
window vs. unbounded storage and an ever-widening UI), and guessing wrong
would have meant redoing both the backend query and the mobile rendering.
Same for the percentage-calculation question the user asked mid-task:
answered with the design in plain terms first, let them confirm, then
implemented — rather than silently picking an interpretation.

Verified the join-date fix against a real multi-week scenario rather than
only same-day test data (which can't distinguish "joined today" from "club
created today" — both endpoints would trivially return `since == today`
either way). Directly backdated a club's `created_at` and one member's
`club_members.joined_at` by SQL in the local dev database to simulate a
genuinely old club with a brand-new member, then confirmed via the live
API that the new member's `since` correctly reflects *their* join date
(today) rather than the club's, while the existing member's grid
correctly grew to a 41-day window with a percentage computed only against
their own 41 applicable days.

## Decisions & Findings

**Nudging from Home reuses the existing per-club, per-day nudge
endpoint unchanged** — it was never habit-specific to begin with (one
push per person per club per day), and making it habit-specific would
have been a larger, unrequested redesign. The UI just surfaces the
existing action from a new place (each not-done member's chip on a
habit's card) and relies on the backend's existing "already nudged today"
409-style guard to prevent duplicate nudges across multiple habits in the
same club on the same day — surfaced to the user as a dimmed,
already-nudged chip state rather than a second error the first nudge
already implied.

**`since` is computed, not stored, and is per-request.** Rather than add
a new column anywhere, both endpoints compute it from data that already
exists (`ClubMember.joined_at`, `Club.created_at`) — for the unified
endpoint, the *earliest* join date across every club the user belongs to
(the first day they had anything at all to track); for the per-club
endpoint, the later of that one club's creation and this user's own
membership. No migration needed.

**The percentage fix was broader than originally asked.** The user's
report was about the grid's *visual* cells looking wrong for a new
member; fixing the math turned out to also fix a real, independent bug in
the *percentage* shown on both the widget and the Stats tab, which was
unconditionally dividing by a hardcoded 30 regardless of how long the
user had actually been trackable. That bug existed before any of this
session's grid-growth work — it would have under-scored any new member of
any club, at any point, even without the 30→50 growth feature. Worth
calling out explicitly rather than letting it blend into "the grid-growth
change" in retrospect, since it was a correctness fix in its own right.

## Changes Made
**Backend** (`club-zero-backend/app/routers/clubs.py`):
`_grid_window_size()` (shared 30→50-cap helper), `GET /clubs/me/habits-today`
now returns `completed_by` per habit, a `clubs` member-roster map, `since`,
and `consistency_score` (previously absent from this endpoint entirely);
`GET /clubs/{id}/stats` (`get_club_stats`) now computes `since` from the
later of club creation and the user's own `joined_at`, grows its window
the same way, and fixes its `consistency_score` to divide by applicable
days instead of a hardcoded 30.

**Mobile** (`club_zero_mobile/`):
`lib/widgets/momentum_day_cell.dart` (`futureCutoff` generalized to take
a `windowSize` and a generic `since` reference instead of a fixed 30 and
club-creation-only date), `lib/providers/home_provider.dart`
(`notDoneMembersFor()`, `nudge()`, `hasNudgedToday()`, parses `since`/
`consistency_score`/`completed_by`, passes a real score + 30-day slice to
the widget), `lib/screens/home_screen.dart` (real "Done by" names, nudge
chips per habit, dynamic-width momentum grid + percentage display),
`lib/screens/club_detail_screen.dart` and `lib/screens/stats_screen.dart`
(both switched to the dynamic window + `since`-based cutoff),
`lib/widgets/momentum_grid_widget.dart` / `lib/services/widget_service.dart`
(accept a precomputed score and `since` instead of recalculating with a
hardcoded 30), `android/.../ClubWidgetProvider.kt` (click `PendingIntent`
via `HomeWidgetLaunchIntent.getActivity` on the widget's image view).

## Verification
- Full `pytest` suite: 42 passed, unchanged, after both endpoint changes.
- Live smoke test (three real accounts, real HTTP calls): per-habit
  `completed_by` correctly shows a completion to *every* club member, not
  just the person who did it, with no cross-club leakage; `clubs` member
  rosters resolve correctly.
- Direct DB-level simulation of the exact scenario the user described: a
  club backdated 40 days, one member backdated to have joined with it,
  24 completions seeded across the last 35 days, a second member joined
  "today." Confirmed via the live API that the old member's window grew
  to 41 days with a 58% score (24/41, matching the seeded data exactly),
  and the new member's `since` is their own join date — not the club's —
  with their window staying at a plain 30 and their score correctly based
  on just the 1 day they've actually had.
- `flutter analyze lib/`: 0 errors across the whole project; touched
  files show only the same pre-existing `withOpacity`-deprecation class
  of notices already present elsewhere.
- On-device: clean launch (no crashes in `adb logcat`), the native widget
  re-rendered successfully (confirmed via its own debug log line) using
  the real backend data, and `GET /clubs/me/habits-today` /
  `GET /clubs/{id}/stats` were both observed hitting the backend from the
  live app session with `200 OK`.

**Not verified:** physically tapping the home-screen widget to confirm it
opens the app — this needs a human tapping the actual widget tile on the
device's home screen, which this session cannot do itself.

## Follow-ups / Deferred
- **Confirm the widget tap-to-launch works** by actually tapping it on
  the device — the code path (`HomeWidgetLaunchIntent` → `MainActivity`)
  is the standard, documented pattern for this plugin version and the
  native build compiled and installed cleanly, but it hasn't been
  physically tapped yet.
- **Per-day historical habit-count accuracy** — both grid endpoints still
  use the *current* habit count as the denominator for every day in the
  window; a habit added yesterday is indistinguishable from one added a
  month ago in the intensity math. Called out again here since the
  grid-growth work touches the exact same code path, but it's unchanged
  from before this pass.
- **iOS widget tap-to-launch** — not implemented; no iOS widget target
  exists yet at all (standing gap, not new).

## References
- `SOFTWARE-ENGINEER/reports/CLUBZERO-2026-10-05-unified-home-screen-and-anchor-visibility.md`
  — the same-day predecessor this work continues from.
- Commit on `main`, `Club-Zero` monorepo (pushed same session).

---

**Completed By:** Claude (Sonnet 5), for tinotendamupezeni@thuthuka.tech.
**Duration:** Single session, 2026-10-05, continuing directly from the unified Home screen and habit-anchors work earlier the same day.
