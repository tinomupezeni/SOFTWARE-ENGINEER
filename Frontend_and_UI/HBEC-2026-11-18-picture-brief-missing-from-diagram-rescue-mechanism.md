# A bare picture-brief JSON object could render as literal raw JSON

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Development (found in `/code-review` of PR #158, before merge)
**Severity:** Medium
**Status:** Resolved

## Summary
`MarkdownRenderer.tsx` already has a mechanism (`wrapUnfencedJson` +
`classifyDiagramBody`) that rescues a diagram the model emitted as bare,
unfenced JSON - wrapping it in its ` ```kind ` fence before it can leak to the
student as literal source text. The local `DiagramKind` type union this
mechanism is built on did not include `'picture'`, so a bare
`{"scene":...,"must_show":...,"alt":...}` object from a picture brief was
never recognized and never rescued - exactly the failure this mechanism
exists to prevent for the other six diagram kinds.

## Symptoms
- No live incident; found by code review reading `DiagramKind` against the
  PR's own new `picture` fence kind.
- Would show as a chat bubble containing raw JSON instead of a picture
  placeholder, if the model ever emitted a brief without its fence.

## Environment Details
- **Server/Host:** n/a (frontend, client-side rendering)
- **Services Affected:** Friday, Learning Guide (and any surface wiring
  `renderPicture`)
- **Related Components:**
  `STUDENT/Frontend/src/shared/components/MarkdownRenderer.tsx`
  (`DiagramKind`, `classifyDiagramBody`, `wrapUnfencedJson`)
- **Time First Observed:** 2026-11-18, code review

## Investigation Steps

### 1. Initial Diagnosis
`picture` was already present in the *other* three fence-matching constants
(`DIAGRAM_FENCE`, `UNTERMINATED_FENCE`, `EXPLICIT_TAGS`) - only the
shape-classification path (`DiagramKind`/`classifyDiagramBody`) was missing
it, which narrowed the fix to exactly that path rather than the whole
fence-handling pipeline.

### 2. Root Cause Analysis
`classifyDiagramBody` identifies a kind from its JSON body's shape (forces →
fbd, curves → plot, steps with layouts → scene, etc.) so a mislabeled or
unlabeled block still renders correctly. A picture brief's shape (`scene`
string + `must_show` array) had no corresponding check.

### 3. Key Findings
- `renderPicture` being `undefined` already no-ops cleanly for the ~21 other
  `MarkdownRenderer` call sites not wired to render pictures (`if (streaming
  || !renderPicture) return null;`) - adding `picture` to the shared fence
  constants changes behaviour only for well-formed `` ```picture `` content
  reaching those call sites (which still drops silently, unchanged), not a
  new crash risk.

## Root Cause
`DiagramKind` (and the two functions built on it) simply never carried the
new `picture` kind when it was added elsewhere.

## Prevention / Rule
**Guardrail:** `picture` added to `DiagramKind`; `classifyDiagramBody` now
recognizes a `scene` string + `must_show` array shape (checked after the
scene-kit's `steps`-based check, so the two never collide); `wrapUnfencedJson`
now wraps a classified `'picture'` body like the other five rescuable kinds.
A regression test (`wraps a bare picture brief the model emitted without a
fence`) pins it. The project's own rule - "adding a diagram kind touches the
contract, admin validator, harness copy, FE validator + renderer... and must
be looked at in a browser" - should be read to include this rescue mechanism
explicitly for any future kind.

## Solution

### Immediate Fix
Added `'picture'` to `DiagramKind`; added the shape check to
`classifyDiagramBody`; added `kind === 'picture'` to `wrapUnfencedJson`'s
eligible-kinds list.

### Long-term Fix
None needed; this closes the gap for the one kind that was missing it.

## Prevention
- [x] Code changes required
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Related Issues
- Found alongside 5 other picture-engine bugs in the same `/code-review` of
  PR #158 - see the sibling entries dated the same day.

## References
- `STUDENT/Frontend/src/shared/components/MarkdownRenderer.tsx`
- `STUDENT/Frontend/src/shared/components/__tests__/MarkdownRenderer.diagrams.test.tsx`

---

**Resolved By:** Claude Sonnet 5 (code review + fix)
**Time to Resolution:** Same session
