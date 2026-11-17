# Reasoning Had No Subscription CLI Provider

**Date:** 2026-11-04
**Project:** KAREN
**Environment:** Development desktop
**Severity:** Medium
**Status:** Resolved

## Summary
Karen's reasoning selector supported only Groq and Ollama. The default was Groq, so a user with working Claude Code or Codex subscription logins still needed a Groq API key for cloud reasoning.

## Symptoms
- A default install without `GROQ_API_KEY` could return `GROQ_API_KEY is not set` for ordinary reasoning turns.
- The settings UI offered no Claude Code or Codex provider.

## Environment Details
- **Server/Host:** Local desktop
- **Services Affected:** Friday desktop reasoning
- **Related Components:** `brain/mod.rs`, `settings.rs`, `lib.rs`, `App.tsx`
- **Time First Observed:** 2026-11-04

## Investigation Steps

### 1. Initial Diagnosis
Read Karen's provider routing and settings validation, then compared Harvey's `claude_runtime.py` and `codex.py` adapters.

### 2. Root Cause Analysis
Karen selected Groq by default and rejected providers other than `groq` and `ollama`. Its HTTP reasoning path required an API key when Groq was selected.

### 3. Key Findings
- Harvey uses an isolated, tool-free Claude Code CLI subprocess or an isolated Codex app server with subscription login.
- Karen's tools can remain under Karen's existing dispatcher; subscription inference only needs to return a decision.
- The installed global Codex CLI is 0.166.0, while Harvey's isolation adapter verifies 0.159.3. An offline isolation test on 0.166.0 failed because the model attempted an `additional_tools` item; retaining the version gate prevented unsafe use.

## Root Cause
The provider contract and UI assumed Groq or Ollama were the only reasoning backends.

## Prevention / Rule
**Guardrail:** Keep provider validation, runtime routing, settings UI, and packaged bridge resources in one provider contract test that exercises each selectable provider through its preflight and response parser.

This catches a provider that appears in settings but cannot run or be packaged.

## Solution

### Immediate Fix
Added Claude Code and Codex subscription choices, defaulted to Claude, bundled a Python bridge with Harvey's isolated adapters, and routed model requested tools through Karen's existing permission checks.

The Claude bridge returned the requested JSON through the real installed CLI with subscription login. Rust compilation, 42 focused brain tests, and the frontend build passed. Installed Codex 0.159.3 under Karen's ignored `.codex-cli` directory without changing global 0.166.0. The Codex bridge returned the requested JSON through that local CLI and the existing ChatGPT login. Codex correctly refused the global 0.166.0 CLI before sending a prompt when the local copy was absent.

### Long-term Fix
Keep the vendored Harvey adapters synchronized with Harvey's audited CLI surface and verify new Codex versions before allowing them.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- `KAREN-2026-10-12-groq-free-tier-tpm-limit-not-key-exhaustion.md`

## References
- Harvey `harvey/claude_runtime.py` and `harvey/codex.py`
- Karen `karen-desktop/src-tauri/src/brain/subscription.rs`

---

**Resolved By:** Codex
**Time to Resolution:** In this session
