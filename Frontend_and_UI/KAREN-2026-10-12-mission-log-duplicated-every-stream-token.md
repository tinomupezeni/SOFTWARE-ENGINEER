# Mission log flooded with near-duplicate entries on every streamed answer

**Date:** 2026-10-12
**Project:** Karen (Friday voice assistant)
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary

The HUD's mission log showed the same answer logged 5-6+ times in a row, each copy progressively shorter/longer than the last. Root cause: the backend emits the `"answer"` pipeline stage on every streamed token chunk as the LLM response grows (not once at the end), and the frontend's event listener pushed a brand-new mission-log entry for every single pipeline event regardless of stage, with no deduplication. User initially suspected this meant the LLM was being called multiple times per turn; confirmed via the latency log (`LLM 1892ms`, a single measurement) that it was one real call -- purely a UI artifact.

## Symptoms

- Mission log showed the same growing response text as 6 separate entries, each one slightly different in length (the streaming snapshot at that moment), cluttering the panel and making it look like repeated/duplicate work.
- User asked whether this meant duplicate API calls were being made for the same query.

## Investigation Steps

### 1. Initial Diagnosis

Checked the per-turn latency breakdown in the same HUD screenshot (`STT 705ms Â· LLM 1892ms Â· total 2611ms`) -- a single LLM timing measurement, which is inconsistent with the request having actually been sent multiple times.

### 2. Root Cause Analysis

`brain/mod.rs`'s streaming loop emits `"answer"` on every incoming token chunk:

```rust
accumulated_content.push_str(text);
if current_gen_id == crate::tts::get_current_generation() {
    let _ = app.emit("karen-pipeline", json!({ "stage": "answer", "detail": accumulated_content }));
}
```

`App.tsx`'s listener pushed an unconditional new mission-log entry for every event it received, with no check on `payload.stage`:

```ts
const unlistenPipeline = listen<PipelineEvent>('karen-pipeline', ({ payload }) => {
  setMissionLog((items) => [`...`, ...items].slice(0, 6))
  switch (payload.stage) { ... }
});
```

Since `"answer"` fires many times per turn (once per streamed chunk) while every other stage fires once, the log filled up almost entirely with near-duplicate answer snapshots, pushing out everything else.

### 3. Key Findings

- This was never a backend bug and never caused extra Groq requests or token spend -- purely a frontend logging/display issue.
- The Live Dialogue panel's `lastResponse` state already displays the live-updating full answer correctly; the mission log doesn't need its own copy of that same growing text at all.

## Root Cause

The mission-log push had no stage filter, so a stage designed to fire repeatedly during streaming was treated the same as one-off stage transitions.

## Prevention / Rule

**Guardrail:** any new pipeline stage that can fire more than once per turn must be explicitly excluded from (or deduplicated in) one-off UI logs like the mission log -- enforce via code-review checklist item for `App.tsx`'s `karen-pipeline` listener ("does this stage fire once per turn or many times, and does the mission log push account for that").

## Solution

### Immediate Fix

`karen-desktop/src/App.tsx`: excluded the `"answer"` stage from the mission-log push entirely (every other stage is still logged); the Live Dialogue panel remains the single source of truth for the live-updating answer text.

```bash
npx tsc --noEmit -p tsconfig.app.json   # pass
```

### Long-term Fix

- None planned; excluding streaming-only stages from the mission log is the correct long-term behavior, not a stopgap.

## Prevention

- [x] Code changes required (done)
- [ ] None further

## Related Issues

- None directly; reported alongside `KAREN-2026-10-12-tts-reads-markdown-literally.md` and the MCP tool-schema token-cost fix from the same conversation.

## References

- Files: `karen-desktop/src/App.tsx`

---

**Resolved By:** Claude (Claude Code)
**Time to Resolution:** ~10 min
