# HBEC Student - Issue Log

Issues and solutions for the HBEC Student application.

**Project:** HBEC Student Platform
**Repository:** C:\Users\Dell\Documents\projects\HBEC

## All Issues

### 2026

#### September
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
