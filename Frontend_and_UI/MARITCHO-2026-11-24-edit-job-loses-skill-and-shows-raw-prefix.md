# Editing a job posted under a specific skill lost the skill and showed a raw prefix

**Date:** 2026-11-24
**Project:** MARITCHO
**Environment:** Development (caught in PR review)
**Severity:** Medium
**Status:** Resolved

## Summary
`initialDescriptionFromJob` in `PostJobScreen.tsx` only stripped the
generic trade-label prefix (`"${tradeLabel(job.trade)}: "`) when pre-filling
the edit form, but jobs posted under a specific skill (via
`describeWithSkill`) are stored with a skill-specific prefix (e.g.
`"Geyser repair: "`) that this function never matched. The edit route also
always passed `initialSkillId={null}`, so the skill picker resolved back to
the generic trade-level skill regardless of what was originally posted.

## Symptoms
- Caught during code review of PR #14, not yet reproduced in production.
- Buyer posts a job under skill "Geyser repair" (trade Plumbing) with
  description "leaking valve" → stored as "Geyser repair: leaking
  valve\nNeeded: Today". Opening `/employer/jobs/{id}/edit` showed "Geyser
  repair: leaking valve" verbatim in the textarea and silently downgraded
  the skill picker to generic Plumbing; saving without re-picking the skill
  permanently lost the original specific skill and left "Geyser repair: "
  stuck as literal body text.

## Environment Details
- **Server/Host:** N/A (code review, pre-merge)
- **Services Affected:** Job edit flow (`/employer/jobs/[jobId]/edit`)
- **Related Components:** `frontend/src/features/jobs/PostJobScreen.tsx`,
  `frontend/src/core/format/trades.ts` (`describeWithSkill`, `ALL_SKILLS`)
- **Time First Observed:** 2026-11-24

## Investigation Steps

### 1. Initial Diagnosis
`/code-review` run against PR #14 flagged `initialDescriptionFromJob` as
only handling the trade-level prefix, not skill-level prefixes.

### 2. Root Cause Analysis
Read `describeWithSkill`: it prefixes `"${skill.label}: "` whenever a
skill's label differs from its trade's generic label. Read
`initialDescriptionFromJob`: it only ever tried to strip
`"${tradeLabel(job.trade)}: "`, so any skill-specific prefix passed through
untouched into the edit textarea. Read the edit page
(`app/employer/jobs/[jobId]/edit/page.tsx`): it hardcodes
`initialSkillId={null}`, so `initialSkill()` never had a skill id to
resolve from and fell back to the generic trade-level skill.

### 3. Key Findings
- The description-parsing side and the skill-selection side were both
  blind to which specific skill (if any) had been baked into the stored
  text, since neither derived it from the text itself.

## Root Cause
Prefix-stripping assumed a 1:1 trade→prefix relationship instead of
reconstructing which skill (if any) actually produced the stored prefix,
and the edit route never attempted to recover that skill at all.

## Prevention / Rule
**Guardrail:** a `skillFromDescription()` helper that scans `ALL_SKILLS` for
one matching the job's trade whose `"${label}: "` prefixes the stored
text, used both to strip the correct prefix and to seed the initial skill
selection — so the edit form can't silently disagree with what
`describeWithSkill` actually wrote. A round-trip test (post under a named
skill → open edit → description and skill unchanged) would catch any
future regression here.

## Solution

### Immediate Fix
Added `skillFromDescription(job)` in
`frontend/src/features/jobs/PostJobScreen.tsx`, used it to pick the correct
prefix to strip in `initialDescriptionFromJob`, and used it ahead of
`initialSkill()` when seeding the `skill` state so editing recovers the
original skill even though the edit route still passes
`initialSkillId={null}`.

### Long-term Fix
None further needed; covered by the immediate fix. Existing component tests
(`PostJobScreen` via `job-helpers.test.ts`) were re-run and pass.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (done, commit 319e337)

## Related Issues
- GitHub PR Rest-creator/MARITCHO#14

## References
- Commit 319e337 on branch `experimental`

---

**Resolved By:** Claude Code (code review + fix)
**Time to Resolution:** Same session
