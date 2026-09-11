# Governance Dashboard Blocked by SQLite Database Lock

**Date:** 2026-07-24
**Project:** FRUGAL_CORE
**Environment:** Development / Demo deployment
**Severity:** High
**Status:** Investigating

## Summary
The Frugal governance dashboard could not read recent governance events because SQLite returned `database is locked`. The failure occurred while querying `governance_events`, blocking audit activity display and indicating concurrent writers, long-lived transactions, or an unsuitable SQLite deployment pattern.

## Symptoms
- The application displayed `Waiting for database connection...`.
- The governance-events query failed with `sqlite3.OperationalError: database is locked`.
- Recent governance activity could not be loaded.

## Environment Details
- **Server/Host:** FRUGAL_CORE demo deployment
- **Services Affected:** Governance/audit dashboard
- **Related Components:** SQLite database, SQLAlchemy query for `governance_events`
- **Time First Observed:** 2026-07-24

## Investigation Steps

### 1. Initial Diagnosis
Captured the failing SQL query and confirmed the error was database lock contention rather than a missing table or malformed query.

### 2. Root Cause Analysis
The available history does not establish which process held the lock. The next investigation must identify active readers/writers, transaction duration, journal mode, and whether multiple processes write to one SQLite file.

### 3. Key Findings
- A read query was blocked by SQLite locking behavior.
- The UI presented the problem as database unavailability without exposing lock owner or age.
- The governance log is operationally important and needs a durable storage strategy.

## Root Cause
Undetermined; contention on the SQLite database file is confirmed.

## Solution

### Immediate Fix
Inspect active processes and transaction behavior, then safely restart only the confirmed lock holder if necessary. Do not delete database or journal files without a validated backup and recovery plan.

### Long-term Fix
Enable appropriate SQLite WAL/busy-timeout settings for a single-process demo, or move concurrent governance writes to PostgreSQL. Add lock-duration logging and a health check distinguishing connection failure from lock contention.

## Prevention
- [ ] Identify and document the lock holder and transaction path
- [ ] Configure bounded busy timeout and suitable journal mode for the demo topology
- [ ] Prevent long-lived transactions around dashboard/event writes
- [ ] Migrate shared concurrent governance storage to PostgreSQL if required
- [ ] Add alerting and lock-contention diagnostics

## Related Issues
- Guide 19: Issue-to-Verified-Production Engineering Workflow

## References
- Antigravity CLI history, FRUGAL_CORE workspace, 2026-07-24

---

**Resolved By:** Not yet resolved in available history
**Time to Resolution:** Unknown
