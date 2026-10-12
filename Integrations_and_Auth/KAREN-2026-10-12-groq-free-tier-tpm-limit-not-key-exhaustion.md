# Groq 429s during heavy testing were a free-tier TPM cap, not exhausted keys

**Date:** 2026-10-12
**Project:** Karen (Friday voice assistant)
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary

User saw repeated `429 Too Many Requests` across all 4 configured Groq keys during a long live-testing session and asked whether the keys were exhausted. Verified directly against Groq's API that all 4 keys are valid and independently not rate-limited; the actual 429 body names the real constraint: an 8000 tokens/minute (TPM) cap on `openai/gpt-oss-120b` for the free/`on_demand` tier, with a single turn in this session requesting 5392 tokens against an already-used 5948 -- i.e. the limit is per-organization/per-model, not meaningfully multiplied by having more keys, and this session's rapid back-to-back test turns (each carrying full persona + context + tool definitions) was enough on its own to trip it.

## Symptoms

- HUD showed: `LLM provider returned 429 Too Many Requests: {"error":{"message":"Rate limit reached for model \`openai/gpt-oss-120b\` ... on tokens per minute (TPM): Limit 8000, Used 5948, Requested 5392 ..."}}`.
- User had configured 4 Groq keys (`GROQ_API_KEY` through `_4`) specifically for round-robin fallback and was unsure whether the rotation logic was working or whether all 4 had separately run out of quota.

## Investigation Steps

### 1. Initial Diagnosis

Read the 429 body carefully: it names a specific numeric TPM limit (8000) and specific used/requested token counts for one request, not a generic "quota exhausted" message -- that's a hard capacity ceiling, not a credential problem.

### 2. Root Cause Analysis

Verified each of the 4 keys directly against Groq's API, independent of Friday:

```bash
curl -s -o /dev/null -w "%{http_code}" https://api.groq.com/openai/v1/models -H "Authorization: Bearer $key"
# all 4 keys: HTTP 200

curl -s https://api.groq.com/openai/v1/chat/completions -H "Authorization: Bearer $key" \
  -d '{"model":"openai/gpt-oss-120b","messages":[{"role":"user","content":"hi"}],"max_tokens":1}'
# all 4 keys: HTTP 200, real completion returned
```

All 4 keys were valid and not rate-limited moments after the 429 was observed in the app -- confirming the limit is tied to usage volume within a rolling window, not a broken/expired key.

### 3. Key Findings

- `groq_keys::should_try_next_key` already correctly excludes 400/404/5xx from triggering rotation and only rotates on 401/403/429 -- this logic was already verified correct in an earlier entry this session (`KAREN-2026-10-12-groq-tool-call-type-field-duplicated.md`) and is not the issue here.
- Friday's per-turn prompt (persona + desktop context + recent conversation + relevant memories + full tool definitions) is large enough that a single turn can request several thousand tokens, which is a meaningful fraction of an 8000 TPM free-tier cap on its own.
- A burst of live test turns within a short window (as in this debugging session) is sufficient to trip this limit even with multiple keys configured, since the cap is evaluated per-model/per-org on Groq's side, not meaningfully circumvented by key count alone at this usage rate.

## Root Cause

Not a bug: Groq's free/`on_demand` tier enforces an 8000 TPM cap on `openai/gpt-oss-120b`, and this session's rapid, repeated live-testing turns (each with a token-heavy prompt) were enough on their own to exceed it within a one-minute window.

## Prevention / Rule

**Guardrail:** none needed in application code; this is an external service capacity limit, not a defect. For future heavy interactive testing/debugging sessions, pace live test turns (a few seconds apart rather than continuous back-to-back) to stay under free-tier TPM caps, or switch the LLM provider to Ollama temporarily via the existing `set_llm_provider` UI control during a testing burst.

## Solution

### Immediate Fix

None required -- explained the mechanics to the user; no code change.

### Long-term Fix (considered, not applied)

Evaluated switching the default LLM provider to a self-hosted Ollama instance (`qwen2.5:3b`) running on a VM (`smepulse-vm`, reachable at `10.50.101.11:11434`) as a way to avoid Groq's TPM cap entirely. Measured a plain, context-free prompt at ~5 seconds response time on that VM, versus Groq's typical 1-2.5s LLM step with Friday's full context -- concluded Ollama is a reasonable **manual fallback** for when actually rate-limited (already supported, no further wiring needed), but not a good *default* replacement given the latency and capability gap (3B vs. 120B model) directly conflicts with this session's latency-reduction work.

## Prevention

- [ ] None (external service limit)
- [x] Documentation to update: note in `ARCHITECTURE.md` or `.env.example` that heavy interactive testing can trip Groq's free-tier TPM cap even across multiple keys, and that `set_llm_provider`/Ollama is the intended manual fallback for that case

## Related Issues

- `KAREN-2026-10-12-groq-tool-call-type-field-duplicated.md` -- confirmed `groq_keys.rs` rotation logic is correct and unrelated to this finding.

## References

- Groq rate limit docs (account/billing specific, not linked here)
- VM: `smepulse-vm` / `10.50.101.11:11434` (Ollama, models: `qwen2.5:3b`, `qwen2.5-coder:7b`, `nomic-embed-text`)

---

**Resolved By:** Claude (Claude Code)
**Time to Resolution:** ~10 min
