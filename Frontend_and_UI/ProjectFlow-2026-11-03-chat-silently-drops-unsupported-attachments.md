# Chat composer silently sends empty messages when an attachment is the only content

**Date:** 2026-11-03
**Project:** ProjectFlow
**Environment:** Production
**Severity:** Medium
**Status:** Investigating

## Summary
A user (Mutsa) referenced having "sent screenshots" in the HBCA project channel, then four messages in a row arrived with completely empty bodies and no references. Investigation found that ProjectFlow has no attachment/file-upload capability anywhere in the stack — not in the `chat.Message` model, not in any API endpoint, and not in the frontend chat UI. There is no composer component in `projectflow-hq` at all for attaching files. The most likely explanation is that the user attempted to paste or attach an image with no accompanying text, and whatever client they used submitted an empty `body` rather than blocking the send or warning that attachments aren't supported — so the content was lost with zero signal to either party.

## Symptoms
- Four chat messages in the HBCA project channel (IDs `6228f5af`, `9903ccdf`, `5d9ce0bc`, `bfa0108f`, all 2026-10-30) have empty `body` and empty `references`.
- The sender's prior message in the same thread ("I have sent you screenshots") implies an attachment was intended.
- The recipient (via the ProjectFlow MCP tool) had no way to tell these messages apart from a true no-op send — they looked identical to an accidental blank submit.

## Environment Details
- **Server/Host:** `projectflow.thuthuka.tech` (API), `projectflow-hq` (frontend)
- **Services Affected:** Chat/messaging (`chat` Django app), `projectflow-hq` frontend, `projectflow-mcp` MCP client
- **Related Components:** `projectflow_backend/chat/models.py`, `chat/serializers.py`, `chat/urls.py`, `projectflow-hq/src` (no chat composer found)
- **Time First Observed:** 2026-10-30 (messages sent); investigated 2026-11-03

## Investigation Steps

### 1. Initial Diagnosis
User asked to retrieve "screenshots" referenced by four blank chat messages via the ProjectFlow MCP tool. The MCP tool's `list_messages` only ever read `body`, `sender_name`, `mentions_detail`, `created_at` from the API — no attachment field existed in its output, so it was unclear whether attachments existed server-side but were simply unsurfaced by the client.

### 2. Root Cause Analysis
Read the backend source directly to settle the question at the data-model level rather than guessing from the MCP tool's (possibly incomplete) output.

```bash
grep -n "attach\|file\|image\|media" src/projectflow_mcp/server.py   # zero matches in the MCP client
cat projectflow_backend/chat/models.py                               # Message has only body, task, mentions, references
cat projectflow_backend/chat/urls.py                                 # only /conversations/ and /messages/, no attachment endpoint
find projectflow-hq/src -iname "*chat*" -o -iname "*conversation*"   # no chat UI component exists in the frontend at all
```

### 3. Key Findings
- `chat.Message` (backend) has exactly four content-bearing fields: `body`, `task`, `mentions`, `references`. No file/image/attachment field was ever added across any of the four chat migrations.
- `body` is only allowed to be blank when the message carries a `references` entry (quoting another message/task/project) — the four messages in question have neither, so they are not quote-replies either.
- There is no attachment upload endpoint anywhere in `chat/urls.py` or `chat/views.py`.
- The `projectflow-hq` frontend has no chat/composer component under its own name at all (`find -iname "*chat*" -o -iname "*conversation*"` returns nothing), so messaging likely happens through another client (e.g. mobile) not present in this checkout — but whichever client was used, the resulting API payload it produced had an empty body and no way to carry the claimed screenshot.
- Separately (not this bug, but found along the way and already fixed): `projectflow-mcp`'s `list_messages` also didn't surface the `references_detail` field that the backend serializer does provide, making quoted-reply messages look like disconnected fragments. That gap was fixed in this session (see `reports/PROJECTFLOW-2026-11-03-mcp-references-support.md`).

## Root Cause
ProjectFlow has no attachment/file-upload capability in its data model or API. Whatever client the sender used to "send a screenshot" had no server-side field to carry that data, so the request that reached the backend necessarily had an empty `body`, and nothing in the system flagged this as a partial/failed send to either the sender or the recipient.

## Prevention / Rule
**Guardrail:** Add a server-side validator on `Message.save()`/the `MessageSerializer` that rejects a message when `body` is blank and `references` is also empty — the model docstring already states blank is only valid for a quoting message, but nothing enforces it today. A message with no text and no reference should fail the request outright (400) rather than persist as a true no-op, which closes the door on exactly this kind of silent data loss while attachment support doesn't exist yet.

This directly prevents a client-side attachment attempt (or any other blank-body bug) from silently succeeding as an empty message with no signal to sender or recipient.

## Solution

### Immediate Fix
None applied — this session only investigated and surfaced the gap. The four empty messages remain in place; the user was told there is nothing recoverable in them and to re-ask the sender what the screenshots were about (likely sent out-of-band, e.g. email/WhatsApp, given no in-app attachment path exists).

### Long-term Fix
Two options, not yet decided/built:
1. Add real attachment support (file field + upload endpoint + frontend composer UI) if screenshots are a recurring need in chat.
2. At minimum, add the blank-body-without-reference validation described above so a failed/unsupported send surfaces as an error instead of a silent empty message.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [ ] Code changes required

## Related Issues
- `ProjectFlow-2026-10-15-frontend-api-loopback-regression.md`
- `reports/PROJECTFLOW-2026-11-03-mcp-references-support.md`

## References
- `projectflow_backend/chat/models.py`
- `projectflow_backend/chat/serializers.py`
- `projectflow_backend/chat/urls.py`
- `src/projectflow_mcp/server.py`

---

**Resolved By:** N/A — open finding, not yet fixed
**Time to Resolution:** N/A
