# Dead-code audit removed a module still used by an offline probe script

**Date:** 2026-11-23
**Project:** HBEC
**Environment:** Development (caught during PR review, PR #174, before merge)
**Severity:** Medium
**Status:** Resolved

## Summary
PR #174 (`chore/dead-code-audit`) removed `AGENTIC_HARNESS/app/shared/guardrails/hallucination.py` as "imported by nothing," based on an AST import-graph/name-grep scoped to `app/`. The module is actually imported and called by `technology/audit_probes.py`, a script run directly (`python technology/audit_probes.py`), which sits outside the scanned `app/` tree and is therefore invisible to a static import-graph built only from in-package imports.

## Symptoms
- No runtime symptom yet — caught during a pre-merge code review of the PR, not in production. Had it merged unreviewed, `audit_probes.py` would fail with `ModuleNotFoundError` the next time it was run.

## Environment Details
- **Server/Host:** Development / PR review only, not deployed.
- **Services Affected:** `AGENTIC_HARNESS` (harness).
- **Related Components:** `app/shared/guardrails/hallucination.py`, `technology/audit_probes.py`.
- **Time First Observed:** 2026-11-23, during review of PR #174.

## Investigation Steps

### 1. Initial Diagnosis
Per the project's global rule to verify, not trust, a removal's safety claim, the PR's two actual removals were checked by grepping the *whole* repository (not just `app/`) for any reference to the removed name, including scripts run outside the normal import graph.

### 2. Root Cause Analysis
```bash
grep -rn "hallucination" technology/
# technology/audit_probes.py:46: from app.shared.guardrails.hallucination import check_hallucination
# technology/audit_probes.py:59: check_hallucination(...)
```
The audit's own method section documents this exact risk class and says it was caught once already for `app.shared.link_check` (also invoked via `python -m`, also invisible to an in-package import graph). The same risk recurred for a second module in the same PR and was missed.

### 3. Key Findings
- The audit's import-graph construction is scoped to `app/`; any caller living outside that tree (deploy scripts, probe/maintenance scripts under `technology/`, cron entry points) is structurally invisible to it regardless of how thorough the in-package analysis is.
- The audit's own report already names this failure mode for one module; it was not generalized into a check covering every removal candidate.

## Root Cause
A static import-graph analysis scoped to one subtree (`app/`) cannot see a caller that lives in a sibling subtree and is invoked as a standalone script rather than imported as a package. The dead-code audit treated "no AST-level importer found within the scanned tree" as sufficient evidence of safety, even though its own method section had already demonstrated that this is not sufficient for at least one other module in the same audit.

## Prevention / Rule
**Guardrail:** any dead-code removal candidate must be verified against a whole-repository text search (`grep -rn <module/symbol name>`), not just the import graph of the subtree the static analyzer scanned — specifically including script directories invoked via `python -m`/`python <path>` and any CI/deploy/cron entry points. Where the audit tooling itself already names this failure mode for one finding, every other finding in the same report must be re-checked against the same risk before merge, not just the one it was first noticed on.

This is the same class of finding as `6. Database Engineering.md`'s "Potemkin Tooling" generalization in the global guide library (declared-safe tooling output trusted without being checked against the one path it structurally cannot see) and reinforces guide `1. SDLC.md`'s existing dead-code-removal guidance.

## Solution

### Immediate Fix
Restored `hallucination.py` and its 4 tests from the pre-PR commit on branch `chore/dead-code-audit`; corrected the claims in `research/semantic/dead_code_audit/DEAD_CODE_REPORT.md` and `research/long_term_memory.md` to reflect the revert and why the name-search scope missed it.

```bash
git show <pre-PR-commit>:AGENTIC_HARNESS/app/shared/guardrails/hallucination.py > AGENTIC_HARNESS/app/shared/guardrails/hallucination.py
# plus its test file, restored the same way
git add -A && git commit -m "revert: restore hallucination.py, still used by technology/audit_probes.py" 
git push origin HEAD:chore/dead-code-audit
```

### Long-term Fix
Extend the audit's own verification step to whole-repo text search for every removal candidate before it's reported as safe, not only for the one case it happened to catch during this run.

## Prevention
- [x] Code review caught this before merge (no production exposure).
- [ ] Extend `dead-code-audit` skill/tooling to whole-repo grep every removal candidate, not just the scanned subtree's import graph.
- [x] Documentation updated (`DEAD_CODE_REPORT.md`, `research/long_term_memory.md`).
- [x] Code changes required (module restored).

## Related Issues
- Same PR also surfaced an architecture-level finding (admin "Guardrails" settings UI only logs instead of applying config) left as a PR comment for an owner decision, not fixed here — see PR #174 comment thread.

## References
- PR: https://github.com/Rest-creator/HBEC/pull/174
- `research/semantic/dead_code_audit/DEAD_CODE_REPORT.md`
- `SOFTWARE-ENGINEER/Principal_Engineer/engineering-guides/1. SDLC.md` ("Potemkin Tooling" generalization)

---

**Resolved By:** Claude Sonnet 5 (code-review subagent, PR review session)
**Time to Resolution:** Caught and fixed before merge, same review session
