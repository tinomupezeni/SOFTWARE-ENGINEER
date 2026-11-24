# LEC Biotec — Memory Index

**Last updated:** 2026-11-24
**Project repo:** `/home/shadowe/Projects/lec-biotech-ascend` (GitHub:
`winstonjthinker/lec-biotech-ascend`)
**One-line what-it-is:** A laboratory-supply e-commerce platform for LEC
Biotec (Zimbabwe/South Africa/Zambia): a storefront + CMS-backed admin
being rebuilt from a static brochure site into a transacting platform.

Read this file first, every session, before touching the codebase. The
project's own `CLAUDE.md` (repo root) is the authoritative, detailed
architecture/process reference — read it too; this file is a thinner
orientation layer plus the "why" and "non-obvious" notes that don't belong
there.

## What this project is

npm-workspaces monorepo: `apps/storefront` (Vite+React 18 customer site),
`apps/admin` (Vite+React 18 admin at `/admin`), `apps/api` (Django 5 +
DRF), `packages/ui` (shared primitives/design tokens),
`packages/tsconfig`. Non-standard things worth knowing up front: the
storefront renders *everything* from the database via a CMS section
registry (no hardcoded marketing copy/images — enforced by a content
gate), and the admin's palette is literally what's served to visitors
(design tokens live in `@lec/ui`, shared by both apps).

## Current state

- **Production:** `chemglee-vps` (SSH alias `chemglee-vps`), containers
  `lec_api`, `lec_worker`, `lec_beat`, `lec_postgres`, `lec_redis`,
  `lec_biotech_ascend` (storefront+admin bundle, served at
  `127.0.0.1:8083`, reverse-proxied to `lecbiotec.com`). Deploy via
  `./deploy.sh` from a local checkout (Docker context `vps-tino`, remote
  `administrator@93.127.143.153`, app dir `/opt/webapps/lec-biotech`;
  requires a local `.env`).
- **In progress:** Catalogue CSV import had a reported "can't import"
  issue (2026-11-24) — root cause and fix are in
  `Backend_and_API/LEC-2026-11-24-catalogue-import-apply-race-false-400.md`.
  The underlying plan/apply TOCTOU (catalogue state can change between
  "Check the file" and "Apply") is accepted behavior, not eliminated —
  watch for recurrence reports and don't assume this class of import
  failure is a new bug without checking that log first.
- Most ProjectFlow tasks for this project are DONE; open items as of
  2026-11-24: "Evaluate VR Headset Options" (low), "Research and Quote
  Google Ads Campaign" (high) — neither is codebase work.

## Map

- `architecture/` — not yet filled in beyond this file; the project's own
  `CLAUDE.md` is the current source of truth for architecture rules
  (frontend, backend, admin, catalogue, inventory, checkout, payments,
  theming, media, cart, order lifecycle — all documented there in detail).
  Fill `architecture/*.md` here only when a note would otherwise force
  re-reading `CLAUDE.md` + code every session; don't duplicate it wholesale.
- `decisions/` — see below; kept empty except where a real decision was
  made in a session (not code-derivable).
- `implementation/` — not yet filled in.
- `prompts/significant-tasks.md` — not yet filled in.
- `change-history/` — not yet filled in; add an entry only when it would
  otherwise take a git-log dig to reconstruct "how did we get here."

## Known gaps / don't trust this for

This memory folder was just created (2026-11-24) and is close to empty.
For anything architectural, trust the repo's own `CLAUDE.md` over this
file until these folders are filled in from real sessions. Don't assume
absence of a note here means absence of a constraint — check `CLAUDE.md`.

## Related

- Bug/issue log entries for this project: `SOFTWARE-ENGINEER` technical-
  area folders, filename prefix `LEC-`.
- Reports: `SOFTWARE-ENGINEER/reports/`, filename prefix `LEC-`.
