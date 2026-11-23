# Deploy workflow: bootstrap cutover arg missing, and a YAML syntax error broke the whole file

**Date:** 2026-11-23
**Project:** HBCA Classroom
**Environment:** Production (hbca-vps, first real deploy)
**Severity:** High
**Status:** Resolved

## Summary
Two independent bugs in `.github/workflows/deploy.yml`, found back to back right after the deploy pipeline first merged to `main`:

1. The `cutover` job called `ops/deploy/cutover.sh` with no argument, but that script requires an explicit color argument on the very first-ever run (before `active_color` exists) — would have failed the first real cutover.
2. A single-line `run: echo "Approved for cutover: ${{ ... }} @ ${{ ... }}"` step contained `: ` (colon-space) in an unquoted YAML plain scalar, which is invalid YAML (reads as a nested mapping key) — this broke parsing for the **entire workflow file**, not just that one step, so every push to `main` after the pipeline first merged failed in 0 seconds with zero jobs executed at all ("workflow file issue").

## Symptoms
- `gh run list` showed `completed/failure` at `0s` duration with zero jobs listed for several consecutive pushes.
- `gh run view <id>` (not `--log`, since no jobs ran to produce one) reported: "This run likely failed because of a workflow file issue."

## Environment Details
- **Server/Host:** hbca-vps (self-hosted GitHub Actions runner)
- **Services Affected:** the deploy pipeline itself, not any running application
- **Related Components:** `.github/workflows/deploy.yml`, `ops/deploy/cutover.sh`
- **Time First Observed:** 2026-11-23, immediately after the deploy pipeline's first merge to `main`

## Investigation Steps

### 1. Initial Diagnosis
Zero jobs ran at all — ruled out anything in the job steps themselves, pointed at the workflow file failing to parse or validate before scheduling.

### 2. Root Cause Analysis
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/deploy.yml'))"
# yaml.scanner.ScannerError: mapping values are not allowed here
#   line 111, column 40
```
Local YAML parsing reproduced the exact failure instantly, pinpointing the single malformed line.

### 3. Key Findings
- GitHub's own UI/API gives no line number or detail for a workflow-file-level failure beyond "workflow file issue" — a local `yaml.safe_load` was faster and more precise than anything the Actions API surfaced.
- The cutover-argument bug was found separately, by code review of `cutover.sh` against how `deploy.yml` called it, before any run reached that job.

## Root Cause
1. `cutover.sh`'s bootstrap-vs-steady-state branching wasn't matched by the calling workflow step.
2. A plain YAML scalar containing a bare `: ` is syntactically invalid outside a quoted or block (`|`) scalar — easy to introduce when writing a human-readable log line inline rather than as a block.

## Prevention / Rule
**Guardrail:** Run `python3 -c "import yaml; yaml.safe_load(open(path))"` (or an equivalent YAML linter) on any hand-written GitHub Actions workflow file before pushing it, especially after adding or editing any single-line `run:` step with a colon in its literal text. This is a zero-cost, pre-push check that would have caught the syntax error instantly instead of costing several failed-in-0-seconds pushes to discover.

## Solution

### Immediate Fix
- Always pass the already-computed target color explicitly to `cutover.sh` from the workflow (safe on every run — the script ignores the argument once `active_color` already exists).
- Converted the single-line `run: echo "...: ..."` step to a block scalar (`run: |`), matching every other multi-token step already in the file.

### Long-term Fix
None further — the guardrail above (pre-push YAML validation) is the standing practice now.

## Prevention
- [x] Configuration changes needed — both fixed in `deploy.yml`
- [ ] Monitoring/alerts to add
- [x] Documentation to update — noted in `docs/deploy/RUNBOOK.md`'s bug list
- [x] Code changes required

## Related Issues
- None

## References
- `.github/workflows/deploy.yml`, `ops/deploy/cutover.sh`

---

**Resolved By:** Claude (session with tinomupezeni)
**Time to Resolution:** ~15 minutes
