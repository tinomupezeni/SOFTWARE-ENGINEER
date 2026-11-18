# The backend's picture-fence regex rejected briefs the frontend already rendered

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Development (found in `/code-review` of PR #158, before merge)
**Severity:** Medium
**Status:** Resolved

## Summary
The backend's `_PICTURE_FENCE` regex (`picture_store.py`, used by
`offer_reply_pictures` to record which ```picture briefs a reply carried)
required a newline immediately before the closing fence. The frontend's own
`DIAGRAM_FENCE` (`MarkdownRenderer.tsx`, the thing that actually parses and
renders the model's live output) has no such requirement. A well-formed brief
missing that one trailing newline would render a "making" placeholder on the
page that the backend never recorded as offered - so the picture could never
resolve, forever stuck or silently refused.

## Symptoms
- No live incident; found by code review comparing the two regexes directly.
- Would show as a picture placeholder that answers `refused` when asked for
  (no matching `offered` row), for a brief that otherwise parsed fine.

## Environment Details
- **Server/Host:** n/a (unit-level, cross-stack)
- **Services Affected:** AGENTIC_HARNESS conversation pictures (Friday /
  Learning Guide replies); STUDENT/Frontend `MarkdownRenderer`
- **Related Components:** `app/shared/picture_store.py` (`_PICTURE_FENCE`),
  `STUDENT/Frontend/src/shared/components/MarkdownRenderer.tsx`
  (`DIAGRAM_FENCE`)
- **Time First Observed:** 2026-11-18, code review

## Investigation Steps

### 1. Initial Diagnosis
`_PICTURE_FENCE = re.compile(r"```picture[ \t]*\n(.*?)\n[ \t]*```", re.DOTALL)`
vs frontend `/```(...|picture|...)\s*\n([\s\S]*?)```/g` - the backend's
`\n[ \t]*` immediately before the close has no frontend equivalent.

### 2. Root Cause Analysis
The backend's job here is to record which briefs the frontend will actually
act on - it must be at least as permissive as the parser whose behaviour it
is trying to mirror, never stricter.

### 3. Key Findings
- The existing test (`test_only_the_briefs_our_reply_carried_are_offered_and_then_drawn`)
  only exercised fences with a trailing newline, so the gap had no coverage
  before this.

## Root Cause
Two independent regexes for the same fence syntax, written at different
times, drifted to slightly different strictness.

## Prevention / Rule
**Guardrail:** the backend regex now matches everything up to the next
literal `` ``` `` with no newline requirement
(`r"```picture[ \t]*\n(.*?)```"`), mirroring the frontend exactly. A new test
(`test_a_fence_with_no_newline_before_the_close_is_still_offered`) pins this.
Any future change to either fence regex should be checked against the other
in the same commit - there is no shared source of truth for this pattern
(both are plain regexes, not a generated contract), so a reviewer must do it
by eye until one exists.

## Solution

### Immediate Fix
Relaxed `_PICTURE_FENCE` to drop the trailing-newline requirement. Verified
the existing malformed/unclosed-fence test cases are unaffected (the lazy
`.*?` still requires an actual closing fence to exist).

### Long-term Fix
Consider sharing one fence-matching definition (e.g. a small JSON/YAML
contract both runtimes read) if more diagram kinds keep drifting this way -
not done here, scope-limited to the reported bug.

## Prevention
- [x] Code changes required
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Related Issues
- Found alongside 5 other picture-engine bugs in the same `/code-review` of
  PR #158 - see the sibling entries dated the same day.

## References
- `AGENTIC_HARNESS/app/shared/picture_store.py`
- `STUDENT/Frontend/src/shared/components/MarkdownRenderer.tsx`
- `AGENTIC_HARNESS/tests/shared/test_picture_store.py`

---

**Resolved By:** Claude Sonnet 5 (code review + fix)
**Time to Resolution:** Same session
