# HBEC Student - Issue Log

Issues and solutions for the HBEC Student application.

**Project:** HBEC Student Platform
**Repository:** C:\Users\Dell\Documents\projects\HBEC

## All Issues

### 2026

#### September
- [2026-09-11: Bulk Import Had No Path for "Just a Folder of PDFs"](./2026-09-11-bulk-import-had-no-path-for-a-bare-folder-of-pdfs.md)
- [2026-09-11: Staging's admin-backend/admin-worker/admin-beat Ran Stale Code Against an Already-Migrated Subject Schema](./2026-09-11-admin-backend-staging-ran-stale-code-against-migrated-subject-schema.md)
- [2026-09-11: "Upload New Paper" Was Fully Built End-to-End But Had No Button or Route Anywhere in the Admin UI](./2026-09-11-new-paper-upload-fully-built-but-unreachable-in-admin-ui.md)
- [2026-09-11: Live Practice UI Never Renders `sharedContext`/`subQuestions` — Structured Questions Showed Blank Bodies](./2026-09-11-practice-ui-never-renders-sub-question-content.md)
- [2026-09-11: 54 Student Papers Point at Harness Papers That No Longer Exist — Bulk Resync Cannot Reach Them](./2026-09-11-orphaned-student-papers-point-to-deleted-harness-papers.md)
- [2026-09-11: Internal Harness→Student Endpoints Share the Public Anonymous Rate Limit](./2026-09-11-internal-harness-endpoints-share-public-anon-rate-limit.md)
- [2026-09-10: Library Page's "Open Queue" CTA Links to Itself](./2026-09-10-library-review-queue-cta-links-to-itself.md)
- [2026-09-10: Deleting or Unpublishing an ExamPaper in Admin Never Removes It From Harness or Student Backend](./2026-09-10-exam-paper-delete-unpublish-never-retracts-downstream.md)
- [2026-09-10: Admin's "Learning Guide" Content Type Has No Replication Signal, and Nothing Downstream Would Read It Even If It Did](./2026-09-10-learning-guide-authored-content-never-consumed-anywhere.md)
- [2026-09-09: Admin Generation's Level String Never Matches Real Content, Blocking Grounding Platform-Wide](./2026-09-09-grade-name-vs-exam-tier-vocabulary-mismatch-blocks-all-generation-grounding.md)
- [2026-09-10: Admin Frontend Typecheck Is Red on a Committed Commit — `resetPassword` Test Uses Fields the Type Doesn't Have](./2026-09-10-reset-password-test-type-mismatch.md)
- [2026-09-10: Staging and Production Resolve the Same Image Tag — No Environment Separation](./2026-09-10-staging-and-production-share-the-latest-image-tag.md)
- [2026-09-10: `/opt/hbec` Is Not the "5 Files" CLAUDE.md Describes — Stale Checkout, Zero-Commit Git Repo](./2026-09-10-opt-hbec-stale-checkout-and-empty-git-repo.md)
- [2026-09-10: Production's Student Backend Was Missing 22 Subjects From Its Own Curriculum Mirror](./2026-09-10-production-student-backend-missing-22-subjects.md)
- [2026-09-10: Specimen Papers With No Year Can Never Replicate to Student Backend — NOT NULL Mismatch](./2026-09-10-null-year-specimen-papers-never-replicate-to-student.md)
- [2026-09-10: CLAUDE.md's "Push to main Deploys Production" Rule Is Stale — cd.yml Is workflow_dispatch-Only](./2026-09-10-claude-md-branch-rule-stale-main-push-does-not-deploy.md)
- [2026-09-10: Student last_login Never Recorded — Every Student Shows "Never" in Admin's Student List](./2026-09-10-student-last-login-never-recorded.md)
- [2026-09-10: Parent Signup Error Reporting Crashes Instead of Reporting the Actual Validation Error](./2026-09-10-parent-signup-error-flattening-keyerror.md)
- [2026-09-10: A Load-Testing Tool Created 142 Synthetic Accounts Directly on Production](./2026-09-10-load-test-tool-ran-against-production-142-accounts.md)
- [2026-09-10: Admin's Model Settings Feature Stored Keys in Plaintext and Never Actually Drove Live LLM Routing](./2026-09-10-model-settings-plaintext-key-storage-and-disconnected-from-real-routing.md)
- [2026-09-09: Admin Generation's Batch/Question-Count Limits Weren't Backed by Real Infra Capacity](./2026-09-09-admin-generation-limits-unbounded-relative-to-real-infra-capacity.md)
- [2026-09-09: Admin's Multi-Variant Batch Generation Was Structurally Broken on the Harness Side](./2026-09-09-paper-variant-identity-missing-blocked-multi-variant-batches.md)
- [2026-09-09: AI-Generated Papers Landed on the Wrong Subject, Invisible Under the Intended Filter](./2026-09-09-ai-papers-filed-under-wrong-subject-name-only-resolution.md)
- [2026-09-09: A Stale Celery Retry Reset an Already-Successful Admin Paper Back to Draft](./2026-09-09-generate-ai-paper-task-not-idempotent-against-its-own-retries.md)
- [2026-09-09: process_manual_entry Crashed Building Its Own Response (MissingGreenlet)](./2026-09-09-process-manual-entry-missinggreenlet-on-response-build.md)
- [2026-09-09: Admin Paper Question Mapping Was Wrong on Nearly Every Field, on Both Sides](./2026-09-09-admin-paper-question-mapping-wrong-on-every-field.md)
- [2026-09-09: Admin AI Paper Generation Crashed on Save With an ImportError for a Function That Never Existed](./2026-09-09-admin-paper-save-called-a-function-that-never-existed.md)
- [2026-09-09: Admin Paper Generation Truncated on "Structured" Questions, Then Crashed Instead of Failing Cleanly](./2026-09-09-admin-token-budget-not-type-aware-plus-unhandled-truncation-crash.md)
- [2026-09-09: Staging's Local Ollama Fallback and Harness Container Were Both Under-Provisioned Relative to Production](./2026-09-09-staging-ollama-fallback-and-harness-oom-drift-from-production.md)
- [2026-09-09: litellm's Own Router Timeout Silently Overrode the Harness's Admin GPU Budget](./2026-09-09-litellm-router-timeout-killed-gpu-calls-before-harness-timeout-mattered.md)
- [2026-09-01: Staging User Management Shows No Last-Login Activity](./2026-09-01-staging-login-audit-not-recording-last-login.md) *(root-caused and resolved 2026-09-09)*
- [2026-09-09: zchpc-hbca-vps Has No Celery Beat/Worker Containers — Admin Content Has Never Auto-Replicated There](./2026-09-09-zchpc-vps-missing-celery-beat-worker-no-replication.md)
- [2026-09-09: Staging Postgres/Pgbouncer Password Drift — Restarting Long-Lived Containers Exposed a Silent Credential Mismatch](./2026-09-09-staging-postgres-secret-drift-crash-loop.md)
- [2026-09-09: O-Level Silently Unselectable — Dropped From Every Exam Board's supported_levels](./2026-09-09-olevel-not-in-exam-board-supported-levels.md)
- [2026-09-09: Silent Auth Failure Falls Back to Stale Guest-Cached Subjects Instead of Refreshing the Token](./2026-09-09-stale-guest-subjects-on-silent-auth-failure.md)

#### August
- [2026-08-19: GitHub Actions Billing-Blocked — Manual Deploy Fallback Established and Documented](./2026-08-19-github-actions-billing-blocked-manual-deploy-fallback.md)
- [2026-08-19: Duplicate Empty-Shell Practice Papers from Two Uncoordinated Replication Paths](./2026-08-19-duplicate-practice-papers-replication-race.md)
- [2026-08-19: Harness Admin Paper Upload Was 500ing on Every Single Call Since a Bad Merge](./2026-08-19-harness-upload-pipeline-syntax-error-bad-merge.md)
- [2026-08-19: Every Harness Student-Context Call 500'd — Method Defined Under the Wrong Class](./2026-08-19-student-context-500-misplaced-method.md)
- [2026-08-19: Exam Practice Showed Codes Instead of Names — Paper Model Never Matched the API](./2026-08-19-exam-practice-paper-model-field-mismatch.md)
- [2026-08-19: Mobile Profile Page Showed Subject Codes and a Grade UUID Instead of Names](./2026-08-19-mobile-profile-showing-codes-not-names.md)
- [2026-08-19: Android 15 Crash on Every Keyboard Focus — Forced Old androidx.core Version](./2026-08-19-android-15-keyboard-crash-androidx-core-pin.md)
- [2026-08-18: Flutter APK and RN App Download Links Both Silently Broken](./2026-08-18-flutter-apk-not-downloadable-bind-mount-shadow.md)
- [2026-08-18: Flutter Mobile Audit: Project Guide Chat Was Faking Replies](./2026-08-18-flutter-mobile-audit-fake-project-guide-replies.md)
- [2026-08-18: ZB Payment Webhook Had No Defense-in-Depth Status Verification](./2026-08-18-zb-payment-webhook-missing-check-status.md)

#### July
- [2026-07-21: Admin Topic Deletion 500 Internal Server Error](./2026-07-21-admin-topic-delete-500.md)
- [2026-07-21: Admin Topics List Field Error](./2026-07-21-admin-topics-list-field-error.md)
- [2026-07-21: HBEC Missing Diagrams and Rollback Bug](./2026-07-21-hbec-missing-diagrams-and-rollback-bug.md)
- [2026-07-21: HBEC Healthcheck 404 — Network Changed](./2026-07-21-hbec-healthcheck-404-network-changed.md)
- [2026-07-21: HBEC Deployment Failure — JWT Keys](./2026-07-21-hbec-deployment-failure-jwt-keys.md)
- [2026-07-16: ZB Payment Webhook Lockout](./2026-07-16-zb-payment-webhook-lockout.md)
- [2026-07-15: DuckDB Payments 400](./2026-07-15-duckdb-payments-400.md)
- [2026-07-14: Flutter Database Migration and APK Download](./2026-07-14-flutter-database-migration-and-apk-download.md)
- [2026-07-14: Curriculum Sync and Sticky Cache Bug](./2026-07-14-curriculum-sync-and-sticky-cache-bug.md)
- [2026-07-14: Admin Frontend 502 Bad Gateway](./2026-07-14-admin-frontend-502-bad-gateway.md)
- [2026-07-13: Student Backend 502 — Docker Network Mismatch](./2026-07-13-student-backend-502-docker-network-mismatch.md)
- [2026-07-13: Redis Sentinel 500 Error](./2026-07-13-redis-sentinel-500-error.md)
- [2026-07-10: Redis Sentinel Failover — Celery Workers Crash with ReadOnlyError](./2026-07-10-redis-sentinel-failover-readonly-error.md)
- [2026-07-10: Admin Backend 502 — Docker Network Mismatch After Container Recreate](./2026-07-10-admin-backend-502-docker-network-mismatch.md)
- [2026-07-02: Mobile Flutter Audit](./2026-07-02-mobile-flutter-audit.md)
- [2026-07-01: HBEC System Audit](./2026-07-01-hbec-system-audit.md)
- [2026-07-01: System Audit Findings](./2026-07-01-system-audit-findings.md)
- [2026-07-01: Subject Filtering Bug](./2026-07-01-subject-filtering-bug.md)

#### June
- [2026-06-25: Database Connection Leak — PgBouncer](./2026-06-25-database-connection-leak-pgbouncer.md)
- [2026-06-13: VPS Systemd Lockup Recovery](./2026-06-13-vps-systemd-lockup-recovery.md)

#### May
- [2026-05-31: Production Stabilization and Mobile Readiness](./2026-05-31-production-stabilization-and-mobile-readiness.md)
- [2026-05-31: Production Routing — Google Auth Resolution](./2026-05-31-production-routing-google-auth-resolution.md)
- [2026-05-19: Mobile Local Dev Resolution](./2026-05-19-mobile-local-dev-resolution.md)
- [2026-05-12: Mobile Production Connectivity Bugs](./2026-05-12-mobile-production-connectivity-bugs.md)

## Quick Reference

### Check logs
```bash
# View application logs
docker compose logs --tail=100 [service_name]
```

### Common Issues
- To be documented as they occur

---

**Last Updated:** 2026-09-09
