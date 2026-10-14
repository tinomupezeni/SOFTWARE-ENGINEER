# Groq Rate Limits Repeated Across Rotated Keys

**Date:** 2026-10-14
**Project:** Karen
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
Karen repeatedly received Groq 429 responses despite rotating through multiple configured API keys. The key pool tracked per-key token headers, but it treated each 429 as an invitation to immediately try another key. Groq quotas are organization-scoped, so this amplified rejected traffic instead of avoiding the shared exhausted window.

## Symptoms
- Interactive turns repeatedly returned rate-limit errors.
- Multiple configured keys did not reliably improve availability.
- Each 429 could trigger additional immediate requests through the remaining keys.

## Environment Details
- **Server/Host:** Local Linux desktop
- **Services Affected:** Groq chat completions and optional Groq TTS
- **Related Components:** `groq_keys.rs`, `brain/mod.rs`, `tts/groq.rs`
- **Time First Observed:** 2026-10-14

## Investigation Steps

### 1. Initial Diagnosis
Inspected Groq key rotation, response-header tracking, LLM retry behavior, and TTS fallback behavior. Compared the implementation with open-source quota routers and Groq-specific key pools.

### 2. Root Cause Analysis
The implementation had per-key token-budget ordering but no provider-wide cooldown. It did not honor `retry-after` or request-reset headers before attempting another key. Research also confirmed that Groq enforces important quotas at the organization level.

### 3. Key Findings
- Key rotation is useful for independently scoped credentials, but not for a shared organization quota.
- Groq supplies reset-duration headers that can bound a cooldown.
- Local Ollama and Piper are available fallback paths and avoid paid capacity.

## Root Cause
429 handling was key-local while the exhausted quota was often organization-wide. Immediate rotation caused request amplification and allowed repeated 429s during the same reset window.

## Prevention / Rule
**Guardrail:** Every Groq 429 must update a provider-wide cooldown from `retry-after` or Groq reset headers before another interactive cloud request is admitted.

This prevents blind key hammering during a shared quota window and makes the fallback decision deterministic.

## Solution

### Immediate Fix
Added a process-wide cooldown in `groq_keys.rs` and recorded it for both LLM and TTS responses. The cooldown prefers provider reset headers and falls back to 60 seconds.

### Long-term Fix
Ordinary interactive LLM turns automatically use Ollama while the Groq cooldown is active. Explicit provider-forced calls retain their requested behavior, and TTS remains local-first.

## Prevention
- [x] Configuration changes needed
- [x] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- `KAREN-2026-10-14-vad-blank-audio-trigger.md`

## References
- Groq rate-limit response headers
- `ARCHITECTURE.md` quota policy
- GitHub comparison: LiteLLM, Portkey Gateway, and `llm-keypool`

---

**Resolved By:** Copilot
**Time to Resolution:** Same session
