# Apple Design Guide Deviation: Friendly/Cartoon UI

**Date:** 2026-10-08
**Project:** Inclusivity
**Type:** Architecture Decision / Scope Decision
**Status:** Completed

## Summary
The UI of the app was shifted from a strict Apple-Design compliant framework to a brighter, cartoon-icon friendly interface, replacing large text-heavy buttons with visual cues (like a floating microphone icon and emoji-based tiles). This deviates slightly from the strict "Apple Design" guidelines (which lean towards system icons, native iOS typography scales, and translucent blurs), but provides a better cognitive experience for the accessibility use-case.

## Context / Trigger
The user explicitly requested: "a light themes, cartoon icons, clean screen, instead of a hold to talk button, we have an audio icon, that the user holds".

## Scope
Included: `Color.kt`, `Theme.kt`, `MarketModeScreen.kt`, `HomeModeScreen.kt`.
Excluded: Underlying STT/TTS and data layers.

## Method
Replaced the strict Apple aesthetic with a clean white/light gray palette. Integrated emojis into the `LivingTile` buttons and replaced the massive "HOLD TO TALK" block with a floating Action-Button style Microphone icon, anchored by spring physics (dampingRatio 0.6f for a bouncier feel) to retain the Apple-Design physical feedback while presenting a softer, cartoonish look.

## Decisions & Findings
- **Deviation from Guide:** The `apple-design` guide advocates for clear iconography (often meaning standard SF Symbols/Material Icons) and standard text weight hierarchy. By replacing these with cartoon-like icons (emojis like 💡 and 💬), we strayed from strict modern enterprise design into friendly, accessible design.
- **Engineering Justification:** For an inclusivity app targeting potentially impaired or neurodivergent users, "friendly" and visually distinct cartoon elements significantly reduce cognitive load compared to clean but clinical system icons.
- **Compromise:** We retained the `apple-design` rules for *Fluid Interfaces* (response on down-press, 1:1 interaction, spring physics) while changing the *visual* layer to the requested style.

## Changes Made
- `Color.kt`: Overhauled to Light Mode palette (PureWhite, LightSurface, AppleBlue, AppleGreen).
- `Theme.kt`: Switched to `lightColorScheme`.
- `MarketModeScreen.kt`: Redesigned to feature a Speech Bubble, a bouncy Mic Icon, and emoji tiles.
- `HomeModeScreen.kt`: Added a 💡 emoji to all living tiles.

## Verification
- Code compilation verified via `./gradlew assembleDebug`.

## Follow-ups / Deferred
None.

## References
- `apple-design/SKILL.md`

---

**Completed By:** Antigravity
**Duration:** 10m
