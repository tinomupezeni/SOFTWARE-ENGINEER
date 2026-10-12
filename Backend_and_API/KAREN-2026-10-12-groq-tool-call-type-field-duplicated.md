# Streaming tool-call "type" field accumulated into an invalid value, causing Groq 400s

**Date:** 2026-10-12
**Project:** Karen (Friday voice assistant)
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary

Friday's agentic loop would intermittently fail mid-conversation with `LLM provider returned 400: ... 'messages.N.tool_calls.0.type' : value is not one of the allowed values ['function']`. The streaming tool-call parser in `brain/mod.rs` treated the `type` field the same way as `name`/`arguments` -- concatenating each delta's fragment onto the previous value with `push_str`. Unlike `name`/`arguments`, which genuinely arrive as string fragments, `type` is sent as a complete value on every delta for some providers/calls, so repeated `"function"` deltas accumulated into `"functionfunction"` (or worse with more deltas), which Groq's strict enum validation rejected on the next request that replayed that message as history.

## Symptoms

- Mid-conversation (reported at `messages.12`, i.e. several turns deep, not on the first request), Friday's HUD showed: `LLM provider returned 400 Bad Request: {"error":{"message":"'messages.12' : for 'role:assistant' the following must be satisfied[('messages.12.tool_calls.0.type' : value is not one of the allowed values ['function'])]" ...}}`.
- No voice feedback at all when this happened (see companion entry `KAREN-2026-10-12-pipeline-errors-never-voiced.md`), so it looked like Friday had simply frozen.
- User initially suspected their multi-key Groq rotation setup (`groq_keys.rs`) was misbehaving.

## Investigation Steps

### 1. Initial Diagnosis

Read the exact error text: a 400 (request/payload problem), not a 401/403/429 (credential/quota problem) -- ruled out key rotation immediately, since `groq_keys::should_try_next_key` correctly does not treat 400 as a rotate-worthy status (verified this is intentional and already tested: `does_not_rotate_on_request_or_server_errors` covers exactly this case).

### 2. Root Cause Analysis

The error names `tool_calls.0.type` specifically. Found the streaming delta accumulation in `brain/mod.rs`:

```rust
while accumulated_tool_calls.len() <= tc.index {
    accumulated_tool_calls.push(ToolCall {
        id: String::new(),
        kind: "function".to_string(),   // already defaults correctly
        function: ToolCallFn { name: String::new(), arguments: String::new() },
    });
}
let active_tc = &mut accumulated_tool_calls[tc.index];
if let Some(ref id) = tc.id { active_tc.id.push_str(id); }
if let Some(ref kind) = tc.kind { active_tc.kind.push_str(kind); }   // bug
```

`kind` (serialized as `type`) starts at the correct default `"function"`, but if the provider sends `"type": "function"` again on a later delta for the same tool-call index (not just the first, as the original code assumed), `push_str` appends it onto the already-correct default, producing `"functionfunction"`. This value gets pushed into the in-memory `messages` vec for this agentic-loop iteration and sent back to Groq on the *next* iteration (multi-step tool calling), which is when the enum validation rejected it -- explaining why the failure appeared several messages deep rather than immediately.

### 3. Key Findings

- `name` and `arguments` genuinely are fragmented across deltas per the OpenAI/Groq streaming tool-call format and must be concatenated.
- `type` is a fixed enum value (currently always `"function"`), never fragmented -- it should be assigned/overwritten, not accumulated.
- `id` uses the same `push_str` pattern; left unchanged since IDs are conventionally sent once (not re-sent per delta) and no evidence of a similar bug surfaced for it, but it's a similar latent risk if a provider ever resends it.

## Root Cause

Streaming delta accumulation applied the "concatenate fragments" pattern (correct for `name`/`arguments`) to a field (`type`) that is actually sent as a complete, non-fragmented value, so the field grew with every repeated delta instead of staying constant.

## Prevention / Rule

**Guardrail:** any streaming-delta accumulator field must document, at the point of accumulation, whether the upstream API fragments that specific field or resends it whole -- enforce via code-review checklist item for `brain/mod.rs`'s tool-call parsing ("does this field's accumulation strategy match what the API actually sends, field by field, not just copy the pattern used for a neighboring field").

This closes the gap that let a reasonable-looking but field-specific assumption (concatenation) get copy-pasted onto a field where it doesn't hold.

## Solution

### Immediate Fix

`karen-desktop/src-tauri/src/brain/mod.rs`: changed `type`/`kind` handling from `push_str` (accumulate) to assignment (overwrite):

```rust
if let Some(ref kind) = tc.kind { active_tc.kind = kind.clone(); }
```

```bash
cargo check --manifest-path karen-desktop/src-tauri/Cargo.toml   # pass
cargo test --manifest-path karen-desktop/src-tauri/Cargo.toml    # 61 passed
```

### Long-term Fix

- None planned; the fix is a direct correction of the accumulation strategy, not a workaround.

## Prevention

- [x] Code changes required (done)
- [ ] Guided live retest of a multi-turn tool-calling conversation (3+ LLM round-trips in one agentic loop) to confirm no recurrence

## Related Issues

- `KAREN-2026-10-12-pipeline-errors-never-voiced.md` -- this error reached the user as a silent HUD-only failure; fixed in the same session so future errors of this kind are at least audible even if not instantly diagnosable.

## References

- Files: `karen-desktop/src-tauri/src/brain/mod.rs`, `karen-desktop/src-tauri/src/groq_keys.rs` (confirmed correct, unrelated)

---

**Resolved By:** Claude (Claude Code)
**Time to Resolution:** ~10 min once the exact error field was read
