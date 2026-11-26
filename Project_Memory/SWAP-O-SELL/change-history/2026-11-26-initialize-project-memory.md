# Initialize Project_Memory for SWAP-O-SELL — 2026-11-26

**What changed:** Created `Project_Memory/SWAP-O-SELL/` from scratch
(MAIN.md, architecture/, decisions/, implementation/, prompts/), backfilled
entirely from existing `SOFTWARE-ENGINEER` dev-log and report history
(~14 bug/issue entries across technical-area folders, ~44 reports), plus a
brief read of the live codebase structure (`backend/`, `swappify-social-hub/`,
`admin/`, `docker-compose*.yml`, `deploy/`).

**Why:** No project memory existed for this project despite extensive
established dev-log/report history under the `SWAP-O-SELL`/`SWAPOSELL`
prefixes — the global memory-maintenance rule requires creating it the
first time any session works in a tracked project.

**Which files this populated:**
- `MAIN.md` — current state, map, known gaps.
- `architecture/system-architecture.md`, `database-architecture.md`,
  `frontend-architecture.md`.
- `decisions/api-design.md`, `database-design.md`, `authentication.md`.
- `implementation/api-integration.md`, `frontend-hooks.md`.
- `prompts/significant-tasks.md`.

**Known limitation:** This is a retroactive backfill, not incrementally
maintained — treat it as a strong starting orientation, not ground truth,
until a few more sessions have exercised and corrected it. In particular,
Google sign-in (commits `64302bd`/`aeb51ad`) has no dedicated report/bug
entry yet and was documented here only from commit messages — verify
against code before relying on it.
