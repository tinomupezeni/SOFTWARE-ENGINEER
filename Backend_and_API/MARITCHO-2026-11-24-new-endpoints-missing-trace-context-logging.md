# New job/vetting endpoints log without trace-context correlation

**Date:** 2026-11-24
**Project:** MARITCHO
**Environment:** Development (caught in PR review)
**Severity:** Low
**Status:** Workaround Applied (flagged, not fixed — pre-existing pattern)

## Summary
PR #14's new `PATCH /jobs/{job_id}` endpoint, and
`POST /workers/me/vetting/police-clearance`, log via plain f-strings with no
trace-context correlation, violating AGENTS.md Phase 5: "Check that all log
statements conform to the structured JSON template with trace context
correlation." Both endpoints open an OpenTelemetry span via
`tracer.start_as_current_span` but never attach it to the log record.

## Symptoms
- Caught during code review of PR #14, not yet reproduced in production.
- Logs from these two new endpoints can't be correlated to their
  OpenTelemetry span or parsed as structured JSON by the log pipeline —
  same as pre-existing violations elsewhere in these routers.

## Environment Details
- **Server/Host:** N/A (code review, pre-merge)
- **Services Affected:** `PATCH /jobs/{job_id}`,
  `POST /workers/me/vetting/police-clearance`
- **Related Components:**
  `backend/app/apps/jobs/interface_adapters/router.py`,
  `backend/app/apps/workers/interface_adapters/router.py`
- **Time First Observed:** 2026-11-24

## Investigation Steps

### 1. Initial Diagnosis
`/code-review` run against PR #14 flagged the two new log statements as
plain f-strings with no trace-context fields.

### 2. Root Cause Analysis
Confirmed this is not new PR #14 behavior in isolation — the same pattern
(span opened, log not attached to it) already exists elsewhere in both
routers. The PR simply added two more instances of an existing gap rather
than introducing a new one.

### 3. Key Findings
- Not blocking for this PR specifically, since fixing just the two new call
  sites would leave the rest of the codebase inconsistent.

## Root Cause
No shared structured-logging helper enforces trace-context attachment, so
each new log call site has to remember to do it manually, and several
don't.

## Prevention / Rule
**Guardrail:** this is left open rather than patched endpoint-by-endpoint —
the real fix is a structured-logging helper/wrapper (or a lint rule) that
makes trace-context attachment the default for any log call inside a
traced span, so new call sites can't opt out by omission.

Flagged as a PR review comment on #14 rather than fixed directly, since a
partial fix (two call sites) wouldn't close the actual gap.

## Solution

### Immediate Fix
None — left as-is in PR #14; posted as a review comment noting it tracks
the existing pattern.

### Long-term Fix
Build the shared structured-logging helper described above, then do a
single pass updating all non-conforming call sites at once.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (pending — repo-wide structured-logging helper)

## Related Issues
- GitHub PR Rest-creator/MARITCHO#14

## References
- PR review comment: https://github.com/Rest-creator/MARITCHO/pull/14#issuecomment-7132925942
- AGENTS.md Phase 5 Engineering Standards Checkpoint

---

**Resolved By:** Flagged by Claude Code (code review), left open pending structured-logging work
**Time to Resolution:** N/A — open
