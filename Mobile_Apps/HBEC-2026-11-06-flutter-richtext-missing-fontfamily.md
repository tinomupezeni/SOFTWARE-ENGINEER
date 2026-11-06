# A `RichText` widget silently dropped the app's font, rendering bold/linked legal text as tofu glyphs

**Date:** 2026-11-06
**Project:** HBEC (Flutter student mobile app, `STUDENT/mobile_flutter/`)
**Environment:** Development
**Severity:** Medium — did not block the build, but made the affected text unreadable (rendered as solid black glyph boxes) in the test harness, and would have rendered in the wrong, unbundled system font on a real device
**Status:** Resolved

## Summary
While building the `/terms` and `/privacy` legal-page screens (shared
`LegalPageShell`/`LegalRichParagraph`/`LegalRichBulletList` widgets in
`lib/features/auth/presentation/widgets/legal/legal_page_shell.dart`), any
paragraph containing a tappable link or a bold `<strong>`-style lead-in was
built with Flutter's `RichText` widget directly, using a shared
`legalBodyStyle` `TextStyle` with no `fontFamily` set. Plain `Text` widgets
on the same page rendered correctly because they inherit `fontFamily` from
the app's `DefaultTextStyle` (set by `AppTheme.lightTheme`'s `textTheme`).
`RichText`, unlike `Text`/`Text.rich`, does **not** inherit `DefaultTextStyle`
at all — every `TextSpan` style it's given is used exactly as-is. With no
`fontFamily`, the `TextSpan`s fell back to the platform/test default font.
In the golden-test harness this surfaced as solid black rectangles in place
of every letter (a classic "no matching glyph" fallback-font render); on a
real device it would not crash, but every bold/linked sentence on these two
pages would silently render in the wrong typeface.

## Symptoms
- Golden test screenshots (`test/golden_tests/goldens/{ci,linux}/
  terms_page_render.png`) showed the final paragraph of Terms §2 and every
  bullet in Privacy §2 as solid black bars instead of text, while every
  other paragraph on the same page (built with plain `Text`) rendered
  correctly with the Inter font.
- No analyzer warning, no runtime exception — purely a visual defect, only
  caught by actually rendering the page (golden test + a live web-vs-Flutter
  screenshot comparison), not by `flutter analyze` or a text-content assertion.

## Environment Details
- **Server/Host:** Local dev (Linux), `flutter test` golden harness.
- **Services Affected:** `lib/features/auth/presentation/widgets/legal/legal_page_shell.dart`
  (`legalBodyStyle`, consumed by `LegalRichParagraph` and
  `LegalRichBulletList`).
- **Time First Observed:** 2026-11-06, while visually comparing the new
  `/terms` and `/privacy` Flutter golden-test renders against the web
  app's actual rendering (captured via a headless-browser screenshot) —
  per this project's migration skill's step 2/5 requirement to look at the
  rendered page rather than trust the widget tree by eye.

## Investigation Steps

### 1. Initial Diagnosis
Compared the Flutter golden-test PNG for `/terms` against a phone-width
screenshot of the live web page. The first several paragraphs (plain
`Text` widgets) matched; the paragraph built from `LegalRichParagraph`
(mixed bold + plain text, mid-sentence `<strong>` emphasis) rendered as
illegible black blocks instead of letters.

### 2. Root Cause Analysis
`legalBodyStyle` was defined as:
```dart
const TextStyle legalBodyStyle = TextStyle(
  fontSize: 15,
  color: AppColors.foreground,
  height: 1.55,
);
```
and used directly inside `TextSpan`s passed to a `RichText`. Plain `Text`
widgets elsewhere on the page merge their given style with the ambient
`DefaultTextStyle` (which carries `fontFamily: AppTheme.fontFamily =
'Inter'` from `AppTheme.lightTheme`'s `textTheme`), so they render in Inter
even without specifying `fontFamily` themselves. `RichText` has no such
merge step — it paints exactly the `TextStyle` on each span, so an absent
`fontFamily` falls through to the platform/test default, which doesn't
cover the same glyph set in the test environment (hence the "tofu" render)
and would simply be the wrong typeface on a real device.

### 3. Key Findings
- The bug was invisible to `flutter analyze`, to the widget tests (which
  assert on text content, not glyph rendering), and to a quick skim of the
  rendered golden PNG's *first* screenful — it only showed up once the
  specific section containing the rich-text paragraph scrolled into the
  compared screenshot.
- The web source actually uses inline `<strong>` tags in exactly these
  spots (`TermsPage.tsx` §2, `PrivacyPolicyPage.tsx` §2's bullet labels),
  which is what drove adding `RichText`-based rendering in the first place
  — so the fix path and the bug are directly linked to a genuine fidelity
  requirement, not an unused code path.

## Root Cause
`RichText`'s `TextSpan` styles are used verbatim and never merged with the
ambient `DefaultTextStyle`, unlike `Text`. A shared body-text style used
only by `Text` widgets elsewhere in the app had never needed an explicit
`fontFamily`; reusing that same style constant inside a `RichText` silently
lost the app's font.

## Prevention / Rule
**Guardrail:** any `TextStyle` constant intended for reuse inside a
`RichText`/`TextSpan` tree must set `fontFamily` explicitly — never rely on
`DefaultTextStyle` inheritance for text built through `RichText`. Added a
code comment on `legalBodyStyle` itself recording this, directly where the
next person reusing the constant will see it.

This closes the gap at its source (the shared style constant) rather than
patching each call site, and the comment makes the "why" discoverable
without needing to rediscover the `RichText`-vs-`Text` inheritance
difference from scratch.

## Solution

### Immediate Fix
```dart
// `fontFamily` is explicit here (unlike the plain `Text` widgets above,
// which inherit it from the app's `DefaultTextStyle`): `RichText` — used by
// every link/bold-emphasis paragraph below — does not inherit
// `DefaultTextStyle` at all, so without this it silently fell back to the
// platform's default font.
const TextStyle legalBodyStyle = TextStyle(
  fontFamily: AppTheme.fontFamily,
  fontSize: 15,
  color: AppColors.foreground,
  height: 1.55,
);
```
Regenerated the golden images after the fix; both `/terms` and `/privacy`
now render every paragraph (plain and rich) in the correct Inter font,
matching the live web app's typography.

### Long-term Fix
No other `RichText` usage in the codebase was found reusing a
`fontFamily`-less style constant at the time of this fix (checked via
`grep -rn "RichText(" lib/`), so no other call site needed the same
correction. Future `RichText`/`TextSpan` styles should follow the same
rule.

## Prevention
- [x] Code changes required — done (see Immediate Fix).
- [ ] Configuration changes needed — none.
- [ ] Monitoring/alerts to add — not applicable (build-time/visual issue).
- [ ] Documentation to update — covered by the inline code comment; no
      separate doc needed.

## Related Issues
- Found while completing the `/terms` and `/privacy` Flutter migration
  pass (screen map gaps, `scripts/parity/screen_map.yaml` ids `terms` and
  `privacy`).

## References
- `STUDENT/mobile_flutter/lib/features/auth/presentation/widgets/legal/legal_page_shell.dart`
- `STUDENT/mobile_flutter/lib/core/theme/app_theme.dart` (`AppTheme.fontFamily`,
  `textTheme`)
- `STUDENT/mobile_flutter/test/golden_tests/legal_pages_golden_test.dart`

---

**Resolved By:** Claude Sonnet 5 (agent session)
**Time to Resolution:** < 30 minutes (found during visual-parity verification in the same session the feature was built)
