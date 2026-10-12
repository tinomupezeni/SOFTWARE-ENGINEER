# Friday: natural-language background research with voice completion and UI status

**Date:** 2026-10-12
**Project:** Karen (Friday voice assistant)
**Type:** Architecture Decision / Feature
**Status:** Completed

## Summary

User wanted to be able to say something like "research clean architecture in SDLC" and have Friday dispatch it as a background job -- similar to how Claude Code subagents run work and report back when done -- so the live conversation isn't blocked, then discuss the findings afterward. Built this on top of existing-but-unwired scaffolding (`memory/tasks.rs`, `brain/tools/tasks.rs`, and an explicit-phrasing-only `background_request`/`start_background_task` pair in `brain/mod.rs`) rather than from scratch: broadened the trigger phrasing, routed background work to a local Ollama VM to avoid contending with the live conversation's Groq quota, added a spoken completion announcement, confirmed conversation-history integration already worked for free, and added a live status list to the HUD.

## Context / Trigger

Direct user request, immediately following confirmation that Friday's voice pipeline was now responsive enough to hold a real conversation. The ask had four parts: (1) a research tool Friday can dispatch to the background, (2) route heavy work through Ollama rather than Groq, (3) a voice "ping" on completion so the user doesn't have to poll, (4) a HUD panel showing background tool status (queued/running/done).

## Scope

**Included:** natural trigger-phrase detection, an Ollama-by-default provider override for background work, a short in-character spoken announcement on completion, and a HUD panel listing background tasks with live status.

**Explicitly excluded:** building a new research/browsing tool -- the agent loop already had Playwright MCP browser tools merged into its tool list (`mcp::tool_defs()`), so background tasks reuse the existing agentic loop rather than needing a bespoke mechanism. Also excluded: a dedicated "discuss findings" UI flow -- conversation-history integration (see Method) already makes the findings available to ordinary follow-up questions without new code.

## Method

1. Read the existing scaffolding before writing anything new: `memory/tasks.rs` (DB-backed task records), `brain/tools/tasks.rs` (create/get/list tool handlers), and `background_request`/`start_background_task` in `brain/mod.rs`. Found the trigger was rigid literal phrasing only (`"run this in the background: "`), the worker thread already existed and emitted a `karen-task` Tauri event on completion, but nothing on the frontend listened for it, and nothing spoke the result.
2. Verified, rather than assumed, that MCP/Playwright tools were already part of the tool list sent to the model (`brain/tools.rs:358`, `definitions.extend(crate::mcp::tool_defs())`), confirming background "research" could do real browsing, not just recall.
3. Checked whether conversation-history persistence needed new plumbing: it didn't -- `start_background_task` already calls the same `run_agentic`/`run_agentic_inner` path that appends user/assistant turns to the active conversation (`db.append_message`), so a background task's question and answer land in the same history ordinary turns read from. No separate memory mechanism was built.

## Decisions & Findings

- Broadened trigger phrasing (`research `, `look into `, `look up `, `find out about `, `investigate `, etc.) rather than requiring the explicit "run this in the background" wording, since the user's actual ask was conversational, not mechanism-aware.
- Background work defaults to Ollama (`KAREN_BACKGROUND_LLM_PROVIDER`, default `"ollama"`) via a new `forced_provider` parameter threaded through `run_agentic`/`run_agentic_inner`, rather than mutating the process-wide `KAREN_LLM_PROVIDER` env var -- that global is shared with the live conversation (a known limitation per `ARCHITECTURE.md`), so mutating it for a background job would have raced with whatever the live turn was doing.
- The completion announcement is deliberately short ("I've got what I found on X whenever you want to hear it"), not the full research dump -- read aloud immediately, a long research answer would talk over whatever the user is doing when it happens to finish.
- The announcement uses the TTS generation ID *current at completion time*, not the one captured when the task was kicked off -- by the time a research job finishes, the live conversation has likely moved through several unrelated turns, so using the stale generation would either silently drop the announcement or interrupt the wrong turn.
- The HUD's background-task list intentionally shows only description + status badge, not the full result inline -- keeps the panel compact; the result is available conversationally once Friday announces it's ready.

## Changes Made

- `karen-desktop/src-tauri/src/brain/mod.rs`: broadened `background_request` trigger matching; added `background_llm_provider()`, `research_ready_announcement()`; added `forced_provider` parameter to `run_agentic`/`run_agentic_inner`; `start_background_task` now emits `karen-task` on queue and running transitions (previously only on completion), speaks the completion announcement, and runs under the Ollama provider override.
- `karen-desktop/src/App.tsx`: added `BackgroundTask`/`TaskEvent` types, a `backgroundTasks` state list, a `karen-task` event listener, and a "BACKGROUND TOOLS" panel under Live Dialogue showing each task's description and a queued/running/done/failed badge with a pulse animation while running.
- Added tests for the new trigger phrases and the announcement text for both outcomes.

## Verification

```bash
cargo check --manifest-path karen-desktop/src-tauri/Cargo.toml   # pass
cargo test --manifest-path karen-desktop/src-tauri/Cargo.toml    # 64 passed at time of this feature
npx tsc --noEmit -p tsconfig.app.json                            # pass
```

Live end-to-end retest (saying "research X", watching the HUD panel transition through queued/running/done, hearing the announcement) not yet done at time of writing -- listed as a follow-up.

## Follow-ups / Deferred

- Live retest of the full research flow, including a multi-step browsing research question, to confirm Ollama's qwen2.5:3b can reliably drive the Playwright tool-calling loop (smaller local models are generally less reliable at multi-step tool use than the 120B Groq model used for live conversation).
- No UI affordance yet to view a completed background task's full result text directly (currently surfaces only through the spoken announcement + asking Friday conversationally) -- deferred since the conversational path already satisfies the original request.

## References

- `KAREN-2026-10-12-mcp-tool-schemas-sent-on-every-turn-burned-tpm-budget.md` -- a related fix in the same area: background tasks are one of the two cases (the other being explicit browsing mentions) that keep MCP tool definitions included after that token-cost fix.
- Files: `karen-desktop/src-tauri/src/brain/mod.rs`, `karen-desktop/src-tauri/src/memory/tasks.rs`, `karen-desktop/src-tauri/src/brain/tools/tasks.rs`, `karen-desktop/src/App.tsx`

---

**Completed By:** Claude (Claude Code)
**Duration:** ~50 min
