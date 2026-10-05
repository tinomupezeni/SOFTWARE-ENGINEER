# App icon still used the pre-rebrand neon-green/navy palette, not the current emerald theme

**Date:** 2026-10-05
**Project:** Club Zero
**Environment:** Development
**Severity:** Low (cosmetic/brand-consistency only, no functional impact)
**Status:** Resolved

## Summary
The app's launcher icon (`assets/icon/app_icon.png`, regenerated for all
platforms via `flutter_launcher_icons`) was designed during an earlier
session when the app's accent color was neon green (`#39FF14`) on a
near-black background. The in-app theme was rebranded at some point since
(by other work in this long-running session/day) to a deep emerald
background (`0xFF0A3C30`) with a mint/aquamarine accent (`0xFF73E6CB`),
used consistently across 81+ call sites in the Flutter code. The icon
was never updated to match, so the app's launcher icon and its actual UI
told two different color stories. Found via direct user report ("lets
match the app icon to the app emerald theme").

## Symptoms
- Launcher icon: dark navy (`#0E1317`) background, vivid jade-green
  (`#07BB7E`) "0" mark.
- In-app theme: deep emerald (`#0A3C30`) background, mint/aquamarine
  (`#73E6CB`) accent — confirmed as the dominant, consistently-used
  palette via `grep` across `lib/` (81 uses of the mint accent, 39 of the
  emerald background, vs. zero remaining uses of the old neon green in
  the UI itself).
- `pubspec.yaml`'s `flutter_launcher_icons.web` config also still
  referenced the old neon-green `theme_color`.

## Environment Details
- **Server/Host:** N/A — client-only asset/config drift.
- **Services Affected:** `club_zero_mobile` — the app icon across every
  platform (`flutter_launcher_icons` regenerates Android/iOS/web/Windows
  from one source), plus the web PWA manifest's theme/background colors.
- **Time First Observed:** 2026-10-05, direct user report.

## Investigation Steps

### 1. Initial Diagnosis
Opened the current source icon and the app's actual `ThemeData` /
color-literal usage side by side; confirmed via `grep -rhoE
"0xFF[0-9A-Fa-f]{6}" lib/` that the emerald/mint pair was the real,
overwhelmingly dominant palette and the icon's colors appeared nowhere
in the current UI.

### 2. Root Cause Analysis
Classic asset drift: the icon was hand-designed once, early in the
project, and never revisited when the in-app color scheme changed later —
nothing ties the icon source file to the theme's color constants, so
there was no mechanism that would have caught the two drifting apart.

### 3. Key Findings
- The icon's actual shapes (the stylized "0" mark, its crescent-shadow
  highlight) were fine and worth keeping — only the color story was
  stale, not the design itself.

## Root Cause
No link between the app's theme color constants and the icon asset — a
rebrand updated one without the other.

## Prevention / Rule
**Guardrail:** when a color-driven rebrand lands, grep the icon/launch
asset directories (`assets/icon/`, platform mipmap/asset-catalog folders)
as part of the same change, same as code — brand assets drift silently
otherwise, with no compiler or test to catch it.

## Solution

### Immediate Fix
Recolored the existing icon artwork in place (same shapes, same
gradient/shadow structure) rather than redesigning it — did a palette
remap from the old reference colors (white canvas, navy background,
bright jade, dark jade-shadow) to the new ones (white canvas unchanged,
`#0A3C30` background, `#73E6CB` mint, a proportionally-darkened mint for
the shadow), verified pixel-exact against the theme's actual hex values
afterward. Updated `pubspec.yaml`'s `flutter_launcher_icons.web` block to
the same pair. Regenerated every platform's icon via `dart run
flutter_launcher_icons`.

### Long-term Fix
None needed beyond the fix itself.

## Verification
Sampled background and mark pixels from the regenerated source PNG:
background `(10, 60, 48)` vs. target `0x0A3C30` = `(10, 60, 48)` (exact);
mark `(113, 229, 202)` vs. target `0x73E6CB` = `(115, 230, 203)` (within
rounding). `flutter analyze lib/` unchanged (0 errors, same pre-existing
info count). Full release build + install + launch on a physical device:
clean, no crashes, confirmed via `adb logcat`.

## Prevention
- [x] Fix applied (icon recolored, regenerated, verified pixel-accurate)
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — none, cosmetic
- [ ] Documentation to update — none
- [x] Code changes required (asset + `pubspec.yaml` web theme colors)

## Related Issues
- None filed yet.

## References
- `club_zero_mobile/assets/icon/app_icon.png`
- `club_zero_mobile/pubspec.yaml` (`flutter_launcher_icons.web`)

---

**Resolved By:** Claude (Sonnet 5), for tinotendamupezeni@thuthuka.tech.
**Time to Resolution:** Same session as discovery, 2026-10-05.
