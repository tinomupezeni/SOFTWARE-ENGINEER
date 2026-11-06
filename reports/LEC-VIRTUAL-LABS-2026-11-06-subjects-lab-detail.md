# Mobile Subjects and Lab Detail slice

**Date:** 2026-11-06
**Project:** LEC Virtual Labs
**Type:** Mobile feature implementation
**Status:** Completed

## Summary
The Flutter user flow now continues from Home into live Subject and Lab Detail
screens using the existing Django catalog API.

## Context / Trigger
The mobile app had a functional Home screen, but the next web flow nodes were
missing. Learners could see subject tiles but could not browse labs or inspect a
lab before starting it.

## Scope
Included Flutter routes for `/subjects/:subject` and `/labs/:slug`, live
catalog and public-manifest API calls, level filters, lab cards, detail
metadata, objectives, steps, safety, loading/error/empty states, and Home
navigation. Backend code, database schema, registration, assignments/classes,
and LabPlayer were out of scope.

## Method
Compared the React Subject and Lab Detail pages, lab CSS, API contract, and
public manifest shape. Implemented the corresponding native Flutter layout
while preserving the shared backend as the source of truth.

## Decisions & Findings
- Subject filters call the existing `/labs/?subject=&level=` endpoint.
- Lab Detail reads `/labs/{slug}/` and never receives answer-revealing
  marking data.
- Native Flutter cards and controls preserve the web's colors, radii, borders,
  metadata, and information hierarchy without changing server contracts.

## Changes Made
- Added `LabPublic` and `LabStep` Dart contract models.
- Added filtered catalog and public-manifest API methods.
- Added `SubjectScreen` and `LabDetailScreen`.
- Wired Home subject, assignment, and resume navigation.
- Added manifest parsing regression coverage and updated parity documentation.

## Verification
- `cd mobile_flutter && flutter analyze`
- `cd mobile_flutter && flutter test`
- `cd mobile_flutter && flutter build web`
- `git diff --check`
- Result: analysis clean, all tests passed, and web build completed.

## Follow-ups / Deferred
- Add attempt-aware Lab Detail actions and actual LabPlayer.
- Add the mobile navigation shell, Assignments, and Classes screens.
- Complete Login signup parity.
- Run Android/iOS real-device journey and screenshot comparison.

## References
- `frontend/src/features/labs/SubjectPage.tsx`
- `frontend/src/features/labs/LabDetailPage.tsx`
- `intelligent_memory_management/contracts/api.md`
- `mobile_flutter/lib/features/labs/lab_screens.dart`

---

**Completed By:** Copilot
**Duration:** One development session
