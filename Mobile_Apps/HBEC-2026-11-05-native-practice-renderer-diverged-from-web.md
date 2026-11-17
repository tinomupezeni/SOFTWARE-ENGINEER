# Native Practice Renderer Diverged from Web

**Date:** 2026-11-05
**Project:** HBEC
**Environment:** Development
**Severity:** High
**Status:** Resolved locally; deployment verification pending

## Summary
Flutter's native practice page implemented a separate question renderer and answer flow. It could not reproduce the web PracticeModePage's markdown, diagrams, structured answers, marking, and review exactly. After fixing its API route and response parsing, the mobile screen still had this feature drift.

## Symptoms
- A paper could open through the native Flutter route but its rendering and interactions differed from web.
- Web-specific diagram, maths, and marking behavior was absent or approximated.

## Environment Details
- **Server/Host:** Local HBEC checkout; no production deployment in this session
- **Services Affected:** Student Flutter and web exam practice
- **Related Components:** Flutter PracticePage, web PracticeModePage, auth APIs
- **Time First Observed:** 2026-11-05

## Investigation Steps

### 1. Initial Diagnosis
Traced Flutter `/practice/:paperId` to its native page and web `/practice/:paperId` to PracticeModePage.

### 2. Root Cause Analysis
Compared the web component tree and question/answer services with the native Flutter implementation.

```bash
rg -n 'practice/:paperId|PracticeModePage|PracticePage' STUDENT/Frontend/src/App.tsx STUDENT/mobile_flutter/lib/core/navigation/router.dart
```

### 3. Key Findings
- The web renderer includes specialized question, diagram, markdown, marking, and review components.
- Native Flutter duplicated only part of that behavior.
- A WebView needs a secure session bridge because Flutter and the web client hold credentials differently.

## Root Cause
Two independent practice UIs were maintained while the requirement was exact web behavior.

## Prevention / Rule
**Guardrail:** Route mobile paper practice through the web PracticeModePage and gate the Flutter/web route mapping in `scripts/parity/web_flutter_parity.py`.

This keeps one rendering and marking implementation for the paper flow and flags route mapping drift.

## Solution

### Immediate Fix
Flutter's paper route now opens the web practice page in a WebView. A 45-second one-use Redis ticket exchanges the native session for a browser refresh cookie. The ticket is carried in the URL fragment and removed before exchange.

```bash
flutter test --no-pub test/features/exam/web_practice_url_test.dart test/features/exam/question_opening_test.dart
.venv/bin/python manage.py test apps.accounts.tests.test_mobile_web_handoff --verbosity 1
python3 scripts/parity/web_flutter_parity.py --no-report
```

### Long-term Fix
Deploy backend and web changes together, then verify an actual signed-in paper journey on an Android device before calling the experience exact in production.

## Prevention
- [x] Code changes required
- [x] Documentation to update
- [ ] Monitoring/alerts to add
- [ ] Configuration changes needed for deployed WEB_APP_URL

## Related Issues
- `Mobile_Apps/HBEC-2026-11-05-flutter-practice-questions-wrong-route.md`
- `Mobile_Apps/HBEC-2026-11-05-flutter-empty-questions-crash.md`

## References
- `STUDENT/Frontend/src/features/exam-practice/pages/PracticeModePage.tsx`
- `STUDENT/mobile_flutter/lib/features/exam/presentation/pages/web_practice_page.dart`

---

**Resolved By:** Codex
**Time to Resolution:** Same session
