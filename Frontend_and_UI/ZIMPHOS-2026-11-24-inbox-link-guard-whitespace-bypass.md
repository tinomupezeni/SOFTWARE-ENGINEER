# InboxPage's off-site-link guard doesn't strip control characters before checking

**Date:** 2026-11-24
**Project:** ZIMPHOS
**Environment:** Development (caught during PR review, PR #3, before merge)
**Severity:** High
**Status:** Investigating

## Summary
PR #3 adds a field-app Inbox screen that renders distributor-sourced `ShopMessage.action_url` / `photo_url` values, guarded by an `isAppPath` (and analogous `isSafeImage`) check meant to block off-site navigation/image loads. The regex only rejects a leading `//` or `/\`. It does not account for leading ASCII tab/CR/LF characters, which the WHATWG URL spec has browsers strip during href/src resolution — so a path like `"/\t/evil.example"` passes the guard as written, but is normalized by the browser to `"//evil.example"`, a same-scheme, different-host destination.

## Symptoms
- No runtime symptom yet — caught during pre-merge code review (ECC `code-review` skill, high effort). `isAppPath("/\t/evil.example")` returns `true` in the current implementation.

## Environment Details
- **Server/Host:** Development / PR review only, not deployed.
- **Services Affected:** `frontend` (field app).
- **Related Components:** `frontend/src/pages/field/InboxPage.tsx:14`.
- **Time First Observed:** 2026-11-24, during review of PR #3.

## Investigation Steps

### 1. Initial Diagnosis
Reviewed the guard's regex against the set of inputs it's meant to reject (off-site absolute URLs, protocol-relative URLs, backslash tricks) and checked each against actual browser URL-resolution behavior, not just the regex's own pattern.

### 2. Root Cause Analysis
Browsers strip ASCII tab (`\t`), CR, and LF from a URL before parsing it (this is standard WHATWG URL parsing behavior, used historically as an XSS/open-redirect bypass technique against naive URL validators). The guard's regex checks the literal string for `//` or `/\` at the start but never normalizes/strips these characters first, so a string that doesn't literally start with `//` can still resolve to one.

### 3. Key Findings
- Both `isAppPath` (navigation) and `isSafeImage` (image `src`) share the same gap, since they're built on the same leading-character check.
- The message content (`action_url`, `photo_url`) is distributor-sourced, i.e. from an external party, making this an actual trust-boundary issue, not just defense-in-depth.

## Root Cause
URL-validation-by-regex that doesn't first normalize the string the way a browser's URL parser will. Stripped control characters are a well-known bypass class for this kind of hand-rolled guard.

## Prevention / Rule
**Guardrail:** any hand-rolled "is this URL same-origin / app-relative" check must first strip ASCII tab/CR/LF (and ideally run the candidate through the `URL` constructor against a known base and compare `origin`) before applying path-prefix logic. A unit test asserting the guard rejects `"/\t//evil.example"`, `"/\r/evil.example"`, and `"/\n/evil.example"` would catch this directly.

## Solution

### Immediate Fix
_Pending — to be fixed in this session._

### Long-term Fix
Replace the regex-based check with `URL` parsing against the app's own origin (or an explicit character-strip step before the existing regex), plus the control-character test cases above.

## Prevention
- [x] Code review caught this before merge (no production exposure).
- [ ] Add regression tests for tab/CR/LF bypass inputs.
- [ ] Documentation to update: none required beyond this log entry.
- [ ] Code changes required (guard fix) — in progress.

## Related Issues
- Found alongside other PR #3 findings; see sibling entries in this directory dated 2026-11-24.

## References
- PR: https://github.com/winstonjthinker/Zimphos/pull/3

---

**Resolved By:** Claude Sonnet 5 (code-review subagent, PR review session) — fix pending
**Time to Resolution:** Caught before merge; fix in progress
