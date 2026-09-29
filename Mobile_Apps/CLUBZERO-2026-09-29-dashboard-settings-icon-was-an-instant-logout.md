# The dashboard's "settings" gear icon logged you out on a single tap, with no screen behind it and no confirmation

**Date:** 2026-09-29
**Project:** Club Zero
**Environment:** Development
**Severity:** Medium (no data loss, but a destructive-feeling action — losing your session — triggered by a single mis-tap on an icon that visually promised something else)
**Status:** Resolved

## Summary
`dashboard_screen.dart`'s header row had a gear/settings icon
(`Icons.settings_outlined`) whose `onPressed` called
`context.read<AuthProvider>().logout()` directly — not a navigation to a
settings screen, not even a confirmation dialog. Tapping it immediately
cleared the session and dropped the user back to the login screen. This
was found while building a real Profile screen at the user's request
("we need a user profile page as well"); there was no profile/account
screen anywhere in the app before this, matching the gap already tracked
in `DEVLOG.md` §5 ("No settings/account screen... nav bar's third tab is
now Clubs, was a dead Settings placeholder").

## Symptoms
- A gear icon, which universally signals "open settings," instead ended
  the user's session with zero intermediate screen or confirmation.
- No way to recover from an accidental tap except logging back in.
- No actual settings or account screen existed anywhere in the app to
  redirect to — the icon was effectively a placeholder that got wired to
  the nearest available action (logout) rather than left inert or removed.

## Environment Details
- **Server/Host:** N/A — client-only bug, no backend involved.
- **Services Affected:** `club_zero_mobile` Flutter client only.
- **Related Components:** `lib/screens/dashboard_screen.dart` (the icon),
  `lib/providers/auth_provider.dart` (`logout()`, unchanged — the bug was
  in when it got called, not the method itself).
- **Time First Observed:** 2026-09-29, while scoping the new Profile
  screen and looking for any existing account-related UI to build on top
  of instead of duplicating.

## Investigation Steps

### 1. Initial Diagnosis
Grepped for existing logout/settings entry points before building a new
Profile screen, to avoid creating a second, conflicting path to the same
action.

### 2. Root Cause Analysis
```
# lib/screens/dashboard_screen.dart (before fix)
IconButton(
  icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 20),
  onPressed: () => context.read<AuthProvider>().logout(),
),
```
The icon's affordance (a gear = settings) didn't match its behavior (an
immediate, irreversible-feeling session end). This is the kind of gap
that's easy to introduce mid-build: a "settings" icon gets added to a
header for visual balance, there's no settings screen yet to point it at,
and it gets wired to the one account-related action that does exist
(`logout()`) as a stand-in, which then never gets revisited once a real
destination is built.

### 3. Key Findings
- This was the *only* way to log out in the entire app — no other logout
  button existed anywhere, so removing the icon without replacing it
  would have been a regression, not a fix.
- No other icon/button in the app has this affordance-mismatch pattern
  (confirmed by grep for other `IconButton`/bare `onPressed:` pairs calling
  `AuthProvider` methods — this was the only one).

## Root Cause
A placeholder UI element (a settings icon with nowhere real to go yet)
was wired to the nearest existing destructive-feeling action instead of
being left inert, and no real settings/profile screen was ever built to
absorb it — until this session's Profile screen work surfaced it.

## Prevention / Rule
**Guardrail:** Any icon whose Material icon name implies navigation (a
gear, a person, a menu) must either push a real screen or be removed —
never wired directly to a stateful action like `logout()`,
`deleteAccount()`, or similar. A quick code-review checklist item:
"does this icon's `onPressed` navigate, or does it *do* something?" — if
it does something consequential, it needs a screen or a confirmation in
between, not a bare state-clearing call.

## Solution

### Immediate Fix
Removed the gear icon from `dashboard_screen.dart`'s header entirely (the
header now just shows the club name, no trailing icon). Logout now lives
on the new Profile tab (`lib/screens/profile_screen.dart`), behind a
confirmation dialog ("Log out? You'll need to sign back in to see your
clubs." / CANCEL / LOG OUT), reachable from the bottom nav bar rather than
a single icon tap on the dashboard.

### Long-term Fix
None needed beyond the fix itself — the Profile screen is now the
permanent, correct home for this and future account actions (the
still-open gaps — leave club, delete account, notification preferences —
now have an obvious screen to land in rather than another ad hoc icon).

## Prevention
- [x] Fix applied (icon removed, logout moved to Profile tab with confirmation)
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — none, client-only UI bug
- [x] Documentation to update — `DEVLOG.md` (see report cross-reference)
- [x] Code changes required

## Related Issues
- None filed yet.

## References
- `club_zero_mobile/lib/screens/dashboard_screen.dart`
- `club_zero_mobile/lib/screens/profile_screen.dart` (new)
- Report: `SOFTWARE-ENGINEER/reports/CLUBZERO-2026-09-29-google-signin-onboarding-guide-profile-screen.md`

---

**Resolved By:** Claude (Sonnet 5), found and fixed same-session for tinotendamupezeni@thuthuka.tech.
**Time to Resolution:** Same session as discovery, 2026-09-29.
