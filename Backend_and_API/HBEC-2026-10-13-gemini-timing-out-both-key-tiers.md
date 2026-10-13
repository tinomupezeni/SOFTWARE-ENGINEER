# Gemini (both primary and legacy key tiers) timing out live — AI marking and revision notes degraded

**Date:** 2026-10-13
**Project:** HBEC Platform
**Environment:** Production (`hbca-vps`)
**Severity:** High (real student-facing AI marking and revision-note generation failures, ongoing)
**Status:** Investigating (root cause external, not yet resolved — logged for continuity)

## Summary
Found during a routine pre/post-cutover stability sweep (unrelated to the
cutover itself — confirmed present both before and after it): direct
completion requests to `google/gemini-flash` (the primary pool) and
`google/gemini-flash-legacy` (the fallback pool added 2026-10-12) both hang
for the full timeout window instead of responding. Network connectivity to
Google's API from the VPS is fast and healthy. This is degrading both exam
marking and revision-note generation for real students right now.

## Symptoms
- Harness logs, repeated: `"Primary (google/gemini-flash) and all fallbacks
  (['fast/llama3.1-70b', 'ollama/llama3.2:3b']) failed. Last error: Fallback
  ollama/llama3.2:3b timed out after 20.0s"` — 219 occurrences in one hour
  on the then-live color alone.
- Error tracker: a live `500 LLMUnavailableError` on
  `POST /api/v1/revision/topics/.../cloze` at 2026-10-13T15:20:18Z, same
  failure shape — confirms this is not marking-specific, it's "Gemini is
  unavailable" across multiple pillars.
- A second, related symptom from the same root cause:
  `analytics/engine.py`'s `handle_exam_submitted` crashing with
  `TypeError: unsupported operand type(s) for /: 'NoneType' and 'int'`
  at `ratio = score / max_score if max_score > 0 else 0` — when marking is
  unavailable, `score` arrives `None`, and the `max_score > 0` guard
  doesn't protect against that case. 129 occurrences in the same window.
  **This second bug is real and worth fixing independently of the Gemini
  outage** — any future "marking genuinely pending" state will hit it too.

## Environment Details
- **Server/Host:** hbca-vps, `hbec-litellm`, `hbec-harness-blue`/`-green`
- **Services Affected:** `AGENTIC_HARNESS` (exam marking, revision notes,
  anything routed through `google/gemini-flash`)
- **Related Components:** `litellm` proxy, Google Gemini API, `analytics/
  engine.py`
- **Time First Observed:** at least 2026-10-13T15:20Z; still reproducing
  as of ~15:45Z

## Investigation Steps

### 1. Initial Diagnosis
Noticed during a pre-cutover log sweep as a large (219/hour) spike of
`ai_marking_unavailable_no_scheme` errors on the then-live color.

### 2. Root Cause Analysis
Ruled out causes in order of likelihood, cheapest check first:
```bash
# Direct completion against the primary pool
docker exec hbec-litellm python3 -c "...POST .../v1/chat/completions, model=google/gemini-flash..."
# -> httpx.ReadTimeout after 30s

# Is it specific to the NEW keys (rotated 2026-10-12)? Try the legacy tier too.
# -> also httpx.ReadTimeout after 20s - both tiers fail identically

# Is this a network/firewall problem, not a Gemini problem?
curl -s -o /dev/null -w '%{time_total}s %{http_code}' https://generativelanguage.googleapis.com/
# -> 0.3s, 404 (expected for a bare root path) - network path is fast and healthy

# Is the other paid provider also down, or is this Gemini-specific?
docker exec hbec-litellm python3 -c "...model=fast/llama3.1-70b..."
# -> 200 OK in 7.8s (slow, but working)
```

### 3. Key Findings
- Both Gemini key tiers (new primary, old legacy) fail **identically** —
  rules out a quota/rate-limit issue on one specific key set (quota
  exhaustion would typically return a fast `429`, not a hang).
- Basic network connectivity to Google's API host is fast and unaffected —
  rules out a firewall/DNS/routing problem on our side.
- Groq (a different provider entirely) works, just slower than usual —
  consistent with either a genuine Gemini-side degradation, or a
  coincidental broader slowness not yet understood.

## Root Cause
Not yet determined with certainty — the evidence points at something on
Google's side (the Gemini API itself, or the specific `gemini-flash-lite-
latest` model), since our own network path, both of our key sets, and a
different provider entirely were all checked and only Gemini specifically
hangs. Not ruled out: a request-shape issue specific to how `litellm`
v1.55.8 (an old pinned version) calls this particular model, though this
was working correctly as recently as 2026-10-12's key rotation work (real
completions confirmed fast and successful then).

## Prevention / Rule
Not applicable yet — no fix has been identified or applied; this is a
live, ongoing external dependency issue, not a code defect in our control
(aside from the separate `analytics/engine.py` `NoneType` bug below, which
has a clear fix).

**The `analytics/engine.py` bug, once confirmed, should be fixed with**: a
null check on `score` before the ratio computation (not fold it into the
`max_score > 0` guard — the two are independent null/zero conditions) —
*not yet implemented, deliberately deferred to a dedicated session rather
than folded into an unrelated stability sweep.*

## Solution

### Immediate Fix
None applied — this is logged for continuity and to avoid re-discovering
the same investigation from scratch in a future session. The existing
fallback chain (Gemini → Groq → GPU) is already degrading as designed:
Groq picks up some of the load (slowly), and the GPU tier (already known
down separately) would be the final fallback if it were healthy.

### Long-term Fix
To be determined once root cause is confirmed. Candidate next steps for a
follow-up session:
- Check Google Cloud's own status dashboard for `generativelanguage.
  googleapis.com` / Gemini API incidents around this time window.
- Check whether `gemini-flash-latest` (the vision pool's model, not the
  `-lite` alias the text pools use) is also affected — would further
  localize this to the lite alias specifically versus Gemini broadly.
- Fix the independent `analytics/engine.py` `NoneType` crash regardless of
  the Gemini outage's own resolution — it's a real bug that will recur
  any time marking is genuinely pending, Gemini outage or not.

## Prevention
- [ ] Root cause confirmed (external provider status not yet checked)
- [ ] `analytics/engine.py`'s `None`-score crash fixed
- [ ] Consider an alert on `ai_marking_unavailable_no_scheme` /
      `LLMUnavailableError` rate, since this ran for at least 25+ minutes
      generating 200+ failures before being noticed as a side effect of an
      unrelated stability sweep, not through active monitoring

## Related Issues
- `HBEC-2026-10-12-gemini-key-rotation-two-tier-fallback.md` — the legacy
  tier this incident confirms is *also* affected, not just the new primary
  keys (useful negative evidence: rules out a bad rotation as the cause).
- `HBEC-2026-10-12-gpu-tunnel-down...` (if logged) — the GPU tier, the
  third link in this same fallback chain, already known down separately;
  this incident means the chain is currently degraded at two of three
  tiers simultaneously.

## References
- `AGENTIC_HARNESS/app/shared/llm_client.py` (`call_llm`,
  `LLMUnavailableError`)
- `AGENTIC_HARNESS/app/analytics/engine.py:54` (the `NoneType` crash)
- `AGENTIC_HARNESS/app/exam_practice/marking/orchestrator.py:439`
  (`_escalate_to_ai`, where marking failures originate)

---

**Resolved By:** Not yet resolved — investigation ongoing
**Time to Resolution:** N/A (logged mid-investigation, ~20 minutes spent
narrowing root cause to "external, Gemini-side" before deferring further
work to a dedicated follow-up)
