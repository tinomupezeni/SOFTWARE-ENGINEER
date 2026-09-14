# Student Frontend Has 3 Pre-Existing TypeScript Errors Despite CLAUDE.md Documenting "Zero Errors"

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Development
**Severity:** Low
**Status:** Investigating

## Summary
While removing an unrelated component (`PWAInstallPrompt`) from
`STUDENT/Frontend/`, ran `npm run typecheck` to confirm the removal
introduced no new errors, and found 3 pre-existing ones already present on
`master` before any change was made — contradicting the project's own
`CLAUDE.md`, which states (dated 2026-08-29): "Zero errors, under full
`strict` + `noImplicitAny`... any error is one you just introduced."
Confirmed these are not caused by this session's work via `git stash` +
re-run: identical 3 errors present with a completely clean working tree.

## Symptoms
```
src/features/exam-practice/api/examApi.ts(171,26): error TS18048:
  'response.data' is possibly 'undefined'.
src/features/exam-practice/pages/PracticeModePage.tsx(184,9): error TS2322:
  Type '{ question: Question; ...; }' is not assignable to type
  'IntrinsicAttributes & QuestionPaperProps'.
  Property 'onRemix' does not exist on type 'IntrinsicAttributes & QuestionPaperProps'.
src/features/exam-practice/pages/PracticeModePage.tsx(184,19): error TS7006:
  Parameter 'diff' implicitly has an 'any' type.
```

## Environment Details
- **Server/Host:** Local dev checkout, `STUDENT/Frontend/`
- **Services Affected:** None at runtime — this is a typecheck-only finding,
  not a reported bug in the running app. Whether it reflects a real latent
  bug in `PracticeModePage.tsx`'s exam-practice remix flow (the `onRemix`
  prop mismatch suggests a real prop-shape drift between `QuestionPaper`
  and its caller) hasn't been investigated further.
- **Time First Observed:** 2026-09-14

## Investigation Steps

### 1. Initial Diagnosis
```bash
npm run typecheck
# 3 errors, all in src/features/exam-practice/
```

### 2. Root Cause Analysis
```bash
git stash   # remove this session's unrelated PWAInstallPrompt-removal changes
npm run typecheck
# identical 3 errors, confirming they predate this session entirely
git stash pop
```

### 3. Key Findings
- Not a regression from any change made this session.
- The `onRemix` / implicit-`any` `diff` parameter pairing in
  `PracticeModePage.tsx:184` suggests a real, not-yet-adapted call site
  after some `QuestionPaperProps` change — worth a dedicated look, but out
  of scope for the task that surfaced this (removing an unrelated PWA
  banner).

## Root Cause
Not yet determined why these 3 errors exist when `CLAUDE.md` documents a
zero-error baseline as of 2026-08-29 — either they were introduced after
that date without the doc being updated, or the doc's claim was never
fully accurate. Not investigated further this session.

## Prevention / Rule
**Guardrail:** A CI check that runs `npm run typecheck` on every push to
`master` and fails the build on any error would have caught this the
moment it was introduced, rather than leaving a stale "zero errors"
claim in `CLAUDE.md` for anyone who trusts it at face value (as this
session initially did, before verifying independently).

This closes the gap because the actual failure mode is a documentation
claim silently going stale — a CI gate makes "zero errors" continuously
true rather than a point-in-time note nobody re-checks.

## Solution

### Immediate Fix
None applied — flagged for the user rather than fixing exam-practice code
unrelated to the actual task at hand.

### Long-term Fix
1. Fix the 3 real errors (likely a `QuestionPaperProps`/`onRemix` drift in
   `PracticeModePage.tsx` and an unguarded `response.data` access in
   `examApi.ts`).
2. Add the CI typecheck gate described above so this can't silently
   reaccumulate.
3. Update `CLAUDE.md`'s claim once actually verified true again.

## Prevention
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — CI typecheck gate, as above
- [ ] Documentation to update — `CLAUDE.md`'s "zero errors" claim, once
      the underlying errors are actually fixed
- [ ] Code changes required — fix the 2 real call sites in
      `src/features/exam-practice/`

## Related Issues
- None yet — first time this drift was noticed.

## References
- `STUDENT/Frontend/CLAUDE.md` (or the relevant section of the root
  `CLAUDE.md`) — "Zero errors, under full `strict` + `noImplicitAny`
  (since 2026-08-29)"
- `STUDENT/Frontend/src/features/exam-practice/api/examApi.ts:171`
- `STUDENT/Frontend/src/features/exam-practice/pages/PracticeModePage.tsx:184`

---

**Resolved By:** Not yet — flagged only, no fix applied
**Time to Resolution:** N/A
