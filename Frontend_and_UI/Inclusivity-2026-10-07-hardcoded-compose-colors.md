# Hardcoded Compose Colors Architecture Debt

**Date:** 2026-10-07
**Project:** Inclusivity
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
The Inclusivity app was initially built using hardcoded Hex values (e.g., `Color(0xFF1E1E1E)`) directly in the Compose screen files rather than leveraging Jetpack Compose's `MaterialTheme`. This created technical debt and prevented the app from supporting scalable themes (like high-contrast or dark mode) necessary for accessibility.

## Symptoms
- Inability to quickly switch color themes.
- Redundant color definitions scattered across UI components.
- Lack of a central `Theme.kt` and `Color.kt` standard in the project.

## Environment Details
- **Services Affected:** Android App UI
- **Related Components:** `MarketModeScreen.kt`, `MainActivity.kt`
- **Time First Observed:** 2026-10-07

## Investigation Steps

### 1. Initial Diagnosis
Reviewed `MarketModeScreen.kt` and `MainActivity.kt` to understand how colors were being applied. Found raw hex values and a default `MaterialTheme` wrapper with no custom schema.

### 2. Root Cause Analysis
During early prototyping, colors were added inline to speed up development. This bypassed Android's recommended theme architecture.

### 3. Key Findings
- `MainActivity.kt` used a generic `MaterialTheme` without a defined `colorScheme`.
- `MarketModeScreen.kt` hardcoded colors for backgrounds, buttons, and text.
- No `ui/theme` package existed in the codebase.

## Root Cause
Bypassing Jetpack Compose theming standards during the rapid prototyping phase of UI development.

## Prevention / Rule
**Guardrail:** UI/UX Code Review Checklist & Linting Rule
Establish a lint rule or code-review checklist item that flags the use of raw `Color(0xFF...)` constructors inside `@Composable` functions outside of `Color.kt`. 

This ensures all colors are mapped through the `MaterialTheme.colorScheme` or semantic color extensions, allowing for universal theme switching and better accessibility support.

## Solution

### Immediate Fix
1. Created `com.inclusivity.communicator.ui.theme` package.
2. Defined "Ink Wash" palette in `Color.kt` (`CharcoalBlack`, `CoolGray`, `SoftIvory`, `ActionGreen`, `AlertRed`, `AccentBlue`).
3. Created `InclusivityTheme` in `Theme.kt` mapping colors to `lightColorScheme`.
4. Refactored `MainActivity.kt` and `MarketModeScreen.kt` to use `MaterialTheme.colorScheme.*` and custom accent variables.

### Long-term Fix
Ensure all future screens (e.g., `HomeModeScreen`, `OfficeModeScreen`) strictly adhere to the `InclusivityTheme`.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- Theming support requested by the user.

## References
- Jetpack Compose Theming Documentation

---

**Resolved By:** Antigravity
**Time to Resolution:** 10 minutes
