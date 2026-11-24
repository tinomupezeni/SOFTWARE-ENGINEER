# LocationSheet allows GPS-only save and fabricates a fake address string

**Date:** 2026-11-24
**Project:** MARITCHO
**Environment:** Development (caught in PR review)
**Severity:** Medium
**Status:** Workaround Applied (flagged, not fixed — architectural)

## Summary
PR #14 weakened `canSave` in `LocationSheet.tsx` to allow saving a job
location with only a GPS pin and no street address, substituting a
fabricated `"Pinned location (${canonical})"` string as the actual address
value sent to the backend instead of requiring the real street address the
hired worker needs to find the job.

## Symptoms
- Caught during code review of PR #14, not yet reproduced in production.
- A buyer taps "Use my current location" without typing a street address;
  the job is created/edited with `address` literally equal to `"Pinned
  location (Hillside)"` — a made-up string, not real door/landmark detail —
  and the worker who gets booked receives only a suburb-level GPS pin with
  no way to find the exact location.

## Environment Details
- **Server/Host:** N/A (code review, pre-merge)
- **Services Affected:** Job location entry (post job / edit job)
- **Related Components:** `frontend/src/features/jobs/LocationSheet.tsx`
- **Time First Observed:** 2026-11-24

## Investigation Steps

### 1. Initial Diagnosis
`/code-review` run against PR #14 flagged `canSave`'s relaxed condition and
the synthetic address string it now produces.

### 2. Root Cause Analysis
Read the `canSave` diff: it now accepts a location with a resolved suburb
and GPS coordinates but no address text, and the save path falls back to
building a human-readable-looking but fake address string from the suburb
name, rather than leaving `address` empty or using a distinct "GPS only"
representation.

### 3. Key Findings
- This directly conflicts with AGENTS.md's "design for the worker's worst
  day" principle — the worker, not the buyer, bears the cost of an address
  that reads as real but isn't.

## Root Cause
The PR's goal (let buyers use GPS location without typing an address) was
implemented by synthesizing a string into the `address` field rather than
treating "GPS pin, no address" as its own distinct state the backend and
worker-facing UI understand.

## Prevention / Rule
**Guardrail:** this is left open for the team to decide — either keep
requiring a real street address even when a GPS pin is also captured, or
if GPS-only is intentionally supported, add a real "no street address, GPS
only" representation (e.g. `address: null` plus a boolean/marker) instead
of writing a fabricated string into the address field, so downstream UI can
tell the difference and prompt the worker accordingly.

Flagged as a PR review comment on #14 rather than fixed directly, since
this is a product/UX decision about whether GPS-only addresses should be
allowed at all.

## Solution

### Immediate Fix
None — left as-is in PR #14; posted as a review comment.

### Long-term Fix
Pick one of the two options above; if GPS-only stays supported, add a
schema field/flag to distinguish a real address from a synthesized one.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (pending author decision on PR #14)

## Related Issues
- GitHub PR Rest-creator/MARITCHO#14

## References
- PR review comment: https://github.com/Rest-creator/MARITCHO/pull/14#issuecomment-7132925942

---

**Resolved By:** Flagged by Claude Code (code review), left open pending team decision
**Time to Resolution:** N/A — open
