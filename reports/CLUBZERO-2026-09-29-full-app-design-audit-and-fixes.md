# Club Zero: full-app design audit against three vendored design skills, all 11 findings closed

**Date:** 2026-09-29
**Project:** Club Zero
**Type:** Audit + fix pass
**Status:** Completed — all 11 findings fixed, `flutter analyze` clean (zero new errors) after every batch; not yet verified on a physical device (see Follow-ups)

## Summary
After several sessions of applying design-skill guidance selectively (contrast
fixes, `kEaseOut` easing token, black-text CTAs), the user asked directly
whether the full app had actually been brought in line with the vendored
design skills. Rather than assume, a read-only audit was run first — every
file in `lib/screens/` and `lib/widgets/` checked against three skills
(apple-design's 5-lens HIG review, emilkowalski/skills' `improve-animations`
8-category audit, mobile-app-ui-design's 8pt-grid/color/typography rules) —
producing `club_zero_mobile/DESIGN_AUDIT.md` with 11 findings ranked by
leverage. The user then asked to fix them in order, top to bottom, which this
report covers.

## Context / Trigger
Direct user question: "so we have updated the full app design with the design
skills right" — answered honestly that no systematic audit had been done,
only selective application. User then asked for "a proper full-app design
audit against these skills," which was run read-only per the
`improve-animations` skill's own methodology (cite every finding at
file:line, confirm each with grep, never modify source during the audit
itself). Once the audit was delivered, the user's follow-up instruction was
explicit: "lets go in order fixing each one on our way down the list."

## Scope
**Included:** all 11 numbered findings in `DESIGN_AUDIT.md`, fixed in the
user's specified order (severity-ranked, CRITICAL → LOW).

**Explicitly excluded:**
- The "missed opportunities" section of the audit (celebration animation on
  challenge completion, list-load stagger, streak count-up, distinct cheer
  tap-feedback) — additive suggestions the audit itself separated from the
  numbered findings; the user's instruction was to fix the numbered list, not
  this section.
- Real Google Sign-In implementation (finding #8) — the audit gave two
  options ("wire it, or visually demote it"); wiring real OAuth needs
  Firebase/GCP console work outside this session's scope, so the button was
  demoted instead (dimmed, non-interactive, "SOON" badge).
- Aggressive collapse of the app's 24–56px hero/display font-size scale
  (part of finding #9) — see Decisions & Findings below for why this was
  deliberately scoped down from the audit's literal "4-5 sizes total"
  suggestion.
- On-device verification — the phone was disconnected before this pass began
  and was not reconnected during it (see Follow-ups).

## Method
Each finding was fixed in the user's specified order, then verified with
`flutter analyze lib/` after every batch, comparing the error/warning count
against the pre-fix baseline (0 errors, 54 pre-existing info-level notices)
to catch any regression immediately rather than batching verification to the
end. Mechanical, repeated-pattern fixes (contrast color swaps, spacing
values, font weights) used scoped `sed` passes — narrow enough to match only
the confirmed violation sites — followed by a `grep` re-check that the exact
expected count of sites changed and no unrelated literal was touched.
Judgment-requiring fixes (press-feedback wrapper, reduced-motion helper,
toast-to-SnackBar migration, empty-state copy, Google button demotion,
typography scale) were read in full file context before editing.

## Decisions & Findings

**One shared `PressableScale` widget, not five duplicated implementations**
(finding #3). Built `lib/widgets/pressable_scale.dart` — wraps a child in
`onTapDown`/`onTapUp`/`onTapCancel` driving an `AnimatedScale` to 0.97 — and
wired it into all 5 primary CTAs. Matches the emil `animate` skill's own
rule to extend existing tokens rather than fork a new convention per screen.

**Reduced-motion support added as a duration wrapper, not a widget wrapper**
(finding #4). Added `motionDuration(context, duration)` to
`lib/theme/motion.dart`, returning `Duration.zero` when
`MediaQuery.of(context).disableAnimations` is true. Applied to all 13
duration-bearing animation call sites app-wide (the 14th, `main_layout.dart`'s
nav-item `AnimatedContainer`, was dead code slated for removal under finding
#10 rather than a real animation to gate). One `StatelessWidget` helper
method (`DashboardSeatsRow._buildMemberSeat`) needed `BuildContext` threaded
through as a parameter since it had no implicit `context` getter.

**Standardized on `SnackBar`, dropped the `fluttertoast` dependency**
(finding #6). `login_screen.dart`, `register_screen.dart`, and
`create_club_screen.dart` were the only files still using `Fluttertoast`;
every other screen already used `ScaffoldMessenger`/`SnackBar`. Migrated all
5 call sites to the existing pattern, confirmed nothing else referenced
`fluttertoast`, then removed it from `pubspec.yaml` and ran
`flutter pub get` to confirm a clean removal.

**Google Sign-In demoted rather than wired** (finding #8). Real OAuth needs
Firebase/GCP console setup outside this pass's scope. The button is now
non-interactive, dimmed (`white38`), and carries a "SOON" badge — it no
longer presents as a working auth path while tapping it. The now-orphaned
`_googleSignIn()` toast-handler methods were deleted from both screens
rather than left as dead code.

**Typography: fixed the weight system fully, scoped the font-size collapse**
(finding #9). Font weights collapsed 6 → 3 (`w500` regular, `w700`
bold/label/button, `w900` reserved for hero/display text) — this surfaced
and fixed a real, previously unnoticed inconsistency: the app's 5 primary
CTA buttons were split between `w800` and `w900` at the identical visual
role (button label). Font sizes were only tightened where the near-duplicate
was unambiguous and low-risk (`10→11`, `15→16`, `18→20`; 16 distinct sizes →
13) — this also unified the dashboard CTA's button-text size with the other
4 CTAs. The 24–56px hero/display scale used across different screens'
headline treatments was deliberately left alone: the audit's own text already
called that tier "coherent," forcing it down to ~4-5 sizes total risks a
visible regression on every screen's hero text, and there was no way to
visually confirm the result since the phone was disconnected for this whole
pass. Documented this scoping explicitly in `DESIGN_AUDIT.md` rather than
overclaiming full compliance with the audit's literal size-count target.

**8pt grid: fixed every specifically-cited value, left stroke/shape tokens
alone** (finding #11). Every off-grid value the audit named by example
(`6`, `10`, `14`, `18`, `30`, `70`) was tracked to its exact file:line and
rounded to the nearest 4/8 multiple, reusing the codebase's own dominant
existing values where one was close (e.g. `14→16` rather than `14→12`, since
16 was already the dominant padding value elsewhere). Border/stroke widths
(1–2px) and the 66px avatar-circle diameter were left untouched — those are
shape/stroke tokens, not the spacing grid this finding is about, and the
audit didn't flag them. Also caught the same off-grid drift in the "SOON"
badge padding added earlier in this same pass for finding #8
(`vertical: 3` → `4`) — a self-consistency fix within the pass itself, not
a separately-audited finding.

## Changes Made
**New files:** `lib/widgets/pressable_scale.dart`.

**Modified:** `lib/theme/motion.dart` (added `motionDuration()` helper),
`lib/screens/login_screen.dart`, `lib/screens/register_screen.dart`,
`lib/screens/create_club_screen.dart`, `lib/screens/onboarding_screen.dart`,
`lib/screens/dashboard_screen.dart`, `lib/screens/stats_screen.dart`,
`lib/screens/clubs_screen.dart`, `lib/screens/main_layout.dart`,
`lib/widgets/dashboard_seats_row.dart`, `lib/widgets/daily_habit_card.dart`,
`pubspec.yaml` (removed `fluttertoast: ^10.0.0`).

**Tracking:** `club_zero_mobile/DESIGN_AUDIT.md` updated live as each finding
closed — added a `Status` column and a one-line note per finding on exactly
what was done (including the two findings, #9 and #11, where the actual fix
was deliberately scoped narrower than the audit's literal suggestion, with
the reasoning inline).

## Verification
`flutter analyze lib/` run after every batch of fixes, diffed against the
pre-audit baseline (0 errors, 54 pre-existing info-level notices, all
`withOpacity` deprecation / unused-import warnings). Final state: 0 errors,
56 info-level notices — the +2 are `withOpacity` deprecation notices from
the new Google-button demotion `Container`s, matching the same pre-existing
deprecation pattern already present elsewhere in those files, not a new
class of issue. `flutter pub get` confirmed `fluttertoast` was cleanly
removable (nothing else depended on it).

No on-device or visual verification was performed — see Follow-ups.

## Follow-ups / Deferred
- **Not verified on a physical device.** The phone was disconnected before
  this pass began (last confirmed state: empty `adb devices`/`adb mdns
  services` output) and was not reconnected during it. None of this pass's
  11 fixes — nor the 4-gaps feature work (discoverable clubs, cheer,
  challenges, stakes) from the prior session — have been visually confirmed
  on-device yet. This is the most load-bearing follow-up: several fixes in
  this pass (typography collapse, 8pt grid rounding, Google button demotion)
  are exactly the kind of change that reads correctly in source but should
  be eyeballed before calling the audit truly closed.
- **"Missed opportunities" section of `DESIGN_AUDIT.md`** (celebration
  animation on challenge completion, list-load stagger, streak count-up,
  distinct cheer tap-feedback) — flagged but not requested for action.
- **Hero/display font-size scale (24–56px)** — deliberately left at its
  current per-screen values rather than force-collapsed; a future pass could
  revisit this with the phone connected to visually judge the tradeoff.

## References
- `club_zero_mobile/DESIGN_AUDIT.md` — the audit itself, with per-finding
  `Status` now tracking this pass's fixes inline.
- `/home/shadowe/Projects/SharedHQ/DEVLOG.md` — living project status doc;
  not yet updated to reference this pass as of this report (next step).
- Design skills referenced: `References/apple-design-skill/`,
  `References/skills/skills/animate/` and
  `References/skills/skills/improve-animations/`,
  `Lessons/mobile-app-ui-design/` (all under this repo).

---

**Completed By:** Claude (Sonnet 5), for tinotendamupezeni@thuthuka.tech.
**Duration:** Single continuous session, 2026-09-29.
