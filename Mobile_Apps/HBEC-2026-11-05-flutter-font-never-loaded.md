# Flutter app never actually rendered in Inter — runtime font fetch was disabled with no bundled fallback

**Date:** 2026-11-05
**Project:** HBEC (STUDENT/mobile_flutter)
**Environment:** Development/Staging (reported by the user comparing the live app to web)
**Severity:** Medium
**Status:** Resolved

## Summary
The user reported the Flutter app's font didn't match the web app's
(Inter). Investigation found this wasn't intermittent or offline-only —
the app had **never** rendered in Inter on any launch, online or not,
since `main.dart` disabled `google_fonts`'s runtime network fetch
(`GoogleFonts.config.allowRuntimeFetching = false`) without ever bundling
the font locally, so every `GoogleFonts.inter(...)` call silently resolved
to the platform fallback (Roboto on Android).

## Symptoms
- User report: "the full mobile app font, should be the exact one as the
  one on the webapp" — implying a visible, permanent mismatch, not a
  one-off.

## Environment Details
- **Server/Host:** N/A (client-only rendering bug)
- **Services Affected:** Every screen in the Flutter app — `app_theme.dart`
  applies `GoogleFonts.interTextTheme`/`GoogleFonts.inter()` to the app's
  entire `ThemeData`.
- **Related Components:** `STUDENT/mobile_flutter/lib/main.dart`,
  `STUDENT/mobile_flutter/lib/core/theme/app_theme.dart`,
  `STUDENT/mobile_flutter/pubspec.yaml`
- **Time First Observed:** 2026-11-05, reported after a live visual
  comparison with the web app.

## Investigation Steps

### 1. Initial Diagnosis
Checked `pubspec.yaml`'s `fonts:` section for a bundled Inter asset —
entirely commented out (the template placeholder, never filled in).

### 2. Root Cause Analysis
```bash
grep -rn "GoogleFonts\|google_fonts" lib/
```
Found `main.dart:27`: `GoogleFonts.config.allowRuntimeFetching = false;` —
a correct instinct for an offline-first app (don't depend on a network
fetch for the UI to look right), but with no corresponding local font
asset ever registered. The `google_fonts` package's documented behavior
when runtime fetching is disabled and no matching bundled asset exists is
to fall back silently to the platform default — exactly what was observed.

### 3. Key Findings
- This was a **permanent**, every-launch bug, not an offline edge case —
  disabling runtime fetching without bundling the font meant the fallback
  path was the *only* path, online or not.
- No other file in `lib/` called `GoogleFonts.*` directly — the blast
  radius was contained to `app_theme.dart`'s theme construction, which
  every screen inherits from.

## Root Cause
A real font-loading risk (unreliable runtime network fetch for app
typography) was half-fixed: the risky path was disabled, but the safe
replacement (a bundled local font) was never added, leaving the app with
no working font-loading path at all for its intended typeface.

## Prevention / Rule
**Guardrail:** None added this session — the direct guardrail (fail a
build if `google_fonts` is a dependency, `allowRuntimeFetching` is false,
and no matching font family exists in `pubspec.yaml`'s `fonts:` section)
is a reasonable small lint/CI script if this pattern is worth guarding
against repo-wide; not built now since the fix here was to remove the
`google_fonts` dependency entirely rather than keep both paths alive.

[No automated guardrail added — the dependency that enabled this class of
bug was removed instead, which closes this specific gap without needing
one.]

## Solution

### Immediate Fix
Not applicable — client-only, no service was down.

### Long-term Fix
- Downloaded Inter's official variable font
  (`google/fonts` GitHub repo, OFL-licensed) to
  `STUDENT/mobile_flutter/assets/fonts/Inter.ttf` — one file covering every
  weight the app uses (Regular through Black, confirmed by grepping every
  `FontWeight.*` used in `lib/`).
- Registered it in `pubspec.yaml`'s `flutter.fonts:` section under family
  `Inter`.
- `app_theme.dart`: replaced every `GoogleFonts.inter(...)` /
  `GoogleFonts.interTextTheme(...)` call with plain `TextStyle(fontFamily:
  'Inter', ...)` / `textTheme.apply(fontFamily: 'Inter')`.
- Removed the now-fully-unused `google_fonts` package from `pubspec.yaml`
  and the dead `GoogleFonts.config.allowRuntimeFetching = false;` line
  (plus its import) from `main.dart`.
- `flutter pub get` confirms `google_fonts` is no longer a dependency.

## Prevention
- [ ] Configuration changes needed — N/A
- [ ] Monitoring/alerts to add — N/A
- [ ] Documentation to update — N/A
- [x] Code changes required — done, see Solution above.

## Related Issues
- None directly; found during a broader Flutter/web visual-parity pass
  (see the 2026-11-05 web/Flutter parity-audit-tool report).

## References
- `STUDENT/mobile_flutter/lib/core/theme/app_theme.dart`
- `STUDENT/mobile_flutter/lib/main.dart`
- `STUDENT/mobile_flutter/pubspec.yaml`
- `STUDENT/mobile_flutter/assets/fonts/Inter.ttf` (new bundled asset)
- Upstream source: `https://github.com/google/fonts/blob/main/ofl/inter/Inter%5Bopsz,wght%5D.ttf`
  (OFL license, `ofl/inter/OFL.txt` in that repo)

---

**Resolved By:** tinomupezeni (with Claude Code)
**Time to Resolution:** <30 minutes
