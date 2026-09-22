# harness-embeddings Broken: torch Security Bump Shipped Without the Paired transformers Bound

**Date:** 2026-09-22
**Project:** HBEC
**Environment:** Staging (`hbec-harness-embeddings-staging`) — image not yet
rebuilt on production at time of writing
**Severity:** High — the embedding backend is completely down; `/health`
reports healthy while the only endpoint that matters, `/v1/embeddings`,
500s on every call
**Status:** Diagnosed, not fixed (flagged to the user; version selection
needs the same OSV verification the original bump used, not a rubber-stamp
bump)

## Summary
Running the new `seed_syllabi.py` script against staging (part of deploying
the `experimental` merge) failed on every document: every call to
`harness-embeddings`'s `/v1/embeddings` returned 500, tripping the client's
circuit breaker after 3 failures. The container itself reports
`Up ... (healthy)` throughout — its healthcheck only proves the process is
alive, not that embedding actually works.

## Symptoms
```
HTTP Request: POST http://harness-embeddings:8090/v1/embeddings "HTTP/1.1 500 Internal Server Error"
{"name": "embedding_remote", "failures": 3, "reset_timeout": 30, "event": "circuit_opened"}
Syllabus seeding failed ... httpx.HTTPStatusError: Server error '500 Internal Server Error'
```
Container logs show the real failure on every request:
```
File ".../transformers/distributed/sharding_utils.py", line 28, in <module>
    from torch.distributed.tensor import DTensor
ImportError: cannot import name 'DTensor' from 'torch.distributed.tensor'
```

## Environment Details
- **Server/Host:** hbca-vps, `hbec-harness-embeddings-staging`
- **Services Affected:** every pillar that reads `curriculum_content`
  (heritage grounding, exam-paper corpus search, and now syllabus search) —
  anything going through `app/shared/embedding_service.py`
- **Related Components:** `AGENTIC_HARNESS/Dockerfile.ml`,
  `AGENTIC_HARNESS/pyproject.toml` (`[project.optional-dependencies].ml`)
- **Time First Observed:** 2026-09-22, first `/v1/embeddings` call attempted
  against staging since the dependency bump landed

## Investigation Steps

### 1. Initial Diagnosis
`docker logs hbec-harness-embeddings-staging` on the failing request showed
the traceback above, rooted in `sentence_transformers` → `transformers` →
`torch.distributed.tensor.DTensor` at model-load time
(`embedding_server.py`'s `_get_model()`), not in application code.

### 2. Root Cause Analysis
```bash
cd AGENTIC_HARNESS
git log -3 --format="%h %ai %s" -- Dockerfile.ml
git log -5 --format="%h %ai %s" -- pyproject.toml
git show 6756fe47 --stat
```
`Dockerfile.ml` pins `torch==2.7.1+cu128` as of commit `6756fe47`
(2026-09-19 15:44), replacing `2.4.1+cu121`, specifically to clear a
CRITICAL `torch.load` RCE (GHSA-53q9-r3pm-6pq6) and to get CUDA 12.8 kernels
for the VPS's Blackwell (sm_120) GPU. `pyproject.toml`'s `transformers`
bound (`>=5.5.0,<5.14`) was last touched by a *different* commit
(`a7ea5ea4`, 2026-09-19 14:20 — 84 minutes earlier) and was calibrated
against `torch==2.4.1`, per its own comment: *"combination measured working
in the running hbec-harness-embeddings container (torch 2.4.1+cu121 /
transformers 5.13.1 / sentence-transformers 5.6.0). Raise them together
with the torch pin, never separately."*

### 3. Key Findings
- The torch-bump commit's own message says this explicitly: *"This is not
  validated on hardware — the image resolves, and that is all that has
  been shown here. Run the embedding worker on the VPS and check
  `torch.cuda.is_available()` and one real encode before trusting it. ...
  Images for these have NOT been rebuilt yet at this commit."* Nobody ran
  that check before this session's seed load did, incidentally, three days
  later.
- `torch.distributed.tensor.DTensor`'s import path changed between
  `torch==2.4.1` and `torch==2.7.1`; whichever `transformers` version
  resolved under the `<5.14` ceiling still imports it the 2.4-era way,
  which no longer exists in 2.7.1's `torch.distributed.tensor`.
- No data loss: `curriculum_content` on staging had `points_count: 0`
  before and after the failed run — this is a brand-new corpus (the
  syllabus seeder), so `index_document`'s per-document
  delete-before-insert (`remove_document`) had nothing to delete. The
  failure is a clean "never inserted," not a destructive one.
- The container's healthcheck (`GET /health`) only proves the process
  answers HTTP, not that model loading or embedding works — the exact gap
  `ModelStatusBadge`'s `Record<Union, Config>` incident
  (`HBEC-2026-09-21-...` — different bug, same shape: something reported
  "fine" that structurally could not be) keeps recurring in different
  services.

## Root Cause
A security-motivated `torch` major-version bump (2.4.1 → 2.7.1) shipped in
`Dockerfile.ml` without raising `pyproject.toml`'s paired `transformers`
upper bound in the same commit, even though the surrounding code comment
explicitly instructs never to do exactly that. The bump commit itself
flagged the gap ("not validated on hardware") but the validation step was
never carried out before (or after) the image was rebuilt and deployed to
staging.

## Prevention / Rule
**Guardrail:** Before merging any change to `Dockerfile.ml`'s `torch` pin,
`pyproject.toml`'s `sentence-transformers`/`transformers` bounds in the
`ml` extra must be reviewed and raised in the *same commit* — the comment
already says this; it needs a mechanism, not another comment. Concretely: a
CI job (or pre-merge check) that diffs `Dockerfile.ml`'s torch version
against the last commit that touched it, and fails if `pyproject.toml`'s ml
bounds are unchanged in the same diff. Short of that, a one-line smoke test
that starts `harness-embeddings` and calls `/v1/embeddings` with a trivial
string, run in CI whenever either file changes — this incident's exact
failure mode (import-time crash inside the model-loading path) is trivially
caught by one real call and invisible to every other check that ran.

## Solution

### Immediate Fix
None applied. Flagged to the user rather than picking a version
combination unilaterally: the working combination on 2.4.1 was chosen by
OSV-verifying each candidate (per `6756fe47`'s own methodology, "verified
against OSV today rather than taken from a report"), and a same-quality
choice for 2.7.1 needs the same process, not a guess that happens to
import.

### Long-term Fix
1. Determine a `transformers`/`sentence-transformers` range that both (a)
   actually imports and runs under `torch==2.7.1+cu128` and (b) still
   clears whatever CVE floor motivated the current `>=5.5.0` lower bound.
2. Update `pyproject.toml`'s `ml` extra bounds together, rebuild
   `harness-embeddings`, and — per the original commit's own instruction —
   actually call `/v1/embeddings` with real input and check
   `torch.cuda.is_available()` before trusting the image.
3. Roll that verified image out to staging, then production, once validated.

## Prevention
- [ ] Configuration changes needed — pin update described above
- [ ] Monitoring/alerts to add — `/health` should exercise a real
      embedding call, not just process liveness, or a second `/health/ready`
      probe should
- [x] Documentation to update — this entry
- [ ] Code changes required — the CI/smoke-test guardrail above

## Related Issues
- None in this repo for this exact combination; same failure *class*
  (a reported-healthy check that couldn't detect a structurally broken
  path) as `HBEC-2026-09-21-...` Model Settings badge incident, unrelated
  root cause.

## References
- `AGENTIC_HARNESS/Dockerfile.ml` (torch pin, commit `6756fe47`)
- `AGENTIC_HARNESS/pyproject.toml` (`[project.optional-dependencies].ml`,
  commit `a7ea5ea4`)
- `AGENTIC_HARNESS/app/shared/embedding_service.py`,
  `AGENTIC_HARNESS/app/shared/corpus_index.py`
- `AGENTIC_HARNESS/embedding_server.py` (`_get_model()`, the crash site)

---

**Resolved By:** N/A — diagnosed, not fixed
**Time to Resolution:** N/A
