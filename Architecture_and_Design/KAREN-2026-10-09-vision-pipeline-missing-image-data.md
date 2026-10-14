# Vision Pipeline Fails to Transmit Image Data to LLM

**Date:** 2026-10-09
**Project:** KAREN
**Environment:** Development
**Severity:** High
**Status:** Resolved (Identified)

## Summary
The desktop screenshot context pipeline captures an image via the desktop portal but only passes the local file path string to the LLM. The underlying Groq API integration only supports text messages, so the LLM never actually sees the image pixels, rendering the vision feature completely non-functional.

## Symptoms
- The agent may confidently guess or hallucinate the contents of the screen based on the file path name or surrounding context.
- The agent cannot actually describe specific UI elements, errors, or visual details from the screen.

## Environment Details
- **Server/Host:** Local desktop
- **Services Affected:** `karen-desktop` (Rust/Tauri backend)
- **Related Components:** `src-tauri/src/desktop_context.rs`, `src-tauri/src/brain/mod.rs`
- **Time First Observed:** 2026-10-09

## Investigation Steps

### 1. Initial Diagnosis
Audited the `capture_desktop_context` tool in `desktop_context.rs`. Noticed it successfully captures a screenshot and saves it to a local path, returning a JSON structure containing `image_path`.

### 2. Root Cause Analysis
Checked how tool outputs are provided to the LLM in `brain/mod.rs` and `pipeline.rs`.
The `Message` struct used for communicating with Groq is defined as:
```rust
struct Message {
    role: String,
    content: Option<String>,
    tool_calls: Option<Vec<ToolCall>>,
    tool_call_id: Option<String>,
    name: Option<String>,
}
```
This struct only accepts text `content`. The tool result JSON containing the file path is converted to a string and passed in. The Groq chat completions endpoint requires multimodal specific structures (e.g., base64 encoded image URLs within the message content array) to process images, which are not implemented here.

### 3. Key Findings
- The screenshot portal correctly captures and saves the image.
- The `Message` struct and Groq API request format are strictly text-only.
- The LLM receives the path string (e.g. `{"image_path": "/run/user/1000/doc/..."}`) and hallucinated visual capabilities based on the system prompt context.

## Root Cause
The chat completion payload struct (`Message`) is strictly text-based and does not implement multimodal vision capabilities. Consequently, the image bytes are never read from disk nor transmitted to the LLM.

## Prevention / Rule
**Guardrail:** Architecture Review Checklist
When implementing multimodal features (vision/audio), integration tests must verify that the actual binary payload (or base64 encoding) is present in the outbound API request payload, not just a local URI.

This guardrail ensures that we do not mistakenly rely on LLM hallucinations when passing local file URIs to cloud APIs that cannot resolve them.

## Solution

### Immediate Fix
Identified during Phase 3 architecture audit. The `capture_desktop_context` tool currently does not provide visual data.

### Long-term Fix
- Update the `Message` struct and serialization logic to support array-based content containing `image_url` components with base64 encoded data.
- Ensure the model selected on Groq supports vision (e.g., Llama-3.2-Vision).
- For Phase 3, this issue is logged and should be addressed when vision capabilities are formally required, rather than blocking the memory system.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- Related to Phase 3 Persistent Context and Memory architecture audit.

---

**Resolved By:** Antigravity CLI
**Time to Resolution:** 30m
