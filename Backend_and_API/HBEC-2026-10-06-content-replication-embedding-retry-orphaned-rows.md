# content.published's embedding-check retry created orphaned ReplicationLog rows stuck at attempts=1

**Date:** 2026-10-06
**Project:** HBEC
**Environment:** Production (Admin Backend → Agentic Harness replication)
**Severity:** Low (small volume, cosmetic to the audit trail — not a content-loss bug)
**Status:** Resolved (code fixed; deploy pending)

## Summary
The admin Replication dashboard (`https://admin.hbca.tech/replication`) showed
1,100 failed `ReplicationLog` rows, all targeting `harness`. Investigating
surfaced three separate, mostly-historical causes — two already fixed by
earlier commits, and one still live: `replicate_content_to_harness`'s
embedding-verification retry calls `ReplicationService.dispatch()` again
*after* the first dispatch already succeeded and marked the row `SENT`. The
row-reuse lookup only matches `PENDING`/`FAILED` rows (by design — a
successful delivery must never be silently reused), so that retry can never
find its own row and opens a new one every time, permanently stuck at
`attempts=1` even though the content had already been delivered once.

## Symptoms
- Admin Replication dashboard: 1,100 failed rows, `target_service=harness`,
  0 failed for `student`/`ai`.
- `error_message` distribution: 1,099 of 1,100 were network-level
  (`"[Errno -3] Temporary failure in name resolution"` ×636, `"[Errno 111]
  Connection refused"` ×378, `"timed out"` ×73, etc.) — not application bugs,
  just the harness being briefly unreachable at dispatch time.
- **1,097 of 1,100 had `attempts=1`** — the tell that retries were not
  accumulating on a single row, for one of three separate reasons (below).

## Environment Details
- **Server/Host:** `hbca-vps`, Admin Backend
- **Services Affected:** `hbec-admin-worker` (Celery), `apps/replication/`
- **Related Components:** `apps/replication/tasks.py`
  (`replicate_content_to_harness`), `apps/replication/services.py`
  (`ReplicationService.dispatch`)
- **Time First Observed:** found 2026-10-06 while triaging the Replication
  dashboard via direct API calls (same credentials/pattern as `hbec-errors-mcp`)

## Investigation Steps

### 1. Initial Diagnosis
Pulled all 1,100 failed rows via `GET /api/replication/logs/?status=failed`
(paginated, `page_size=100`). Grouped by `error_message` and `attempts`:
99.9% network-level errors, 99.7% stuck at `attempts=1` across a 3-month
span (2026-07-02 to 2026-09-30).

### 2. Root Cause Analysis — three distinct causes, disambiguated by timestamp
```
1,034 rows (before 2026-08-27): dispatch() caught every exception, logged
  FAILED, and returned NORMALLY (no raise) - so the task's
  `except Exception: self.retry()` was never reached, for any error type.
  Fixed by commit 7543724 (2026-08-27).

   ~49 rows (2026-08-27 to 2026-09-18): dispatch() now raised correctly and
  self.retry() DID fire, but the "reuse the same row across retries" lookup
  did not exist yet - every retry called ReplicationLog.objects.create()
  unconditionally. Fixed by commit a006e198 (2026-09-18).

    ~7 rows (after 2026-09-18, STILL LIVE until today): the row-reuse lookup
  now exists (services.py:338-355, keyed on target+event_type+payload_hash,
  status__in=[PENDING, FAILED]) - correct for every caller except
  replicate_content_to_harness's SECOND retry (tasks.py:174-184), which
  fires after the FIRST dispatch already succeeded and set status=SENT.
  That row no longer matches PENDING/FAILED, so the retry's next
  dispatch() call creates a fresh orphaned row - which, if ITS OWN
  transport call then times out for real, surfaces as exactly the observed
  pattern: a lone FAILED row, attempts=1, with no visible link to the
  original successful delivery.

     1 row: the already-understood `uuid` UnboundLocalError
  (HBEC-2026-09-30-harness-paper-replication-500.md), correctly retried to
  attempts=4 under the now-working row-reuse logic - proof the fix works
  when both pieces (raise + reuse) are present, which is exactly what the
  third cause above was still missing for this one code path.
```

### 3. Key Findings
- `services.py:91-100`'s own test (`test_a_successful_delivery_is_not_reused_by_a_later_one`)
  pins the *correct*, deliberate behavior for every other caller: a
  re-publish of identical content after a success must be a new delivery,
  not a retry. The content.published embedding-check is a genuine exception
  to that rule — it's polling the *same* delivery's embedding status, not
  publishing new content — and had no mechanism to say so.

## Root Cause
`ReplicationService.dispatch()` had no way for a caller to say "this retry is
for the exact same already-SENT row" — only the generic hash-based
PENDING/FAILED lookup, which is correct for every caller except this one.

## Prevention / Rule
**Guardrail:** `test_attempt_counting.py`'s new
`TestReuseLogIdSurvivesAnAlreadySentRow` class pins both sides: reuse works
when `reuse_log_id` is passed, and (unchanged) a second row opens without it
— so a future caller discovering this exact problem has the fix and the test
coverage already there, rather than reinventing it. `test_dispatch_contract.py`'s
new `test_content_task_retry_after_a_dispatch_success_reuses_the_same_row`
exercises the full task-level round trip Celery actually performs.

## Solution

### Immediate Fix
- `ReplicationService.dispatch()` gained an optional `reuse_log_id` parameter:
  when provided, looks up that exact row by ID first, bypassing the
  status-filtered hash lookup entirely. Every other caller is unaffected —
  the parameter defaults to `None` and the documented "a successful delivery
  is never reused" invariant holds for everyone else.
- `replicate_content_to_harness` gained a `replication_log_id` task parameter
  (kept out of `payload`/`retry_args` deliberately — stuffing it into the
  signed payload would change `payload_hash` on every retry, breaking the
  hash correlation this whole mechanism depends on, and would leak internal
  bookkeeping to Harness over the wire). The embedding-check retry now passes
  `kwargs={"replication_log_id": str(result.log.id)}`, so the next attempt
  reuses the exact same row regardless of its `SENT` status.

### Long-term Fix
None needed — this was the complete fix for the live bug. The 1,083 historical
rows from the two already-fixed causes are not touched by this change; whether
that specific historical content still needs re-delivery is a separate,
lower-urgency question (see Follow-ups) — not assumed safe to bulk-retry
without checking for staleness against newer edits of the same content.

## Prevention
- [x] Code change applied and tested
- [ ] Deploy to production (not yet done as of this writing)
- [ ] Review the 1,083 historical failed rows for whether their content was
      ever superseded by a later successful sync (a newer edit hashes
      differently and creates its own SENT row, which would make the old
      FAILED row harmless rather than representing live-missing content) —
      case-by-case, not a blanket retry
- [ ] Monitoring/alert to add: a Prometheus/Grafana panel or threshold alert
      on `ReplicationLog` rows stuck at `attempts=1` past some age, to catch
      the next instance of this pattern before it accumulates for months

## Related Issues
- `HBEC-2026-09-30-harness-paper-replication-500.md` (the `uuid` bug — the
  one row in this set that retried correctly, proving the fix works once both
  the raise and the row-reuse are present)
- Commit `7543724` (made `dispatch()` raise)
- Commit `a006e198` (added the hash-based row-reuse lookup)

## References
- `ADMIN/adminBackend/apps/replication/services.py` (`ReplicationService.dispatch`)
- `ADMIN/adminBackend/apps/replication/tasks.py` (`replicate_content_to_harness`)
- `ADMIN/adminBackend/apps/replication/tests/test_attempt_counting.py`
- `ADMIN/adminBackend/apps/replication/tests/test_dispatch_contract.py`

---

**Resolved By:** Tinotenda Mupezeni
**Time to Resolution:** Same session as discovery (code); deploy and
historical-row review remain open follow-ups.
