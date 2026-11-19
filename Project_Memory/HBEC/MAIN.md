# [PROJECT] — Memory Index

**Last updated:** YYYY-MM-DD
**Project repo:** [path or URL]
**One-line what-it-is:** [what this project does, for someone with zero context]

Read this file first, every session, before touching the codebase. It
should be enough to understand what the project is and why it's built the
way it is without reading source. If something here is stale or wrong,
fix it in the same session you notice — don't leave it for later.

## What this project is
2-4 sentences: purpose, who uses it, the one or two things that make it
non-standard (if anything).

## Current state
What's live, what's in progress, what's explicitly paused/deprioritized.
Update this every session that changes it — this is the section most
likely to rot.

## Map
- `architecture/` — what the system looks like now (components, data flow,
  boundaries). Derivable from code in principle, kept here so an agent
  doesn't have to re-derive it every session.
- `decisions/` — **why** it's built this way, where "why" isn't visible
  from reading the code (alternatives considered, constraints, trade-offs
  accepted). Don't duplicate code-derivable facts here.
- `implementation/` — notes on specific non-obvious mechanisms (a tricky
  hook, an integration quirk) worth remembering without re-reading the
  code each time.
- `prompts/significant-tasks.md` — prompts that produced non-obvious
  architectural output worth reusing or referencing, not a log of every
  prompt.
- `change-history/` — dated entries, one per session/change that altered
  architecture or decisions. Not a diary of every commit — only entries
  that would otherwise force a re-read of git history to understand "how
  did we get here."

## Known gaps / don't trust this for
[Anything in this memory set that's known to be incomplete, or areas where
you should still verify against the actual code before acting — e.g. "auth
flow docs predate the OAuth migration, verify against code until updated."]

## Related
- Bug/issue log entries for this project: see `SOFTWARE-ENGINEER`
  technical-area folders, filename prefix `[PROJECT]-`.
- Reports: see `SOFTWARE-ENGINEER/reports/`, filename prefix `[PROJECT]-`.
