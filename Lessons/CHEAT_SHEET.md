# Engineering Principles Cheat Sheet

> Plain-language versions of the recurring lessons pulled from this repo's
> dev-logs (May–Sept 2026). Memorize these six. Full technical detail,
> stack-specific rules, and checklists live in
> `PRINCIPAL ENGINEER/engineering-guides/` — this file is the fast version.

**The one-line summary:** it doesn't count until you've actually watched it
happen — not the config file, not the doc, not the green checkmark, the real
thing.

---

## 1. Never trust a tool until you've watched it fail once

If `ruff`, `mypy`, a lint rule, or a migration-downgrade script exists in a
config file but nobody has ever actually run it, assume it doesn't work. Run
it on day one, let it break, fix what it finds. "We have strict typing" only
becomes true once you've seen it bite — not when you added it to
`pyproject.toml`.

*From: MARITCHO's `ruff`/`mypy`/`pytest`/alembic-downgrade — all declared,
none ever run, all broken the first time they actually were.*

## 2. Found one, fix all its cousins right now — not later

When you catch a bug like "login never records `last_login`," don't just
patch that one file. Stop and grep the whole codebase for every other place
doing the same kind of thing — admin, student, mobile, whatever — and fix
them all in the same sitting. Wait, and you'll "discover" the same bug again
next week in a different file and it'll feel like a new incident.

*From: HBEC's admin `last_login` fix, then the identical student-side bug
found separately, a day later.*

## 3. Click the actual button before you call it done

A feature isn't finished because the model exists, the API test passes, and
the button renders. Those can all be true and the button still does
nothing, because nobody ever wired them together. Before marking anything
done, click through it as a real user would, start to finish, and watch it
actually work.

*From: HBEC's chat feature that returned a hardcoded fake reply, a template
picker reading an empty table, an upload dialog with no button that opened it.*

## 4. If one system's ID lives inside another system's table, that link is your job — not the database's

A normal foreign key stops you from deleting something still in use
elsewhere. Across two separate services (an admin database and a student
database, say), there's no such protection — nothing stops one side from
deleting a row the other side still points to. Whenever you copy an ID
across a service boundary, ask "what happens when the original gets
deleted?" If you don't have an answer, that's a bug waiting to happen.

*From: HBEC's exam papers — deleted on one side, orphaned and still showing
on the other, twice, on two different models a day apart.*

## 5. A cleanup script passing on staging doesn't mean production's mess looks the same

Build-once-deploy-everywhere protects your *code* by testing the exact
image before promoting it. The same discipline applies to *data*: if you
run a "merge the duplicates" script before a migration, run it against
production too, separately — don't assume staging's clean data means
production is clean. Production accumulates its own mess independently.

*From: HBEC — a duplicate-subject cleanup script run only on staging;
production had its own 26 duplicates and crash-looped on promotion.*

## 6. Assume your docs are already wrong today

A README, an architecture diagram, a "how deployment works" note — none of
it updates itself when the code changes under deadline pressure. Before you
make a decision based on what a doc says, open the actual code or config
it's describing and check they still match. Trust the code, verify the doc
— never the other way round.

*From: HBEC's `CLAUDE.md` branch-deploy rule going stale, and MARITCHO's
`schema.sql` never matching its own Alembic migrations.*

---

## Bonus: the two you already had down

**Build once, deploy everywhere.** Build the Docker image once, test that
exact image on staging, then promote that *same* image to production —
don't rebuild for prod. Whatever passed staging is byte-for-byte what
production runs, so "worked on staging, broke on prod" can't be a build
difference.

**Design the database before you design the code.** A bloated, badly
normalized schema is where most 500 errors are actually born — a missing
constraint, a wrong nullability, a field that should've been its own table.
Think data shape first; the code mistakes are cheaper to fix than the schema
mistakes.

---

*Full guide library: `PRINCIPAL ENGINEER/engineering-guides/MANIFEST.md`.
Raw incident evidence: the technical-area folders at the repo root
(`Backend_and_API/`, `DevOps_and_Infrastructure/`, etc.).*
