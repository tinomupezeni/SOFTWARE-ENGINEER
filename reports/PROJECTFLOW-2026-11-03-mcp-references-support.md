# projectflow-mcp: surface message `references_detail` in `list_messages`

**Date:** 2026-11-03
**Project:** ProjectFlow (projectflow-mcp client)
**Type:** Cleanup / Small feature
**Status:** Completed

## Summary
`projectflow-mcp`'s `list_messages` tool only ever rendered a message's `body`, `sender_name`, and `mentions_detail`, silently dropping the `references_detail` field the backend serializer already provides. This made quote-reply messages (where `body` can legitimately be blank per the model's own contract) unreadable — they looked like disconnected, content-less fragments. Added rendering of `references_detail`, rebuilt, and reinstalled the pipx package.

## Context / Trigger
User asked to pull the content behind four blank chat messages, assuming they were screenshot attachments. Before concluding anything about attachments, needed to rule out the simpler explanation: that these were quote-reply messages whose reference the tool just wasn't showing.

## Scope
- In scope: `list_messages` output formatting in `src/projectflow_mcp/server.py`.
- Explicitly excluded: the pre-existing stale diff in `build/lib/projectflow_mcp/server.py` (an out-of-date build artifact unrelated to this session, left untouched) and any backend changes — the backend already returns `references_detail` via DRF's default serializer context, so no backend change was needed.

## Method
Read the actual backend source (`projectflow_backend/chat/models.py`, `serializers.py`, `views.py`) to confirm the real shape of the data before changing the client, rather than guessing at field names. Confirmed `MessageViewSet` is a plain DRF `ModelViewSet` so `get_serializer_context` already includes `request`, meaning `references_detail` populates correctly on list without any backend work.

## Decisions & Findings
- The four blank messages in question turned out to have empty `references_detail` too (confirmed after the fix) — so they are not quote-replies either, ruling out that explanation. See `Frontend_and_UI/ProjectFlow-2026-11-03-chat-silently-drops-unsupported-attachments.md` for what they actually are (a likely silent attachment-attempt failure, since ProjectFlow has no attachment support anywhere in the stack).
- Confirmed, while in the backend source, that no attachment/file field exists on `chat.Message` and no attachment endpoint exists — this ruled out the original "screenshot" hypothesis entirely and redirected the investigation.

## Changes Made
- `src/projectflow_mcp/server.py`: `list_messages` now renders a `(references: ...)` suffix per message, showing the referenced item's label and link, or "restricted"/"Deleted item" labels as returned by the backend's `resolve_references_for`.
- Reinstalled via `pipx install --force .` from the repo root so the live MCP tool picks up the change; user restarted the MCP connection to load it.
- No backend changes were required or made.

## Verification
Called `list_messages` against the live HBCA project channel after reinstall + restart; confirmed reference strings now render correctly for known quote-reply messages (e.g. "addressed -> /messages?conversation=...&message=...") and confirmed the four blank messages show no references, settling the investigation above.

## Follow-ups / Deferred
- The pre-existing stale `build/lib/projectflow_mcp/server.py` diff (unrelated, older version of the file) was left as-is — not part of this change, not cleaned up.
- Whether to add real attachment support to ProjectFlow is deferred to the user; tracked as an open option in the linked bug-log entry.

## References
- `Frontend_and_UI/ProjectFlow-2026-11-03-chat-silently-drops-unsupported-attachments.md`
- `src/projectflow_mcp/server.py`
- `projectflow_backend/chat/serializers.py`

---

**Completed By:** Claude (session with Tinotenda Mupezeni)
**Duration:** Single session
