# Synchronous Data Backfill Blocked in Pull Request Review

**Date:** 2026-10-03
**Project:** HBEC
**Environment:** Code Review (PR #51)
**Category:** Database & State
**Severity:** High (Prevented)

## Summary
During the code review of PR #51, a synchronous data backfill was discovered masquerading as a Django database migration (`0011_recount_question_counters.py`). The migration used a `RunPython` block to iterate over the entire `ExamPaper` table and issue `.update()` queries to recalculate question counts. 

This was identified as a critical deployment blocker because HBEC utilizes a Blue-Green deployment architecture with a shared PostgreSQL database. If this migration had been merged and run during deployment, it would have locked production rows and exhausted the active Blue environment's database connection pool, leading to a live production outage.

## The Technical Hazard
In a Blue-Green deployment on a single shared database:
- The idle deployment (Green) runs `manage.py migrate` upon startup.
- If a migration executes a long-running data update, it acquires row-level or table-level locks (`AccessExclusiveLock` or standard row write locks).
- The active deployment (Blue), which is serving live traffic, will attempt to write to those same rows.
- Blue's queries will queue behind Green's migration lock.
- Blue's application connection pool will rapidly fill up with blocked transactions, causing the web server to fail all incoming API requests (HTTP 500/502).
- The production site goes down before the Blue-Green flip even occurs.

## The Correct Architectural Pattern
Following the **Zero-Downtime Expand/Contract Migration Sequence** defined in the Principal Engineering Code Review Guide, data backfills must be completely isolated from schema migrations. 

The schema migration must only include the `ADD COLUMN` or `CREATE TABLE` instructions (the "Expand" phase). The data population must be executed as an asynchronous background job *after* the deployment completes.

## Resolution
1. **Migration Rejected:** `0011_recount_question_counters.py` was deleted from the PR.
2. **Logic Extracted:** The synchronous backfill loop was extracted into `ADMIN/adminBackend/apps/exam_papers/tasks.py` as an asynchronous Celery background task: `@shared_task def backfill_question_counters()`.
3. **Deployment Strategy:** The PR will deploy the task code first. Once Green is promoted to Blue and becomes the active production environment, an administrator will manually trigger the Celery task to populate the counters gracefully in the background without blocking the migration pipeline.

**Resolved By:** Antigravity
