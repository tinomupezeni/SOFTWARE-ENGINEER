# Flutter Mobile Audit: Project Guide Chat Was Faking Replies

**Date:** 2026-08-18
**Project:** HBEC (mobile_flutter)
**Environment:** Development / Production (feature never actually worked)
**Severity:** Critical (P0 finding)
**Status:** Resolved

## Summary
A full read-only audit of the Flutter mobile app (`STUDENT/mobile_flutter/`) found that the Project Guide chat feature was never actually calling the backend — every "reply" was a hardcoded string returned after a `Future.delayed`, meaning no student using Project Guide on mobile ever got real AI guidance, on any build, ever.

## Symptoms
- No user-reported symptom — the feature *appeared* to work (a message would send, a delay would pass, a reply would render), which is exactly why it went unnoticed. There was nothing for a user to complain about; the mock reply always "succeeded."
- Found only via direct source review during a structured audit pass (PHASE M-AUDIT.1), not via any log or crash.

## Environment Details
- **Server/Host:** N/A (client-side mock, no server involved)
- **Services Affected:** `mobile_flutter` Project Guide feature
- **Related Components:** `lib/features/project_guide/domain/repositories/project_guide_repository.dart`, `.../data/repositories/project_guide_repository_impl.dart`, `.../presentation/pages/project_guide_page.dart`
- **Time First Observed:** 2026-08-18, during a scheduled full-codebase audit

## Investigation Steps

### 1. Initial Diagnosis
Read every feature package end-to-end under `lib/features/`, comparing what each screen claimed to do against what its repository/data layer actually implemented, following `research/procedural/adding_a_feature.md`'s expected clean-architecture shape.

### 2. Root Cause Analysis
`ProjectGuideRepositoryImpl._sendMessage` (or equivalent) never touched `Dio`/`HarnessStreamClient` — it awaited a fixed delay and returned a canned string, a leftover scaffold from early development that nothing ever replaced.

### 3. Key Findings
- P0: Project Guide chat — fake reply, no real backend call (this file)
- P1: test coverage gap in the same feature package
- P2: `guided_learning_page.dart`'s 100ms auto-scroll `Future.delayed` callback had no `mounted` guard — a real, separate crash risk on rapid navigation
- P3: an orphaned duplicate `project_guide_page.dart` under `lib/features/curriculum/presentation/pages/`, unreferenced by the router
- Full findings written to `mobile_flutter/docs/audit_report.md`

## Root Cause
The chat send path was original scaffolding (a `Future.delayed` + hardcoded string) that was meant to be temporary during early UI development and was never wired to the real streaming endpoint before shipping.

## Solution

### Immediate Fix
Added `ProjectGuidanceEvent`/`ProjectGuidanceMetadata`/`ProjectGuidanceTextChunk`/`ProjectGuidanceDone` sealed classes and a real `getGuidance()` streaming method using the existing shared `HarnessStreamClient`; rewrote `_sendMessage` from the mock delay into a real `await for` loop over the SSE stream. Also added the missing `mounted` guard in `guided_learning_page.dart` and deleted the confirmed-orphaned duplicate page.

### Long-term Fix
None outstanding from this specific finding — remediation was scoped and completed in the same pass (PHASE M-REMEDIATE.4), committed under a strict file allowlist (PHASE M-COMMIT.2) as part of `fecdda8` (`feat(mobile): complete parity remediation, drift sync queue, and offline sync banner`).

## Prevention
- [x] Code changes required (committed)
- [ ] Backfill BLoC/widget tests for Project Guide chat send/receive (flagged P1, not yet done)
- [ ] A "does this repository method ever await a real I/O call" lint/review checklist item for future feature scaffolding, so a placeholder implementation can't silently ship

## References
- `mobile_flutter/docs/audit_report.md` (full audit findings)

---

**Resolved By:** Claude Code (Sonnet 5)
**Time to Resolution:** Audit ~1-2 hours; remediation ~1 hour
