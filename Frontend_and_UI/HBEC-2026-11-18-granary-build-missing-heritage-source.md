# GRANARY_BUILD claimed sourced heritage content but carried no citation

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Development (Kids / Build It feature, not yet in production)
**Severity:** Low
**Status:** Resolved

## Summary
`GRANARY_BUILD`'s own file-header comment states "Every fact is from the
heritage corpus" and names three specific entries, but the `Build` object
itself carried no `source` field — the one place the owner's "sources are
never lost" rule actually surfaces to a reader/reviewer. Its sibling
`WALL_BUILD` (`zimbabweWall.ts`), built in the same PR, correctly sets
`source` on the `Build` object. The inconsistency meant a student seeing the
wall build gets a citation; a student seeing the granary build (built right
alongside it) does not, for content that makes the identical sourcing claim.

## Symptoms
Not user-facing yet — caught in code review before merge. Would have shipped
as a silent asymmetry between two sibling features built in the same PR.

## Environment Details
- **Server/Host:** N/A — frontend-only, `STUDENT/Frontend/src/features/junior/granary.ts`
- **Services Affected:** none (static content definition)
- **Related Components:** `build.ts` (`Build.source?: string`, optional),
  `BuildViews.tsx` (renders `{build.source && (...)}`), `zimbabweWall.ts`
  (the sibling build that does set `source`)
- **Time First Observed:** 2026-11-18, during code review of PR #155

## Investigation Steps

### 1. Initial Diagnosis
Code review noticed `WALL_BUILD` sets a top-level `source` field citing real
documents with page numbers, while `GRANARY_BUILD` (same PR, same `Build`
shape) has no `source` field at all, despite its own comment claiming sourced
content.

### 2. Root Cause Analysis
`GRANARY_BUILD`'s facts come from `heritage_corpus.json`'s general IK/problem
entries ("Hozi / isiphala granary", "Sealed drum vs raised hozi", "Zunde
raMambo grain reserve") — these entries carry no document/page citation of
their own, unlike the national-monuments corpus `WALL_BUILD` draws from
(which does carry `document` + `page` per entry). The author likely omitted
`source` because there was no page number to cite, rather than because the
content was unsourced.

### 3. Key Findings
- `Build.source` is optional (`source?: string`), so omitting it produces no
  type error — nothing forced the author to notice the gap.
- The content genuinely is sourced (named entries exist in the corpus); the
  citation was simply never written down on the object a reader actually sees.

## Root Cause
An optional field with no enforcement meant a real sourcing claim (stated in
a comment, visible only to someone reading the source file) never reached the
one place — the `Build.source` field — that actually surfaces to a student or
reviewer.

## Prevention / Rule
**Guardrail:** when a `Build`'s header comment claims heritage-corpus sourcing
in prose, require (by lint rule, PR template checklist item, or a build-time
assertion reading the comment against the field) that the object's own
`source` field is non-empty. A cheap version: a unit test enumerating every
`Build` export and asserting `source` is set whenever the file's own doc
comment contains the word "heritage corpus" or similar.

This closes the gap because it turns an unenforced convention (optional
field, prose claim) into something a missing citation actually fails.

## Solution

### Immediate Fix
Added a `source` field to `GRANARY_BUILD`, citing the three named
heritage-corpus entries by title (no page numbers available, since these
entries don't carry one — unlike the monuments corpus):

```typescript
source: 'From: "Hozi / isiphala granary", "Sealed drum vs raised hozi", "Zunde raMambo grain reserve" (heritage corpus).',
```

### Long-term Fix
Consider the lint/test guardrail described above so a future `Build` with a
similar sourcing claim in its comment can't ship without the field set.

## Prevention
- [ ] Add a test enumerating every `Build` export, asserting `source` is set
      when the file's own comment claims corpus sourcing
- [x] Code changes required (done)

## Related Issues
- Found during the same review pass as PR #155's community-paper topic-order
  bug (separate entry, `Backend_and_API/`).

## References
- `STUDENT/Frontend/src/features/junior/zimbabweWall.ts` (the correctly-cited
  sibling build)
- `AGENTIC_HARNESS/app/shared/data/heritage_corpus.json` (the corpus)

---

**Resolved By:** Claude Sonnet 5 (agent session, on behalf of tinomupezeni)
**Time to Resolution:** Same session as discovery
