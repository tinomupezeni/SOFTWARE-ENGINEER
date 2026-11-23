# PyMuPDF removal left two seed scripts still importing `fitz`

**Date:** 2026-11-23
**Project:** HBEC
**Environment:** Development (caught during PR review, PR #175, before merge)
**Severity:** Medium
**Status:** Resolved

## Summary
PR #175 (`feat/drop-pymupdf`) removes PyMuPDF (`pymupdf`/`fitz`, AGPL-3.0) from `AGENTIC_HARNESS/pyproject.toml` and `requirements.lock`, replacing every in-app PDF read with `app/shared/pdf_reader.py` (pypdfium2-based). Two maintenance scripts under `AGENTIC_HARNESS/seeds/tools/` — `export_syllabi.py` and `extract_syllabus_topics.py` — still did `import fitz` directly. Both scripts' own docstrings say to run them with the harness's Python environment, which after this PR no longer has PyMuPDF installed at all.

## Symptoms
- No runtime symptom yet — caught during pre-merge code review, not in production. Had the PR merged unreviewed, either script would fail immediately with `ModuleNotFoundError: No module named 'fitz'` the next time an operator ran it.

## Environment Details
- **Server/Host:** Development / PR review only, not deployed.
- **Services Affected:** `AGENTIC_HARNESS` (harness), specifically its seed/maintenance tooling, not the live request path.
- **Related Components:** `AGENTIC_HARNESS/seeds/tools/export_syllabi.py`, `AGENTIC_HARNESS/seeds/tools/extract_syllabus_topics.py`.
- **Time First Observed:** 2026-11-23, during review of PR #175.

## Investigation Steps

### 1. Initial Diagnosis
The PR's core claim ("the harness neither imports nor depends on PyMuPDF" after this change) was checked against the actual dependency manifest and a whole-tree grep for the removed import, not just the in-app code paths the PR description focused on.

### 2. Root Cause Analysis
```bash
grep -rl "import fitz\|import pymupdf" AGENTIC_HARNESS/
# AGENTIC_HARNESS/seeds/tools/export_syllabi.py
# AGENTIC_HARNESS/seeds/tools/extract_syllabus_topics.py
```
Both scripts need table-aware PDF reading (`find_tables()`-equivalent), which pypdfium2 does not provide on its own — the same reason the main app code was migrated to `pdfplumber` rather than bare pypdfium2 for table-bearing documents. The seed scripts were simply missed when the dependency was removed, because they aren't imported by the app's own import graph (they're standalone operator-run tools, the same blind-spot shape as the sibling dead-code-audit finding logged the same day).

### 3. Key Findings
- The sibling PR #176 (admin half of the same removal) had already converted these same two files to `pdfplumber` on its own branch — the fix here mirrors that existing conversion rather than inventing a new approach.
- No other stray `import fitz`/`import pymupdf` remained anywhere else under `AGENTIC_HARNESS` after the fix.

## Root Cause
A dependency removal was verified against the application's own import graph (the code paths `pyproject.toml`'s dependency list is meant to serve) but not against every script in the repository that happens to use the same dependency outside that graph — the identical blind spot documented the same day in the dead-code-audit PR (#174): a standalone operator-run script is invisible to checks scoped to the in-package import graph.

## Prevention / Rule
**Guardrail:** when removing a dependency, grep the *whole* repository for its import name(s) (`import fitz`, `import pymupdf`, and the package name in `requirements`/`pyproject.toml` lock files across every subtree, including `seeds/`, `scripts/`, `technology/`, and any other operator-tooling directory), not just the application's own import graph. A dependency removal PR's acceptance criteria should include "no remaining import of the removed package anywhere in the repository," verified by a repo-wide grep run in CI or by the reviewer, not assumed from the in-app code review alone.

## Solution

### Immediate Fix
Converted both scripts from `fitz`/PyMuPDF to `pdfplumber` (mirroring the identical conversion PR #176 already made to the same two files), verified with `py_compile`, confirmed a repo-wide grep for the removed import now returns nothing under `AGENTIC_HARNESS`.

```bash
grep -rl "import fitz\|import pymupdf" AGENTIC_HARNESS/   # now empty
git add -A && git commit -m "fix: convert seed scripts off PyMuPDF to pdfplumber"
git push origin HEAD:feat/drop-pymupdf
```

### Long-term Fix
Add a CI check (once Actions is unblocked — see HBEC project memory for the current billing block) that greps for removed-dependency import names across the whole repository on any `pyproject.toml`/`requirements.lock` diff that drops a package.

## Prevention
- [x] Code review caught this before merge (no production exposure).
- [ ] Add a repo-wide grep check for removed-dependency imports to CI once Actions is unblocked.
- [ ] Documentation to update: none required beyond this log entry.
- [x] Code changes required (both scripts converted).

## Related Issues
- `Backend_and_API/HBEC-2026-11-23-dead-code-audit-removed-still-used-module.md` — same root cause shape (a standalone script outside the scanned import graph), found the same day in a different PR.
- An architecture-level finding on the same PR (whether `pdf_reader.py`'s single flattened text block vs. PyMuPDF's real multi-block grouping matters for a future multi-column case) was left as a PR comment, not fixed — currently a no-op since no consumer uses block boundaries yet.

## References
- PR: https://github.com/Rest-creator/HBEC/pull/175
- Related draft PR: https://github.com/Rest-creator/HBEC/pull/176 (already had the correct conversion for these two files)

---

**Resolved By:** Claude Sonnet 5 (code-review subagent, PR review session)
**Time to Resolution:** Caught and fixed before merge, same review session
