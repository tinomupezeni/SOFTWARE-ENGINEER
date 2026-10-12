# All 24 Playwright browser tool schemas sent on every turn, burning Groq's TPM budget

**Date:** 2026-10-12
**Project:** Karen (Friday voice assistant)
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary

Following up on `KAREN-2026-10-12-groq-free-tier-tpm-limit-not-key-exhaustion.md` (which confirmed Groq's 429s were a genuine 8000-TPM-per-key cap, not broken keys), investigated what was actually consuming that budget per turn. Found that `brain::tools::all_tool_defs()` unconditionally included all 24 MCP/Playwright browser-automation tool schemas on *every single turn*, including plain conversational exchanges ("hi", "what time is it") that could never use a browser. That's a large, constant, avoidable token cost repeated on every request regardless of need. Fixed by gating MCP tool inclusion behind whether the turn is a background/research task or explicitly mentions browsing/a URL -- the single highest-leverage lever on how long the shared Groq quota lasts across a session, more impactful than adding more keys.

## Symptoms

- User asked for "a long-lasting better solution" to repeated 429 rate-limit errors, after key rotation was already confirmed correctly implemented and the keys confirmed to have independent (not shared) 8000 TPM budgets.
- No single turn should plausibly need 5000+ input tokens for a short voice command, yet that was the observed request size in an earlier 429 error body (`Requested 5392` tokens for one turn).

## Investigation Steps

### 1. Initial Diagnosis

Verified via direct `curl` against Groq's chat-completions endpoint with each key that per-key `x-ratelimit-remaining-tokens` values were distinct and independently decrementing -- confirming 4 separate 8000 TPM budgets (32000 TPM combined), ruling out "keys share one pool" as the explanation for fast exhaustion.

Checked `brain/mod.rs`'s retry loop and confirmed it already cycles through all configured keys on 401/403/429 before failing (`groq_keys::should_try_next_key`), so a 429 reaching the user means *every* key was simultaneously near its cap -- pointing at per-turn token cost as the real lever, not the rotation mechanism itself (which was already correct).

### 2. Root Cause Analysis

```rust
// brain/tools.rs
definitions.extend(crate::mcp::tool_defs());
```

This ran unconditionally inside `all_tool_defs()`, which is called once per agentic-loop turn in `run_agentic_inner` regardless of what the turn was about. Live logs showed `[mcp] 'playwright': 25 tools (24 advertised)` -- 24 full tool schemas (name, description, JSON parameter schema) serialized and sent to Groq on every single request, including ones the fast-path/router didn't already intercept (i.e. most real conversational turns that reach the LLM at all).

### 3. Key Findings

- Native tools (open_app, set_volume, read_file, etc.) are small and always relevant -- no gating needed there.
- MCP/Playwright tools are comparatively large (full browser-automation parameter schemas) and only ever useful for research/background tasks or an explicit browsing request -- a small, clearly-identifiable subset of real turns.
- Background/research tasks (the feature added earlier in this session) always need these tools by definition, so the gate must not accidentally exclude them for that path.

## Root Cause

Tool-definition assembly had no concept of "does this turn need browser tools" -- it always included the full registry, so every turn paid the token cost of a capability it almost never used.

## Prevention / Rule

**Guardrail:** any tool category added to the registry whose use is situational (not every-turn) must be gated behind an explicit need-check at the call site, the same way `needs_semantic_memory` already gates semantic memory lookups -- enforce via code-review checklist item for `brain/tools.rs`/`brain/mod.rs` ("is this tool category relevant to every turn, or does it need its own `needs_*` gate like memory/browser tools already have").

This generalizes: the same bloat will recur for any future large tool category (a second MCP server, a big native tool with a verbose schema) unless gating is the default assumption, not an afterthought.

## Solution

### Immediate Fix

- `karen-desktop/src-tauri/src/brain/tools.rs`: split `all_tool_defs()` into a thin wrapper (`include_mcp: true`, preserves existing behavior/tests) and `all_tool_defs_with(include_mcp: bool)`, which only extends with `mcp::tool_defs()` when `include_mcp` is true.
- `karen-desktop/src-tauri/src/brain/mod.rs`: added `needs_browser_tools(transcript, is_background_task) -> bool` -- always true for background/research tasks (passed via the existing `forced_provider.is_some()` signal from the research-task feature), otherwise keyword-gated (explicit "browse"/"website"/a URL/domain-like mention). Call site now computes `include_mcp` once and passes it through.
- Added a diagnostic log line (`tool definitions: N tools (...), M bytes serialized`) so future token-cost regressions are directly observable rather than requiring another investigation like this one.

```bash
cargo check --manifest-path karen-desktop/src-tauri/Cargo.toml   # pass
cargo test --manifest-path karen-desktop/src-tauri/Cargo.toml    # 69 passed
```

### Long-term Fix

- Consider the same treatment for conversation-history size and persona length if TPM pressure recurs after this fix -- not applied this session since MCP tool schemas were judged the dominant cost and the simplest, safest first lever.
- A smarter key-selection strategy (track each key's real remaining-token headroom from response headers and prefer the least-depleted key, instead of blind round-robin) was considered as a complementary improvement but deferred -- the token-cost reduction here is higher-leverage and lower-risk to ship first.

## Prevention

- [x] Code changes required (done)
- [ ] Guided live retest confirming the `tool definitions: ... bytes` log shows a large drop for ordinary conversation turns vs. a research/background turn
- [ ] Follow-up: smarter per-key budget tracking (deferred, noted above)

## Related Issues

- `KAREN-2026-10-12-groq-free-tier-tpm-limit-not-key-exhaustion.md` -- established the limit is real and per-key, setting up this investigation into what was actually consuming it.
- Research-task feature (same session) -- the source of the `forced_provider`/background-task signal this fix reuses to keep browser tools available exactly where they're actually needed.

## References

- Files: `karen-desktop/src-tauri/src/brain/tools.rs`, `karen-desktop/src-tauri/src/brain/mod.rs`, `karen-desktop/src-tauri/src/mcp.rs`

---

**Resolved By:** Claude (Claude Code)
**Time to Resolution:** ~35 min
