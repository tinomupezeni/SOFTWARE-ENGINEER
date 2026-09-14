# Production's Third Gemini Key Was Never Passed to the LiteLLM Container — Silently Running 2-of-3 Keys

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Production
**Severity:** Medium
**Status:** Resolved (repo fixed; production hand-patch still pending explicit deploy permission)

## Summary
While building the new provider-health-check capability (see the
companion feature commit), building the harness's key list against
`docker-compose.production.yml` surfaced that `GOOGLE_API_KEY_3` — which
`litellm_config.yaml` requires for the third Gemini key across three model
pools (`google/gemini-flash`, `google/gemini-pro`, `vision/gemini-flash`)
— was never included in the `litellm` service's `environment:` block in
`docker-compose.production.yml`, even though a real, valid value for it
already exists in production's `/opt/hbec/.env`. `GROQ_API_KEY_3` and
`GOOGLE_API_KEY_2` were both correctly wired; `GOOGLE_API_KEY_3` was
simply missing from the list.

## Symptoms
- No user-visible symptom on its own — the Gemini pool degrades to 2
  working keys out of 3 configured, which only becomes visible as reduced
  effective RPM/TPM headroom or as one less key of protection during a
  rate-limit event. Not the kind of thing that produces an error anyone
  would notice outside of a load spike.

## Environment Details
- **Server/Host:** hbca-vps, `docker-compose.production.yml` (both the git
  copy and, presumably, the disconnected `/opt/hbec` copy — see the
  companion litellm-config-drift entry for why production compose files
  are hand-maintained separately from git on this host)
- **Services Affected:** `hbec-litellm`
- **Time First Observed:** 2026-09-14

## Investigation Steps

### 1. Initial Diagnosis
Cross-checked which env vars `litellm_config.yaml`'s Gemini pool entries
actually require against what `docker-compose.production.yml`'s `litellm`
service passes through:
```bash
grep -n "GOOGLE_API_KEY" AGENTIC_HARNESS/litellm_config.yaml
grep -n "GOOGLE_API_KEY" docker-compose.production.yml
```
`GOOGLE_API_KEY` and `GOOGLE_API_KEY_2` were both present in the compose
file; `GOOGLE_API_KEY_3` was not.

### 2. Root Cause Analysis
Confirmed via `ssh hbca-vps` that `/opt/hbec/.env` genuinely has a real,
non-placeholder `GOOGLE_API_KEY_3` value already set — so this isn't a
missing-secret problem, purely a missing pass-through line in the compose
file's `environment:` block.

Also checked staging for the same class of gap: staging's compose file
**does** pass `GOOGLE_API_KEY_3` through correctly, but its actual value in
`.env.staging` is still the literal placeholder `your_third_gemini_key_here`
— a different root cause (a real secret never provisioned) producing the
same practical effect (2 working keys instead of 3).

### 3. Key Findings
- Production: wiring gap, real key exists, just never passed to the
  container.
- Staging: wiring is correct, but no real key was ever provisioned —
  needs a real value from whoever manages the Google AI Studio project,
  not a code change.

## Root Cause
`docker-compose.production.yml`'s `litellm` service `environment:` block
was missing a `GOOGLE_API_KEY_3: ${GOOGLE_API_KEY_3:-}` line that its two
sibling keys both have — an omission, not a deliberate choice.

## Prevention / Rule
**Guardrail:** The new provider-health check
(`app/shared/observability/provider_health.py`, see the companion feature
commit) will surface this class of gap automatically going forward: any
key referenced by `litellm_config.yaml` that never resolves to a real
value shows up as `harness_provider_key_live == 0` for that key label,
and if it's the last live key on a provider it trips `ProviderAllKeysDead`
— rather than remaining invisible until a load spike needs the missing
capacity.

## Solution

### Immediate Fix
Added `GOOGLE_API_KEY_3: ${GOOGLE_API_KEY_3:-}` to the `litellm` service's
`environment:` block in the git-tracked `docker-compose.production.yml`
(and, for consistency, confirmed `docker-compose.yml`/`docker-compose.staging.yml`
already had it). Not yet hand-patched into `/opt/hbec`'s disconnected
production copy — that requires the same explicit-permission,
backup-first process used for the earlier Groq/Prometheus production
edits, not done unilaterally as part of this observability work.

### Long-term Fix
- Provision a real (non-placeholder) `GOOGLE_API_KEY_3` value in
  `.env.staging`.
- Apply this same compose fix to `/opt/hbec`'s production copy.
- Structural fix already covered by the litellm-config-drift entry's own
  guardrail proposal (bake config into the image / CI-diff check) would
  have caught this too, since it's the same class of "hand-maintained
  production file silently missing something git has."

## Prevention
- [x] Configuration changes needed — fixed in git
- [ ] Configuration changes needed — production's live compose file still
      needs the same hand-patch; staging's `.env.staging` still needs a
      real key value
- [x] Monitoring/alerts to add — covered by the new provider-health check
- [ ] Documentation to update — none
- [x] Code changes required — done

## Related Issues
- Discovered while building
  `AGENTIC_HARNESS/app/shared/observability/provider_health.py` (see that
  commit) — the new capability that will catch this class of gap
  automatically from now on.
- `HBEC-2026-09-13-production-litellm-config-drift-from-git.md` — same
  general class of "hand-maintained production file drifts from git
  silently."

## References
- `docker-compose.production.yml`, `docker-compose.staging.yml`,
  `docker-compose.yml`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session as discovery (repo fix); production
hand-patch pending
