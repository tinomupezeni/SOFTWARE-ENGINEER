# ProjectFlow MCP server: chat, notifications, and workspace-management tool expansion

**Date:** 2026-10-27
**Project:** ProjectFlow (projectflow-mcp)
**Type:** Feature Expansion
**Status:** Completed

## Summary
Expanded the ProjectFlow MCP server from 7 tools (task CRUD + assignment)
to 26, adding read/write access to ProjectFlow's unified chat system
(DMs, project channels, task comments, @mentions, #references),
notifications, global/user search, milestones, time tracking, task
reminders, and project membership management — all derived from the
actual Django/DRF backend source rather than guessed from the public API.

## Context / Trigger
User asked to (1) fix a known bug in `create_task`, (2) add the ability to
pull messages from ProjectFlow chats, and (3) review the backend codebase
under `~/Projects` to scope out "all the power we can give this MCP."

## Scope
Included: chat/messaging (conversations, messages, task comments,
mentions, reference search), notifications, global search, user search,
milestones, time entries, task reminders (single + overdue-bulk), and
project member add/remove — the "Core + chat" scope the user selected
when given a choice between that, a chat-only cut, and a scope that also
included admin/ops features.

Explicitly excluded (deferred, not forgotten): workspace management/invites,
client CRUD, finance documents, the personal checklist feature, and
observability/VPS-monitoring endpoints. These exist in the backend but are
either admin-facing, niche, or lower-value for an AI agent's day-to-day use.
File attachments were also out of scope — the backend has no attachment/
upload model anywhere except admin-only help-center media, so that would be
new backend work, not an MCP wrapper.

## Method
Rather than guessing endpoint shapes from the README or MCP server alone,
read the actual backend source at `~/Projects/ProjectFlow/projectflow_backend`
(Django + DRF) to enumerate every app's `urls.py`, and for the features in
scope, read the relevant `models.py`/`serializers.py`/`views.py` to get
exact field names, permission requirements, and request/response shapes
(e.g. `Message.mentions`/`references`, `Milestone.due_date`/`status`,
`TimeEntry.hours`/`date`, the `/tasks/<id>/send-reminder/` permission
check). This avoided building tools against assumed field names that would
fail against the real API.

## Decisions & Findings
- ProjectFlow has no separate "Comment" model — task comments, project
  channels, and DMs are unified into a single `chat.Message` model, scoped
  by either a `task` FK (which auto-resolves to the task's project channel)
  or a `conversation` FK. One `list_messages`/`post_message` tool pair
  covers both task comments and channel/DM messages, rather than separate
  tools per surface.
- Messages are immutable via the API (`http_method_names = ["get", "post",
  "head", "options"]` on `MessageViewSet`) — no edit/delete tools were
  built since the backend doesn't support them.
- Extracted a shared `find_user_by_email()` helper (exact-match search via
  `/users/search/`) since five new tools (mentions, DM start, project
  member add/remove) needed the same "resolve email -> approved active
  user" logic that `assign_task` already had inline.
- Used `Optional[dict]` instead of PEP 604 `dict | None` syntax for the one
  typed return annotation added, since `pyproject.toml` declares
  `requires-python = ">=3.9"` and the `|` union operator on bare types
  isn't valid there.
- Verified the full tool set against the real `mcp` package (not just
  `ast.parse`) in a scratch venv — confirmed all 26 tools register and
  produce valid JSON schemas via `FastMCP.list_tools()`.

## Changes Made
- `src/projectflow_mcp/server.py`: fixed `create_task`'s UnboundLocalError
  (see `PROJECTFLOW-2026-10-27-create-task-unbound-user-id.md`); added
  `get_api_base_url()` and `find_user_by_email()` helpers; added 19 tools:
  `search_users`, `global_search`, `list_conversations`,
  `get_project_channel`, `start_direct_message`, `list_messages`,
  `post_message`, `search_chat_references`, `list_notifications`,
  `mark_notification_read`, `mark_all_notifications_read`,
  `list_milestones`, `create_milestone`, `log_time_entry`,
  `list_time_entries`, `send_task_reminder`, `remind_overdue_tasks`,
  `add_project_member`, `remove_project_member`.
- `README.md`: reorganized the tool list into Tasks & Projects / Chat &
  Notifications / Search sections and documented all new tools.
- Commit: `f4f30c0` on `main` in `projectflow-mcp`.

## Verification
- `python3 -m ast.parse` on the final file (syntax check).
- Installed the package into a scratch venv (`/tmp/pf_venv`) with the real
  `mcp` dependency and called `FastMCP.list_tools()` — confirmed all 26
  tools (7 original + 19 new) register with correct required/optional
  parameters and valid input/output JSON schemas.
- No live API calls were made against the production ProjectFlow instance
  as part of this change (no test credentials used in this session).

## Follow-ups / Deferred
- Workspace management (list members, invites, stats), client CRUD,
  finance documents, personal checklist, and observability/VPS tools were
  explicitly deferred per the user's chosen scope — candidates for a
  follow-up pass if needed.
- The server re-authenticates via `/auth/login/` on every single tool call
  (no token caching/reuse across calls within a session) — not changed in
  this pass since it predates this work, but worth a future look if call
  volume or backend login load becomes a concern.
- `build/lib/projectflow_mcp/server.py` was already dirty (stale build
  artifact, diverged from `src/`) before this session started and was left
  untouched — it wasn't part of this change and isn't meant to be
  hand-edited.

## References
- `PROJECTFLOW-2026-10-27-create-task-unbound-user-id.md` (the bug fixed
  alongside this expansion)
- Backend source: `~/Projects/ProjectFlow/projectflow_backend`
  (`chat/`, `projects/`, `users/` apps)
- `~/Projects/projectflow-mcp/src/projectflow_mcp/server.py`

---

**Completed By:** tinomupezeni
**Duration:** ~1 session
