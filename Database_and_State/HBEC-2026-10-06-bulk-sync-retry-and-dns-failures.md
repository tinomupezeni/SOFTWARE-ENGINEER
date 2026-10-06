# bulk.sync retries stuck at attempts=1; Sept 29 DNS failure cluster to harness

**Date:** 2026-10-06
**Project:** HBEC Platform
**Environment:** Production (VPS `gpu-ndime`)
**Severity:** Low (corrected from Medium — see Correction below)
**Status:** Resolved (no code change needed — already explained by a known, already-fixed bug)

## Correction (2026-10-06, same day, verified against live data)
The original write-up read `last_attempt_at` as "frozen" at 2026-09-29 11:00
for all 435 rows — that was a misreading of a `MAX(last_attempt_at)`-style
query result as if it applied uniformly. Pulled all 435 rows directly via
the admin API (`GET /api/replication/logs/?status=failed&event_type=bulk.sync`)
and the timestamps are spread across **313 distinct minutes from
2026-07-14 to 2026-09-29** — 2026-09-29T11:00 is only the *latest* one, not
a shared moment. This is the exact same 1,100-row `ReplicationLog` set
already fully root-caused the day before in
`Backend_and_API/HBEC-2026-10-06-content-replication-embedding-retry-orphaned-rows.md`:
all 435 `bulk.sync` failures (and 1,093 of the other 1,100 failed rows,
total) predate the fix that made `self.retry()` reachable at all
(`dispatch()` previously caught every exception and returned normally — no
raise, no retry — fixed 2026-08-27 by commit `7543724`). The
retry-correlation fix (`(target, event_type, payload_hash)` row reuse,
commit `a006e198`, 2026-09-18) is irrelevant here: with no retry ever
firing, there was never a second attempt for that fix to correlate.
`bulk.sync` does flow through the same shared `ReplicationService.dispatch()`
as every other event type — there is no separate, uncovered dispatch path.

## Summary
Of 9,141 `bulk.sync` replication rows, 435 are `failed`, every one with
`attempts = 1`. The error breakdown is 420 × `Temporary failure in name
resolution`, plus a handful of connection-refused/reset, all targeting
`harness`, spread across 313 distinct timestamps from 2026-07-14 to
2026-09-29 — not one incident, just the chronic pre-2026-08-27 "dispatch()
never raised" bug sampled across three months of ordinary `harness`
connectivity blips. Already explained; no further investigation needed.

## Symptoms
- `SELECT status, count(*), max(attempts) ... WHERE event_type='bulk.sync'` → `failed | 435 | 1`, all from one 11:00 cluster on 2026-09-29.
- No `bulk.sync` failure since — so the retry path is currently unproven in production either way.
- 435 failed full-payload rows (~26 MB) retained alongside the successes.

## Environment Details
- **Server/Host:** gpu-ndime
- **Services Affected:** admin → harness bulk replication (content freshness for AI marking context)
- **Related Components:** `ReplicationService.dispatch()`, `bulk.sync` task, harness bulk endpoint, DNS/container networking
- **Time First Observed:** 2026-10-06 (failures themselves: 2026-09-29 11:00 UTC)

## Investigation Steps

### 1. Initial Diagnosis
Grouped `replication_logs` by `(event_type, status)`; the `attempts = 1` ceiling on every failed row matches the exact bug shape HBEC's CLAUDE.md documents as fixed (unconditional `create()` + `attempts += 1` writing a fresh `attempts: 1` row per retry). Verified the correlation fix IS present in `master` code (`services.py` reuses rows on `(target, event_type, payload_hash)`).

### 2. Root Cause Analysis
TBD: (a) whether `bulk.sync` flows through the fixed `dispatch()` or a separate path that still creates-per-attempt; (b) whether the Sept-29 rows predate the fix's deploy (prod runs `sha-e44223f`); (c) which hostname failed DNS (check `HARNESS_SERVICE_URL` history / container DNS at the time — likely fallout of a network/compose event, same morning as other infra churn).

### 3. Key Findings
- Failure signature is environmental (DNS + refused/reset), not payload: 96% name resolution.
- All failures target `harness` (1,100 failed rows total across types, all `target_service='harness'`).

## Root Cause
Not a `bulk.sync`-specific gap. `dispatch()` caught every exception and
returned normally (no raise) until 2026-08-27 (commit `7543724`) — so
`self.retry()` was structurally unreachable for *any* event type across
that entire period, `bulk.sync` included. No DNS postmortem is needed: 420
of 435 errors are ordinary `harness` name-resolution blips scattered across
three months, not one outage.

## Prevention / Rule
Already covered by the existing guardrail in
`Backend_and_API/HBEC-2026-10-06-content-replication-embedding-retry-orphaned-rows.md`
(a deploy-time write-probe + the `reuse_log_id` test coverage). No additional
parametrized cross-path test is needed — there is one `dispatch()`, and every
event type including `bulk.sync` already goes through it.

## Solution

### Immediate Fix
None needed. Whether to replay these 435 specific rows is a separate,
lower-urgency judgment call (the underlying content may have since been
superseded by a later successful sync) — tracked as a Follow-up, not a bug.

### Long-term Fix
None needed beyond what the referenced entry already covers.

## Prevention
- [x] Root cause identified — already fixed, no `bulk.sync`-specific gap
- [ ] Judgment call: review whether any of the 435 rows' content still needs
      re-delivery, or was superseded by a later successful sync (same
      follow-up already listed in the referenced entry, not duplicated here)

## Related Issues
- `Database_and_State/HBEC-2026-10-06-replication-log-unbounded-retention.md` (same table, retention facet)
- `Backend_and_API/HBEC-2026-10-06-content-replication-embedding-retry-orphaned-rows.md` (the actual root-cause analysis for this entire 1,100-row failed set, including these 435)

## References
- `ADMIN/adminBackend/apps/replication/services.py:330-371` (correlation fix in `master`)
- Error sample: `[Errno -3] Temporary failure in name resolution` (420/435)

---

**Resolved By:** Tinotenda Mupezeni (correction + verification, 2026-10-06); original investigation by Muse Spark (opencode)
**Time to Resolution:** Same day — the "TBD" questions were already answered by prior-day work this entry hadn't cross-referenced yet.
