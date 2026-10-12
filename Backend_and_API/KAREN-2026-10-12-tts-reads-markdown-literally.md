# Friday spoke markdown symbols literally ("star star") instead of stripping them

**Date:** 2026-10-12
**Project:** Karen (Friday voice assistant)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary

Friday's responses are meant to be spoken, but the LLM sometimes formats answers with markdown (`**bold**`, `- bullet` lines, `#` headings), and nothing in the pipeline stripped that before handing text to TTS -- so Friday would literally voice the formatting characters (reported by the user as "it reads `**` as 'star star'"), undermining the natural, in-character voice the project is aiming for. Fixed with a two-part defense: the system prompt now explicitly tells the model not to use markdown (since replies are always spoken, never displayed as rendered text), and a `strip_markdown_for_speech` pass runs on every string immediately before it reaches `tts::speak_chunk`, so an occasional slip from the model still can't reach the user's ears as raw symbols.

## Symptoms

- Spoken responses included audibly wrong content like "star star" where the model had written `**word**`, and bulleted lists ran together without pauses since bullet markers and list newlines weren't treated specially.
- No prior instruction in the system prompt addressed output formatting at all, beyond "keep answers concise."

## Investigation Steps

### 1. Initial Diagnosis

User described the exact failure mode (asterisks read as "star star") while discussing wanting a more natural, JARVIS/Karen-(Spider-Man)-style voice. Checked the system prompt built in `run_agentic_inner` and found no mention of markdown/formatting constraints at all.

### 2. Root Cause Analysis

Traced every path that calls `tts::speak_chunk` in `brain/mod.rs`: the per-sentence streaming chunk, the trailing remainder after streaming ends, and `speak_now` (used by the fast-path/router/background-task announcements). None of them transformed the text in any way before handing it to TTS -- whatever the LLM wrote was spoken character-for-character.

### 3. Key Findings

- Prompting alone ("don't use markdown") is a request, not a guarantee -- models still occasionally emit it, so a prompt-only fix would regress intermittently.
- A simple character-drop (removing `*`, `_`, `#`, `` ` `` outright) is sufficient for TTS purposes: none of those symbols has a sensible spoken reading, so there's no information lost by dropping them rather than trying to translate them into speech.
- Bullet-point newlines needed separate handling from the emphasis-marker strip -- naively dropping a leading `- ` without inserting a pause would run list items together as one run-on sentence.

## Root Cause

No stage between LLM output and TTS ever sanitized markdown formatting; the system prompt also never told the model this was a voice-only interface where markdown has no meaning.

## Prevention / Rule

**Guardrail:** any text reaching `tts::speak_chunk` must pass through `strip_markdown_for_speech` first -- enforce via code-review checklist item for `brain/mod.rs` ("does this new speak_chunk call site sanitize its input, or is it reading a hand-written constant that provably never contains markdown").

This is defense-in-depth deliberately: the system-prompt instruction reduces how often the model tries to use markdown at all, and the stripping function guarantees that even if it does, the user never hears it.

## Solution

### Immediate Fix

`karen-desktop/src-tauri/src/brain/mod.rs`:

- Added an explicit instruction to the system prompt: every reply is spoken aloud, never read as text, so never use markdown/bullets/numbered lists/headers; say lists as a spoken sentence instead.
- Added `strip_markdown_for_speech(&str) -> String`: converts bullet-marker newlines (`- `, `* `, `• `) into spoken pauses (". ") instead of running list items together, then drops `*`, `_`, `#`, and `` ` `` characters outright (none have a sensible spoken reading), then collapses whitespace.
- Applied it at all three `speak_chunk` call sites that carry model-generated text: the per-sentence streaming chunk, the trailing remainder, and `speak_now`. The HUD/conversation-history copy of the text is left unstripped (markdown is harmless there, and may render fine in a future text view).
- Added tests covering emphasis/heading/code-marker stripping, bullet-to-pause conversion, and that ordinary hyphenated words (e.g. "zero-trust") are left untouched.

```bash
cargo check --manifest-path karen-desktop/src-tauri/Cargo.toml   # pass
cargo test --manifest-path karen-desktop/src-tauri/Cargo.toml    # 69 passed
```

### Long-term Fix

- None planned; the two-part fix (prompt instruction + defensive stripping) is the complete, durable solution for this failure mode.

## Prevention

- [x] Code changes required (done)
- [ ] Guided live retest with a response that previously included markdown (e.g. a list-heavy research answer) to confirm it now reads cleanly

## Related Issues

- Reported in the same conversation as `KAREN-2026-10-12-mission-log-duplicated-every-stream-token.md` and the MCP tool-schema token-cost fix (Groq rate-limit follow-up).

## References

- Files: `karen-desktop/src-tauri/src/brain/mod.rs`

---

**Resolved By:** Claude (Claude Code)
**Time to Resolution:** ~20 min
