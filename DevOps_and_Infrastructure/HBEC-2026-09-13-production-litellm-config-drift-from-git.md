# Production's `litellm_config.yaml` Is Significantly Behind the Git-Tracked Version — Including an Already-Fixed GPU Timeout Bug

**Date:** 2026-09-13
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Investigating

## Summary
While diagnosing an "AI not working" report, fixing the Groq model
reference required editing production's actual
`/opt/hbec/AGENTIC_HARNESS/litellm_config.yaml` directly, since `/opt/hbec`
is a disconnected checkout (confirmed in an earlier session's finding,
`HBEC-2026-09-10-opt-hbec-stale-checkout-and-empty-git-repo.md`) — nothing
there tracks the real git repo. Diffing production's file against the
git-tracked `AGENTIC_HARNESS/litellm_config.yaml` revealed production is
missing several substantial fixes that are already written and merged:

1. **A documented GPU-timeout fix.** The git version pins
   `gpu/qwen14b` (and its `ollama/llama3.2:3b` alias) to
   `timeout: 330`, with a comment explaining exactly why: the router's
   global 20s timeout kills any real GPU generation call before it can
   finish (measured ~58 tokens/s, a 50-question batch projects to ~270s),
   so "every admin generation failed straight into `gpu_unavailable` even
   though the model itself was fine." Production still has no per-model
   timeout override on either GPU entry — it is still subject to exactly
   the bug this fix already solved, just never deployed.
2. **A whole Vision (Gemini) pool** (`vision/gemini-flash`, 3 keys) is
   entirely absent from production — vision requests have no keyed
   provider to fall back through to Claude, per the config's own
   `{"vision/gemini-flash": ["vision/claude-sonnet"]}` fallback rule that
   also doesn't exist in production yet.
3. **Prometheus metrics are off.** Git has `litellm_settings: callbacks:
   ["prometheus"]`; production doesn't, so `/metrics` on `hbec-litellm`
   presumably 404s and any dashboard/alert reading from it reads
   `up == 0` permanently — not because litellm is down, but because it
   never exposed the endpoint.
4. The GPU `api_base` is a hardcoded IP in production
   (`http://172.17.0.1:11436`) versus an env-var
   (`os.environ/OLLAMA_GPU_TUNNEL_URL`) in git — the git version is
   explicitly designed to be host-portable; production can't be without a
   manual edit.

## Symptoms
- No single symptom pointing directly at "config drift" — surfaced only
  by diffing files while fixing an unrelated issue. The GPU-timeout gap in
  particular could plausibly explain a class of "gpu_unavailable" failures
  distinct from (and possibly compounding) the ZCHPC tunnel connectivity
  issue found in the same investigation.

## Environment Details
- **Server/Host:** hbca-vps, `/opt/hbec/AGENTIC_HARNESS/litellm_config.yaml`
  vs. the git repo's copy
- **Services Affected:** `hbec-litellm` (production only — staging deploys
  this file from git via `git pull`, so it isn't affected)
- **Related Components:** `docker-compose.production.yml`'s litellm
  volume mount (`./AGENTIC_HARNESS/litellm_config.yaml:/app/config.yaml:ro`,
  resolved against `/opt/hbec`, not the real repo)
- **Time First Observed:** 2026-09-13

## Investigation Steps

### 1. Initial Diagnosis
```bash
diff <(ssh hbca-vps "cat /opt/hbec/AGENTIC_HARNESS/litellm_config.yaml") \
     AGENTIC_HARNESS/litellm_config.yaml
```
Ran this specifically to check whether the Groq model-reference fix
needed to land anywhere besides production's own file — found the diff
was far larger than just that one line.

### 2. Root Cause Analysis
Confirmed `/opt/hbec` has no working git history
(`HBEC-2026-09-10-opt-hbec-stale-checkout-and-empty-git-repo.md`), so
whoever wrote the GPU-timeout fix, the Vision pool, and the Prometheus
callback into the real repo had no mechanism that would have carried it
to production automatically — someone would have needed to manually copy
the file across, and that step was never done.

### 3. Key Findings
- This is the second file-level production/git divergence found this
  general area of the codebase (the first being the stale `/opt/hbec`
  checkout itself) — anything that lives as a plain file mount rather
  than baked into a versioned, rebuilt image is exposed to this same
  class of drift on this deployment model.
- The GPU-timeout fix's own comment describes symptoms
  (`gpu_unavailable` failures under real load) that match a plausible
  read of part of what's currently wrong on production, independent of
  the ZCHPC tunnel connectivity problem found in the same session.

## Root Cause
Production's compose file mounts `litellm_config.yaml` directly from
`/opt/hbec`'s local filesystem rather than from a versioned image layer,
and nothing in the deploy pipeline updates that file when the git-tracked
copy changes — it was correct once, at whatever point it was placed
there, and has silently fallen behind every fix made to the tracked copy
since.

## Prevention / Rule
**Guardrail:** Bake `litellm_config.yaml` into the `hbec-harness`/litellm
image build (or a dedicated small image) instead of bind-mounting it from
a hand-maintained host path, so a production deploy can only ever run the
config that shipped with the image it pulled — the same guarantee already
relied on for every other app service. If it must stay a bind-mount for
operational reasons, a pre-deploy CI check that diffs `/opt/hbec`'s copy
against the repo's and fails/warns on drift would catch this before it's
found by accident during an unrelated incident.

This closes the gap because the root cause is structural — a file that
lives outside the image and outside git's reach on that host will always
drift the moment anyone fixes something in the tracked copy and forgets
(or has no way to know) to also push it to `/opt/hbec` by hand.

## Solution

### Immediate Fix
Applied only the Groq model-reference fix directly to production's file
(hand-edited, original backed up to
`litellm_config.yaml.bak-YYYYMMDD` first) — deliberately did **not**
bundle in the GPU-timeout, Vision-pool, or Prometheus fixes in the same
pass, since the user asked for a scoped Groq fix now and wants ZCHPC
(which the GPU-timeout fix is directly relevant to) tackled as a separate
next step.

### Long-term Fix
Two decisions for the user, likely to be resolved together with the ZCHPC
tunnel investigation:
1. Whether to deploy the rest of the git-tracked config
   (GPU timeout, Vision pool, Prometheus callback) to production now or
   as part of that next session.
2. Whether to implement the image-bake or CI-diff guardrail above so this
   doesn't require another accidental discovery next time.

## Prevention
- [ ] Configuration changes needed — deploy the remaining git-tracked
      fixes to production (pending the ZCHPC session)
- [ ] Monitoring/alerts to add — a config-drift CI check per the
      guardrail above
- [ ] Documentation to update — none yet
- [x] Code changes required — the Groq portion only; done, see the
      companion entry

## Related Issues
- `HBEC-2026-09-10-opt-hbec-stale-checkout-and-empty-git-repo.md` — same
  underlying "`/opt/hbec` isn't really connected to anything" root cause,
  different symptom (that entry: stale source trees with zero effect
  since nothing builds from them; this entry: one specific *actually
  mounted and load-bearing* file drifting quietly).
- `HBEC-2026-09-13-groq-model-llama-3.3-70b-versatile-retired.md` — the
  fix that prompted this diff in the first place.
- Directly relevant to the upcoming ZCHPC GPU tunnel investigation: the
  GPU-timeout fix described here may explain part of what's currently
  broken there, independent of the tunnel's own connectivity problem.

## References
- `AGENTIC_HARNESS/litellm_config.yaml` (git-tracked, current)
- `/opt/hbec/AGENTIC_HARNESS/litellm_config.yaml` (production, now
  partially updated — Groq only)
- `/opt/hbec/docker-compose.production.yml` (the bind-mount definition)

---

**Resolved By:** Not yet — Groq portion fixed, the rest deferred to the
ZCHPC follow-up session
**Time to Resolution:** N/A (partial)
