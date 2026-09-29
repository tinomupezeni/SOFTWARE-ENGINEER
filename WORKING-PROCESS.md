# Working process — how a task should be handled, start to end

**Written:** 2026-09-23, alongside `HANDOFF-subscription-label-fix.md`, for
a successor agent taking over this session. This is a general reference,
not specific to one task — keep it around (unlike the handoff file, which
gets deleted once that specific task is done).

This describes the actual discipline used throughout this session, which
covered a lot of ground (bug fixes, a multi-project dead-code audit,
infrastructure work, product-flow changes) without breaking anything or
touching production. The steps below are *why* that held up.

## 0. Before anything — read the standing rules

Two files govern every session in this project, and both **override
default behavior**:
- `/home/shadowe/.claude/CLAUDE.md` — global rules across all projects.
  Currently: log every bug/misconfiguration found or fixed as a dev-log
  entry in `SOFTWARE-ENGINEER`, automatically, without being asked; log
  every completed engineering initiative/decision as a **report** in the
  same repo's `reports/` folder, same automatic expectation.
- `/home/shadowe/Projects/HBEC/CLAUDE.md` — project-specific architecture,
  service map, known gotchas, and rules (e.g. never call an LLM outside
  `shared/llm_client.py`, never seed the student DB directly, the exact
  branch-to-deploy mapping). Read the parts relevant to whatever you're
  about to touch before touching it — it documents real incidents, not
  hypothetical ones.

Both are meant to be followed exactly, not improvised around.

## 1. Understand what's actually being asked

Distinguish the shape of the request before doing anything:
- **A direct instruction** ("fix X", "build Y") — go do it, following the
  steps below.
- **An exploratory question** ("is X handled well?", "what do you think
  about Y?") — this gets a short, direct answer with a recommendation, not
  an unprompted implementation. Don't start writing code because a question
  sounded like it might need a fix eventually.
- **An audit/investigation request** — this gets research first, findings
  presented, then a scoping decision *with* the user before any change
  lands (see step 3).
- **A blocked/ambiguous request** — if there's a genuine fork in the road
  only the user can resolve (which of several valid approaches, whether to
  touch a specific piece of live data, production vs. staging), ask via a
  structured question. If the answer is a reasonable default, don't ask —
  proceed and let the user redirect if it's wrong. Asking too much is its
  own failure mode.

## 2. Research before touching code

**Never assume — verify.** This session's biggest source of near-misses
was trusting a single signal (e.g. "no frontend caller" meaning "dead
code") without checking the others. The actual discipline:

- **Read the real code, not a memory of it.** If a claim can be checked by
  reading a file, read the file. Don't reason from what a function
  "probably" does.
- **For anything that spans more than a couple of files, delegate to a
  research fork** rather than filling your own context with raw grep/read
  output you won't need again. A fork inherits full conversation context
  and runs in the background — use it for "trace this flow end to end" or
  "find every X in this codebase" style work. Write the fork's prompt as a
  directive with exact scope (what's in, what's out, what you've already
  ruled out), not a vague question.
- **For anything that touches multiple independent angles at once**
  (e.g. an audit covering endpoint-wiring + backend dead code + frontend
  dead code), launch multiple forks **in parallel in one message**, not
  sequentially.
- **A single grep result is a lead, not a conclusion.** Before believing
  "no callers exist," check: is this the *exact* same file/export being
  investigated, or a same-named-but-different thing in another file? (This
  session caught exactly that trap — a `fetchDueTopics` in one file was
  reported dead based on 9 callers that actually belonged to an unrelated
  same-named function elsewhere.)
- **Before concluding something is dead/unused/safe to remove**, check
  *all* of: does the direct frontend call it, does another service call it
  over HTTP or an event stream, does anything else in the database have a
  foreign key into it, is it the *only* creation site for data something
  downstream reads. Any one of those being true means it's not dead, no
  matter how unused it looks from one angle. This exact check overturned
  most of an initial "these are all dead" list twice in this session.
- **A subagent/fork's report is not automatically correct.** Spot-check its
  claims, especially anything with a specific number or "N callers"
  attached — trace the exact import path yourself before acting on it.
- **When something looks broken, check whether it's pre-existing.** Before
  reporting a test failure as caused by your change, `git stash` (with
  `-u` for untracked files) and run the same test against the unmodified
  code. If it still fails, it's not yours — say so and move on, don't
  "fix" something unrelated. `git stash pop` to restore afterward.

## 3. Present findings, get alignment before acting

For anything beyond a small, unambiguous fix:
- Summarize what was found concisely — the actual findings, not a
  transcript of the investigation.
- If there's a real choice to make (scope, which of several valid
  approaches, whether to touch production data), ask a structured question
  with a recommended default rather than picking silently or interrogating
  with many small questions.
- Once the user picks a direction, proceed without re-asking for
  confirmation on every sub-step that direction implies — re-litigating an
  already-made decision wastes their time.
- For genuinely destructive/hard-to-reverse actions (deleting code with DB
  tables behind it, touching a live production database, force-pushing),
  confirm even after a general go-ahead, and explain exactly what will
  happen before doing it.

## 4. Implementation

- **Match existing conventions exactly.** Before writing new code, read a
  comparable existing example in the same codebase (a similar view, a
  similar hook, a similar test file) and mirror its shape — naming, error
  handling, comment style, test fixture pattern. Don't introduce a new
  pattern when one already exists.
- **Minimal, scoped changes.** Fix what was asked, not everything adjacent
  that could theoretically also be improved. If you notice something else
  while in there, mention it — don't silently expand scope.
- **No comments unless explaining a non-obvious *why*.** Well-named code
  doesn't need a comment restating what it does. A comment earns its place
  when it captures a constraint, a past incident, or a reason a reader
  would otherwise have to rediscover.
- **Check the reverse direction too.** If auditing "does the frontend call
  every backend endpoint," also check "does the frontend call anything
  that *doesn't exist* on the backend" — the second direction found a real
  bug this session that the first direction alone would have missed.
- **When a fix touches a shared helper**, check every other call site of
  that helper before assuming your change is isolated (e.g. renaming a
  function, changing a fallback value) — grep for all references, not just
  the ones you already know about.

## 5. Testing — before claiming anything works

- **Write real tests for new or changed behavior**, in the same file/style
  as existing tests for that area. Cover the actual edge cases that matter
  (empty/missing data, a value that doesn't match any known case, the
  degrade-on-failure path) — not just the happy path.
- **Use throwaway containers for anything stateful.** Never point tests at
  a real shared database. Spin up Postgres/Redis in Docker with a
  disposable name, point the app at it via env vars, run tests, then
  `docker rm -f` it when done. Get the env var names and the correct
  settings module right for the specific service (e.g. this project's
  Django services need `POSTGRES_HOST=127.0.0.1` never `localhost`, and
  `config.settings.test` not `config.settings.local` for a Postgres-backed
  run) — check the project's own docs for this instead of guessing.
- **Run the specific new/changed test file first**, then the **full test
  suite for that service** — a change can break something unrelated far
  away from where you were looking.
- **Know the baseline.** Before a task, if a full suite already has known
  pre-existing failures (this session tracked exact ones per service), any
  run afterward should match that exact baseline. A new failure beyond it
  is real; the known ones are not yours to fix unless asked.
- **Lint and typecheck** whatever the language/toolchain provides (`ruff
  check`, `tsc -b --noEmit`, etc.) on the files you touched, not just the
  new ones.
- **A test suite passing is not the same as the feature working.** For
  anything with a UI, a live smoke test (see step 7) is what actually
  confirms it — tests verify the code does what the test says, not that
  the test says the right thing.

## 6. Committing

- **Only commit when asked.** Don't assume a finished piece of work should
  be committed automatically.
- Run `git status` and review the actual diff before staging — never
  `git add -A` blindly. Check for anything that looks like it might carry
  a secret even in an innocuous-looking file.
- **Small, scoped commits**, generally split along natural boundaries this
  session used consistently: backend vs. frontend, or one commit per
  distinct fix/finding rather than one giant combined commit.
- **Commit messages explain why, not just what** — what was actually
  found/verified, what the fix does and doesn't cover, what was
  deliberately left alone and why. A future reader (human or agent) should
  be able to understand the reasoning without re-deriving it.
- End every commit with the attribution line this session's system
  reminder specified:
  `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`
- Create new commits rather than amending, unless explicitly told to amend.
- Never use `--no-verify` or otherwise skip hooks.

## 7. Deployment

- **Staging first, always.** This project's staging deploy is currently
  manual (`docker compose build` + `up -d` over SSH) because CI/CD
  auto-deploy has a known billing-related outage — don't assume a push
  alone deploys anything.
- **Never touch production without asking first, every time.** A prior
  approval does not carry forward to the next change — each production
  action gets its own explicit confirmation. This held for the entire
  session even when staging changes were approved in bulk.
- After rebuilding, **wait for the health check to actually report
  healthy** before considering the deploy done — don't assume a successful
  `docker compose up` means the service is serving traffic correctly.

## 8. Verify live, not just in theory

- **Hit the real deployed endpoint** after a deploy — via a shell into the
  container running a real request (e.g. Django's `manage.py shell` +
  `APIClient`, or the service's equivalent), not just "the tests passed so
  it should work."
- Confirm both directions: the fixed/new behavior actually behaves as
  intended, *and* nothing else broke (e.g. a removed route now correctly
  404s, a route that should still work still returns 200).
- If real data exists to check against (e.g. querying a live metrics
  system, an actual admin config value), prefer pulling the real number
  over describing what should theoretically happen.

## 9. Document it

- **Every bug/misconfiguration found or fixed** gets a dev-log entry in
  `/home/shadowe/Projects/SOFTWARE-ENGINEER`, filed under the matching
  technical-area folder, named `[PROJECT]-YYYY-MM-DD-brief-description.md`,
  following `templates/issue-template.md` exactly. One entry per distinct
  issue, written as it's found — not batched from memory at the end of a
  session.
- **Every completed engineering initiative or decision** (an audit, a
  refactor, an architecture choice — even one that found no bug) gets a
  **report** in the same repo's `reports/` folder, following
  `templates/report-template.md`, same naming convention.
- Read the target repo's own README/templates before writing the first
  entry of a session and follow its conventions exactly rather than
  improvising a structure.
- **Commit and push documentation immediately**, same as code — not
  batched for later.

## Threads through all of it

- **Never fabricate or guess a displayed value.** If real data can't be
  resolved, show an honest "unavailable" state. This shows up constantly
  in this codebase's own comments (`// An honest gap beats a fabricated
  number`) — it's a hard rule, not a style preference.
- **Measure twice, cut once**, especially for anything hard to reverse —
  deletions, schema changes, production actions. The verification steps in
  section 2 exist specifically because this session found real damage
  would have resulted from skipping them, twice.
- **Match scope to what was actually asked.** Noticing the same bug exists
  in a second codebase (e.g. a mobile app mirroring a web app's flow) is
  worth mentioning — it is not, by itself, permission to go fix it there
  too without being asked.
- **State results directly.** Brief, factual updates at key moments (found
  something, changed direction, hit a blocker) — not a running commentary
  on internal reasoning, and not silence either.
