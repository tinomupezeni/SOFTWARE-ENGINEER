# Issue: Invisible Text on Auth Screens due to White Scaffold Background

## Description
During the migration to the Emerald Theme, the root `Scaffold` background on `login_screen.dart` and `register_screen.dart` was accidentally left as `Colors.white`. Because the text and input fields were already updated to use `Colors.white` and `Colors.white70` for the dark theme, the text became completely invisible against the white background.

## Resolution
Updated the `backgroundColor` on both `login_screen.dart` and `register_screen.dart` to use the primary Emerald dark background `Color(0xFF0A3C30)`.

## Resolved By
Antigravity
