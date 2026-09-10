# A Load-Testing Tool Created 142 Synthetic Accounts Directly on Production

**Date:** 2026-09-10
**Project:** HBEC
**Environment:** Production
**Severity:** Medium
**Status:** Resolved (cleanup); root cause not yet identified

## Summary
Found while reviewing production's Student Management list ahead of clearing
out test accounts: 142 accounts matching the pattern
`loadtest-pool-<NNNN>-<hex>@hbec-loadtest.example.com`, all created within a
single 15-minute window (`2026-08-31 18:36:43` to `18:51:37`), all
`role=student`, all `auth_provider=email`, none ever logged in
(`last_login=None`), and zero attached real activity (no subscriptions, no
practice sessions, no papers, no payments — just an empty `StudentProfile`
per account, the minimum a signup creates). This is unambiguously the
output of an automated load-test run, and it landed on production's
database, not staging's.

## Symptoms
Admin's Student Management list showed 142 accounts with obviously synthetic
emails inflating the active-student count and cluttering any real review of
signups.

## Environment Details
- **Server/Host:** hbca-vps, production
- **Services Affected:** Student Backend (`accounts.User`, `accounts.StudentProfile`)
- **Time First Observed:** 2026-09-10, prompted by the user reviewing the
  Student Management list and asking for test accounts to be cleaned out

## Investigation Steps

### 1. Initial Diagnosis
User pasted a handful of visible rows showing the `hbec-loadtest.example.com`
pattern; querying by that domain directly returned 142 matches, not just the
few visible on one page.

### 2. Root Cause Analysis
Checked `date_joined` distribution: all 142 fall inside a 15-minute window on
2026-08-31, consistent with a single scripted run rather than organic
signups. Checked every FK pointing at `User` for attached data belonging to
these accounts — all zero except the expected `StudentProfile` (one each)
and some `OutstandingToken` JWT rows from the load test's own login calls.

### 3. Key Findings
- Root cause of *why* the load-test tool's target pointed at production
  instead of staging is not yet identified — no CI run, script, or config
  change from that exact time window was investigated as part of this
  cleanup (out of scope; this entry only covers finding and removing the
  resulting data).
- Deleting the 142 `User` rows cascaded correctly through `StudentProfile`
  (`CASCADE`), but left 196 `OutstandingToken` rows with `user=NULL` rather
  than deleting them — that FK uses `SET_NULL`, not `CASCADE`. Harmless (a
  token with no user can never be used), but worth knowing if anyone audits
  `OutstandingToken` counts later and wonders why some have no owner.

## Root Cause
Unconfirmed — a load-testing tool created real accounts against production's
API on 2026-08-31, target environment/config not investigated.

## Solution

### Immediate Fix
Captured the full list (id, email, username, date_joined) to a local file
before deleting, for an audit trail. Deleted all 142 accounts directly via
`User.objects.filter(email__icontains="hbec-loadtest.example.com").delete()`.
Verified `remaining: 0` afterward. Left two visually-similar-looking but
confirmed-real accounts untouched (one matching the ProjectFlow project
owner's name testing with a personal account, one a real-looking company
domain) — did not assume they were test data without checking.

### Long-term Fix
Find and fix whatever pointed the load-test tool at production's URL instead
of staging's, so this doesn't recur. Not investigated this session.

## Prevention
- [ ] Find the load-test tool/script and confirm its target config now
      points at staging, not production
- [ ] Consider a periodic check (or an admin dashboard signal) for accounts
      matching obviously-synthetic email patterns on production, so a
      recurrence is caught immediately instead of discovered by chance
      during a manual review
- [ ] Consider whether `OutstandingToken`'s `SET_NULL` (vs `CASCADE`) is
      intentional — orphaned null-user tokens will accumulate on every
      future account deletion too

## Related Issues
- None directly, but same general "found while reviewing something else"
  pattern as several other entries from this session

## References
- `STUDENT/hbec_backend/apps/accounts/models.py` (`User`, `StudentProfile`)

---

**Resolved By:** Claude (Sonnet 5), pairing with Tinotenda Mupezeni (cleanup only — root cause of the load-test misconfiguration not yet found)
**Time to Resolution:** Cleanup same session; root cause outstanding
