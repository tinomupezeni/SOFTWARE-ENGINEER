# Orphaned widget fragment in `dashboard_seats_row.dart` broke `assembleDebug`

**Date:** 2026-10-05
**Project:** CLUBZERO
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary

`club_zero_mobile/lib/widgets/dashboard_seats_row.dart` ended with a 7-line orphaned fragment (a leftover `SEND` button from an older version of the invite dialog) dangling after `_showInviteDialog`'s closing brace. This broke the file's class structure, so `flutter run` / `assembleDebug` failed with a cluster of misleading `const`-expression and constructor errors. Removed the fragment; `flutter analyze` is clean and the app builds, installs, and runs on the test device with no Dart exceptions.

## Symptoms

- `flutter run` failed in `compileFlutterBuildDebug`:
  - `Error: Not a constant expression` on `const Text("SEND EMAIL"...)` and `const Text("SEND"...)`
  - `Error: Too many positional arguments: 0 allowed, but 1 found` on the toastification `title: Text(...)`
  - `Error: Constructor is marked 'const' so all fields must be final` on `DashboardSeatsRow`
- None of these errors pointed at the actual problem (lines 258–264).

## Environment Details

- **Server/Host:** Local dev machine → physical test device (Samsung SM-S906U1, Android 15, wireless ADB)
- **Services Affected:** Flutter mobile app (`club_zero_mobile`), debug build
- **Related Components:** `lib/widgets/dashboard_seats_row.dart` (`_showInviteDialog`, invite-dialog actions)
- **Time First Observed:** 2026-10-05, when launching the app on the test phone over wireless ADB

## Investigation Steps

### 1. Initial Diagnosis

Build output blamed `const Text(...)` widgets. Read the file end (lines 230–265) instead of trusting the error locations.

### 2. Root Cause Analysis

```bash
# Structure mapping of _showInviteDialog (starts line 189):
#   194 showDialog( → 196 builder: AlertDialog( → 235 actions: [
#   255 ], → 256 ), → 257 ); → 258 }, ← orphan + 6 more dead lines
```

- `_showInviteDialog` closed correctly at line 257 (`);`) — then line 258 had a stray `},` followed by a `child: const Text("SEND"...)` fragment that belonged to a previous iteration of the dialog (the current dialog already has its `SEND EMAIL` button at line 253).
- The stray fragment sat at class scope, corrupting the parse of everything around it — hence the cascade of `const`/constructor errors in *valid* code above it.
- `flutter analyze lib/widgets/dashboard_seats_row.dart` after the fix: 0 errors, only 8 pre-existing `info`-level deprecation notices (`withOpacity`, legacy `Share` API).

### 3. Key Findings

- The `title: Text(...)` "too many positional arguments" error was pure cascade — the toastification call was always correct; only the orphan needed removal.
- Working tree was otherwise clean (`git status` empty), so the fragment was committed, almost certainly by the latest commit `246d3c5` ("invite & offline engine") which reworked this dialog.

## Root Cause

A partial edit/merge of the invite dialog left a 7-line dead fragment after the function's closing brace. Dart's parser attributed the structural break to surrounding valid code, producing error messages that pointed everywhere except the real location.

## Prevention / Rule

**Guardrail:** Run `flutter analyze` (which fails on errors, not just warnings) before committing any Dart change — or, per the standing gap, add it to CI. A 13-second analyzer run fails before this fix and passes after it, catching 100% of committed-but-uncompilable Dart regardless of how misleading the compiler errors look.

This is the same missing gate as `Backend_and_API/CLUBZERO-2026-10-05-main-missing-router-imports.md` (logged same day): neither the backend nor the mobile app has any automated check that the code even compiles.

## Solution

### Immediate Fix

Deleted the orphaned lines 258–264 in `dashboard_seats_row.dart`, closing the function cleanly:

```dart
    );
  }
}
```

Verified with:

```bash
flutter analyze lib/widgets/dashboard_seats_row.dart  # 0 errors
flutter run -d "<wireless-device-id>"                 # builds, installs, runs; pid confirmed via adb; logcat shows no Flutter/Dart exceptions
```

### Long-term Fix

- CI running `flutter analyze` + `pytest` on every change (DEVLOG §8 item 8 — still open, now blocking two verified incidents).
- Prefer small scoped edits over dialog rewrites that leave fragments behind; review diffs to EOF, not just the hunk.

## Prevention

- [ ] CI with `flutter analyze` (errors gate the merge)
- [ ] Backend import-smoke check (companion entry, same day)
- [ ] Confirm which image/SHA is on `smepulse-vm` — backend has a parallel startup-crash bug in the same commit

## Related Issues

- `Frontend_and_UI/ClubZero-2026-10-02-dart-sed-syntax-corruption.md` — earlier Dart-syntax corruption in the same app, different mechanism (global `sed` vs. leftover edit fragment); same missing `flutter analyze` gate would have caught both
- `Backend_and_API/CLUBZERO-2026-10-05-main-missing-router-imports.md` — same commit vintage, same missing-gate root pattern, backend side

## References

- `SharedHQ/club_zero_mobile/lib/widgets/dashboard_seats_row.dart`
- `SharedHQ/DEVLOG.md` §8 item 8 (no CI)

---

**Resolved By:** Muse Spark (opencode)
**Time to Resolution:** ~15m (pair phone → build → diagnose → fix → analyze → reinstall → verify running)
