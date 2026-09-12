# CLAUDE.md's "Push to main Deploys Production" Rule Is Stale — cd.yml Is workflow_dispatch-Only

**Date:** 2026-09-10
**Project:** HBEC
**Environment:** CI/CD (GitHub Actions)
**Severity:** Medium
**Status:** Investigating

## Summary
Found while preparing to push this session's work to `main`. `CLAUDE.md`'s
"Cross-Cutting Rules" section states: *"Branch rule (2026-08-11): push to
master deploys staging, push to main deploys production."* Reading the
actual `.github/workflows/cd.yml`, this is only half true — the staging half
is correct, but production is `workflow_dispatch`-only, deliberately not
triggered by a push to `main` at all. The file's own header comment
confirms this was an intentional design decision, just never reflected back
into `CLAUDE.md`.

## Symptoms
No functional symptom — this is a documentation/reality mismatch that could
have caused real caution/confusion (a user or a future session might hold
off on pushing to `main`, or scramble to "disable CI/CD first," based on a
rule that no longer matches the code).

## Environment Details
- **Server/Host:** N/A — GitHub Actions config
- **Services Affected:** none functionally; documentation only
- **Related Components:** `.github/workflows/cd.yml`, `CLAUDE.md`
- **Time First Observed:** 2026-09-10, while confirming it was safe to push
  this session's work to `main` after manually promoting production earlier
  the same session

## Investigation Steps

### 1. Initial Diagnosis
Read `cd.yml`'s `on:` trigger block: `push: branches: [master]` plus
`workflow_dispatch` — no `push: branches: [main]` anywhere in the file.

### 2. Root Cause Analysis
The `deploy-production` job's own condition is explicit:
```yaml
if: github.event_name == 'workflow_dispatch' && github.event.inputs.environment == 'production'
```
And the file's header comment states this was a deliberate choice: *"main →
production ... deliberately NOT auto-deployed on push. Production only moves
via workflow_dispatch(environment=production, tag=<a staging-built sha>) - a
human decides when... `main`'s git ref can be fast-forwarded to match
afterward for bookkeeping; that update is not what ships the deploy."*
`CLAUDE.md`'s branch-rule note was never updated to match this redesign.

### 3. Key Findings
- Confirmed via `grep` across every active workflow (`cd.yml`, `ci.yml`,
  `security-scan.yaml`) that only `cd.yml` has any deploy capability
  (`ssh-action`/`scp-action`), and its production path requires an explicit,
  human-triggered `workflow_dispatch` — pushing to any branch, including
  `main`, cannot trigger a production deploy under the current design.

## Root Cause
Documentation drift: `cd.yml` was redesigned (production made
dispatch-only, promoting a specific staging-built tag rather than
rebuilding on every `main` push) without updating the corresponding rule in
`CLAUDE.md`.

## Prevention / Rule
**Guardrail:** A PR template checklist item requiring any change to a workflow's `on:`/`if:` trigger conditions to include a matching update to `CLAUDE.md`'s Cross-Cutting Rules in the same PR — enforced at review, not left to be remembered later.

This is the same class of doc/reality drift as `2026-09-10-opt-hbec-stale-checkout-and-empty-git-repo.md`; pairing the two changes in one PR is cheaper than a later session re-deriving what changed.

## Solution

### Immediate Fix
None needed for safety — confirmed no action required before pushing to
`main`. Verified this by reading the actual workflow files rather than
trusting the stale doc.

### Long-term Fix
Update `CLAUDE.md`'s Cross-Cutting Rules branch-rule note to describe the
real current behavior: push to `master` auto-deploys staging; `main` is a
bookkeeping ref for what's been promoted, and production only moves via a
deliberate `workflow_dispatch(environment=production, tag=<sha>)`.

## Prevention
- [ ] Update `CLAUDE.md`'s branch-rule section to match `cd.yml`'s actual
      current design
- [ ] When a workflow's deploy semantics change again, update this doc in
      the same commit rather than as a follow-up, so this doesn't drift a
      second time

## Related Issues
- Same pattern as the other doc/reality mismatches found this session
  (`2026-09-10-opt-hbec-stale-checkout-and-empty-git-repo.md`)

## References
- `.github/workflows/cd.yml`
- `HBEC/CLAUDE.md`, "Cross-Cutting Rules" section

---

**Resolved By:** Not yet — documented, doc update pending
**Time to Resolution:** N/A
