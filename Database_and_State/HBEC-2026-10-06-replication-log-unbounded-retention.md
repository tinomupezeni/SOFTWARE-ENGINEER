# Replication logs and content stream grow without bound — no retention

**Date:** 2026-10-06
**Project:** HBEC Platform
**Environment:** Production (VPS `gpu-ndime`)
**Severity:** Medium
**Status:** Investigating

## Summary
`hbec_admin` is 856 MB, of which `replication_logs` alone is 622 MB (73%). The single biggest contributor: 9,141 `bulk.sync` rows averaging ~60 KB of full-payload JSONB each (551 MB), of which 8,706 are successfully `sent` — success rows are kept forever; nothing ever deletes or archives them. The Redis `content_sync` stream shows the same shape: 12,368 entries, `max-deleted-entry-id 0-0` (never trimmed), 76 stale consumer entries, ~11 MB and climbing. No urgency today (disk 68%), but both curves only go one way.

## Symptoms
- `pg_total_relation_size(replication_logs)` = 622 MB and growing with every sync.
- `XINFO STREAM content_sync`: `entries-added 12368`, `max-deleted 0-0`; group `student_sync_group` fully caught up (lag 0) yet nothing is ever trimmed.
- No incident attached — found during read-only capacity appreciation, 2026-10-06.

## Environment Details
- **Server/Host:** gpu-ndime
- **Services Affected:** admin backend DB growth; Redis memory (minor today)
- **Related Components:** `replication_logs`, `replication_stream_outbox` (all `published`, healthy), `content_sync` stream
- **Time First Observed:** 2026-10-06

## Investigation Steps

### 1. Initial Diagnosis
Ranked tables by `pg_total_relation_size` per database; ranked stream stats via `XINFO`. Consumer health confirmed first (lag 0, outbox all published) so retention work cannot break delivery.

### 2. Root Cause Analysis
There is simply no retention policy: no `DELETE`/partitioning on `replication_logs`, no `MAXLEN`/`XTRIM` on the stream, no consumer cleanup (`XGROUP DELCONSUMER`).

### 3. Key Findings
- Growth is dominated by *successful* rows — a retention policy loses no debugging value if it keeps failures longer than successes.
- `replication_stream_outbox` (15 MB, all `published`) is healthy and out of scope for urgency but wants the same policy eventually.

## Root Cause
Missing retention policy on two append-only replication records (Postgres log table, Redis stream).

## Prevention / Rule
**Guardrail:** every append-only operational table/stream ships with its retention in the same PR that creates it — a `MAXLEN ~` on stream creation (or a Beat `XTRIM`), a `DELETE WHERE created_at < now() - interval` Beat task for log tables (keep failures N× longer than successes), and a dashboard panel tracking bytes-per-table so the next unbounded curve is visible before it matters.

## Solution

### Immediate Fix
TBD — proposed: keep 30 days of `sent`, 180 days of `failed` in `replication_logs` (payloads aside, row counts are small); `XTRIM content_sync MAXLEN ~20000` + `XGROUP DELCONSUMER` for dead consumers; confirm sizes after.

### Long-term Fix
- Retention Beat tasks + Grafana panels per the guardrail above.
- Consider `payload` archival (object storage) instead of inline JSONB for `bulk.sync`-scale rows.

## Prevention
- [ ] Retention tasks + panels
- [ ] Review checklist item: "append-only store created → retention defined"
- [ ] Code changes required (Beat tasks, stream MAXLEN)

## Related Issues
- `Database_and_State/HBEC-2026-10-06-bulk-sync-retry-and-dns-failures.md` (same table, retry-counting facet)

## References
- Queries used: per-table `pg_total_relation_size` ranking; `XINFO STREAM/GROUPS content_sync`

---

**Resolved By:** TBD
**Time to Resolution:** TBD
