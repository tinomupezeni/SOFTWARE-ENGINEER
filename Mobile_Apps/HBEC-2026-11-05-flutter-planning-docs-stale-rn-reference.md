# Flutter mobile planning docs still named the deleted React Native app as the production/reference client

**Date:** 2026-11-05
**Project:** HBEC (STUDENT/mobile_flutter)
**Environment:** Development (documentation/planning docs only — no runtime impact)
**Severity:** Low
**Status:** Resolved

## Summary
`STUDENT/mobile_flutter`'s own planning hub (`planning/state.md`,
`planning/procedural/feature_migration_workflow.md`) still stated, in the
present tense, that the Expo/React Native student app (`STUDENT/Mobile/`)
"remains the production client" and is "the reference implementation" every
migrated screen must match. That app was removed from the repo entirely on
2026-11-04 (commit `1fefa8934`, "Remove React Native student mobile app,
focus shifts to Flutter rewrite"). Any session reading this hub for guidance
after that commit would be told to compare against, or defer to, a directory
that no longer exists.

## Symptoms
- No runtime symptom — this is drift in a project's own planning/memory
  documentation, found while building a web↔Flutter parity tool and reading
  `planning/procedural/feature_migration_workflow.md` to see how feature
  migrations were meant to be verified.
- A session following that workflow doc's step 1 ("locate the RN screen...
  under `STUDENT/Mobile/src/features/...`") would hit a missing directory.

## Environment Details
- **Server/Host:** N/A (local repo documentation)
- **Services Affected:** None at runtime; affects any future session's
  planning/migration guidance for `STUDENT/mobile_flutter`
- **Related Components:** `STUDENT/mobile_flutter/planning/state.md`,
  `STUDENT/mobile_flutter/planning/procedural/feature_migration_workflow.md`
- **Time First Observed:** 2026-11-05, while building
  `scripts/parity/web_flutter_parity.py`

## Investigation Steps

### 1. Initial Diagnosis
While building a parity-audit tool to compare the web app against the
Flutter app, checked `feature_migration_workflow.md` to confirm what this
project already considered its "reference implementation" for a migrated
screen, since the user's instinct ("match the web version") implied the
reference might already have shifted off React Native.

### 2. Root Cause Analysis
```bash
grep -rln "React Native\|STUDENT/Mobile\|RN app" \
  STUDENT/mobile_flutter/planning/ STUDENT/mobile_flutter/research/ \
  STUDENT/mobile_flutter/docs/
```
This returned 11 files. Most are historical/episodic logs correctly
describing RN in the past tense (e.g. "we migrated from RN") — accurate and
left untouched. Two files, however, made present-tense factual claims:
- `planning/state.md`: "React Native app remains the production client
  until Phase 5 completes."
- `planning/procedural/feature_migration_workflow.md`: "The reference
  implementation lives in `HBCA/STUDENT/Mobile/`."
Both became false the moment `STUDENT/Mobile/` was deleted; nothing updated
them as part of that removal commit, since it was framed as a cleanup of
dead code, not a planning-doc change.

### 3. Key Findings
- Doc drift of this kind is invisible until something tries to *use* the
  doc's instructions (here: an agent about to follow the migration
  workflow's step 1).
- The remaining 9 files that mention RN are legitimately historical and were
  not re-audited exhaustively this session — a full sweep for similarly
  stale present-tense claims elsewhere in the hub is a reasonable follow-up,
  not done here (scope was the two load-bearing docs actually consulted).

## Root Cause
A repo-cleanup commit removed a directory that several of a *different*
subproject's own planning/procedural docs still referenced in the present
tense as current/authoritative, with no process step that re-checks
dependent documentation when a referenced path is deleted.

## Prevention / Rule
**Guardrail:** None added this session — recommending one is harder to get
right than it looks (a generic "grep docs for deleted paths" pre-commit
check would also flag every legitimate historical reference, like the 9
files correctly describing RN in the past tense, producing enough noise to
get ignored). Flagging this as a case where the practical mitigation is
procedural, not mechanical: when a directory this central gets deleted, grep
sibling subprojects' own `CLAUDE.md`/planning docs for its path as a
dedicated step before closing out that removal, rather than treating it as
answered by the removal commit's own scope.

[No automated guardrail added — the two docs were fixed directly, and the
remaining reference sweep is a named follow-up, not a prevented recurrence.]

## Solution

### Immediate Fix
Not applicable — no service was down; this is a documentation-only issue.

### Long-term Fix
Updated both docs to state plainly that `STUDENT/Mobile/` was removed
(2026-11-04, commit `1fefa8934`) and that the web app (`STUDENT/Frontend/`)
is now the sole parity reference:
- `planning/state.md`: rewrote the "Current Context" status line and "North
  star" to drop the RN-production-client claim; added a cross-link to the
  new `scripts/parity/web_flutter_parity.py` tool.
- `planning/procedural/feature_migration_workflow.md`: title changed from
  "Migrating a Screen/Feature from React Native" to "Migrating a
  Screen/Feature" (the source is no longer always RN); reference
  implementation retargeted to `STUDENT/Frontend/`; step 4 updated to run
  the new parity script.

## Prevention
- [ ] Configuration changes needed — N/A
- [ ] Monitoring/alerts to add — N/A
- [x] Documentation to update — done for the two load-bearing docs; a
      full sweep of the remaining 9 historical-reference files is a
      follow-up, not done here
- [ ] Code changes required — N/A

## Related Issues
- Same session: built `scripts/parity/web_flutter_parity.py` (see
  `reports/HBEC-2026-11-05-web-flutter-parity-audit-tool.md`), which is what
  surfaced the need to read this workflow doc in the first place.

## References
- `STUDENT/mobile_flutter/planning/state.md`
- `STUDENT/mobile_flutter/planning/procedural/feature_migration_workflow.md`
- `STUDENT/mobile_flutter/planning/episodes/2026-11-05_web_flutter_parity_tool.md`
- Removal commit: `1fefa8934` "Remove React Native student mobile app, focus
  shifts to Flutter rewrite"

---

**Resolved By:** tinomupezeni (with Claude Code)
**Time to Resolution:** <1 hour (found and fixed in the same session as the
parity-tool build)
