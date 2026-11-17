# deploy_actor overwrote the git-tracked baseline tool, corrupting a fresh clone's demo

**Date:** 2026-11-17
**Project:** FRUGAL
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
`deploy_actor/deploy.py` wrote the approved candidate directly onto
`lab/tools/baseline-ssh-detector/detect.py` — the same file tracked in git
as the pristine "V1 starting tool" used to demonstrate Finding #001. That
mutated (already-improved) state was committed to GitHub as part of the
initial push, so a fresh clone's baseline detector silently stopped
reproducing the finding it was supposed to demonstrate.

## Symptoms
Cloned the repo fresh onto `mywealth-vm`, ran
`lab/scenarios/seed_distributed_ssh.sh`, and the detector's own printed
output contradicted its own narrative text: the script prints "producing
no alert" / "this is the exact IGM input," but the actual output showed
`ALERT: distributed brute-force against labuser -- 9 attempts across 3
distinct source IPs`.

## Environment Details
- **Server/Host:** Local dev machine (where the mutation was committed)
  and `mywealth-vm` (where it was discovered on a fresh clone)
- **Services Affected:** `lab/tools/baseline-ssh-detector/detect.py`,
  `lab/scenarios/seed_distributed_ssh.sh`
- **Related Components:** `deploy_actor/deploy.py`,
  `candidates/CAND-001-distributed-ssh-bruteforce/candidate.json`
- **Time First Observed:** 2026-11-17, during repo stand-up on
  `mywealth-vm`

## Investigation Steps

### 1. Initial Diagnosis
The scenario script's own printed alert output didn't match its hardcoded
narrative text about what the baseline tool does.

### 2. Root Cause Analysis
```bash
diff lab/tools/baseline-ssh-detector/detect.py candidates/CAND-001-distributed-ssh-bruteforce/detect.py
# (no output -- files were byte-identical)
```
Confirmed the two files were identical: the "baseline" tool in git was
actually the deployed CAND-001 candidate, not the original per-IP-only
detector.

### 3. Key Findings
- `deploy_actor/deploy.py` resolved its deploy target directly from
  `candidate.json`'s `target_tool` field, which pointed at the same path
  git tracks as the canonical starting artifact.
- Across this session's earlier deploy/rollback/redeploy testing, the
  file was left in its deployed state when the repo was committed and
  pushed in one shot (single squashed commit), so there was no earlier
  git history to recover the pristine version from either.
- The original pristine content had to be reconstructed from the
  session's own transcript (the first version written), not recovered
  from git.

## Root Cause
The deploy actor's mutable "live tool config" target and the git-tracked
"pristine reference artifact" were the same file path, so any deploy
permanently and silently altered what a fresh clone considered the
starting state.

## Prevention / Rule
**Guardrail:** a deploy actor's live/mutable target must never be the
same path as a git-tracked reference/fixture artifact. Enforce this by
construction: `deploy.py` now writes to `<reference_tool>.with_name("live.py")`,
a sibling file that is `.gitignore`d and seeded from the reference on
first deploy (see `Frugal/Docs/DECISIONS_LOG.md` ADR-008) — not by a
process rule that's easy to forget, but by the deploy target literally
never resolving to a tracked path.

This closes the exact gap: no number of deploys can ever change what a
fresh clone's reference tool does, because the deploy actor is
structurally incapable of writing there.

## Solution

### Immediate Fix
- Restored `lab/tools/baseline-ssh-detector/detect.py` to its original
  pristine content (per-IP-only detector).
- Changed `deploy_actor/deploy.py` to resolve its target as a sibling
  `live.py` rather than the reference tool path, seeding `live.py` from
  the reference on first deploy.
- Added `lab/tools/*/live.py` to `.gitignore`.
- Fixed two related latent bugs found in the same pass: both
  `lab/scenarios/seed_distributed_ssh.sh` and
  `seed_distributed_ssh_suricata.sh` resolved their gitignored output
  directories with `cd ... && pwd` before creating them, so they crashed
  on a fresh clone where those directories don't exist yet (`mkdir -p`
  now runs first).
- Re-ran the full deploy -> verify-pristine-reference -> verify-live.py
  cycle and the baseline scenario script, confirmed both now behave
  correctly.

### Long-term Fix
Already in place via ADR-008; no further action needed for V1's single
deploy target. If Frugal grows multiple deploy targets, apply the same
pattern (reference path != live path) to each.

## Prevention
- [x] Configuration changes needed (deploy.py target resolution)
- [ ] Monitoring/alerts to add — not applicable, dev-only lab
- [x] Documentation to update (ADR-008, README.md)
- [x] Code changes required

## Related Issues
None.

## References
- `Frugal/deploy_actor/deploy.py`, `Frugal/Docs/DECISIONS_LOG.md` ADR-008.
- `Frugal/lab/scenarios/seed_distributed_ssh.sh`,
  `seed_distributed_ssh_suricata.sh`.

---

**Resolved By:** Claude (Sonnet 5), with tinomupezeni
**Time to Resolution:** ~20 minutes
