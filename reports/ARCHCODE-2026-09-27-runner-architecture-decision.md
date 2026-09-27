# Runner architecture decision: local docker-compose, Python orchestrator, event log as the only boundary

**Date:** 2026-09-27
**Project:** ArchCode
**Type:** Architecture Decision
**Status:** Proposed — awaiting confirmation of the runtime fork

## Summary
The runner decision is pre-answered in outline by PRD §10 (orchestrator → sandbox → verifier,
with only the event log and final DB state crossing the boundary) and PRD §16 ("local runner
first: `docker-compose` + a CLI"). What is genuinely undecided is the *runtime* and the
*first slice*. The recommendation is: **a local `docker-compose` runner written in Python, with
a separate verifier process, a committed JSONL event-log schema as the only interface, and a
CLI before any UI.** The decisive constraint is one the PRD does not state: the frontend is a
TanStack Start app deploying to Cloudflare Workers, and Workers cannot start a Postgres
container. The deployed web app therefore *structurally cannot execute anything* in v1, and
any design that pretends otherwise is designing a hosted runner by accident.

## Context / Trigger
The frontend reached the end of the design review's five steps, with `CAPABILITIES.execution`
deliberately `false` and Run/Submit inert. Work is moving to the runner, which PRD §15 Q6
leaves open: "Local runner: is it v1.5 or the wedge?" That question is about sequencing and
cost structure, not architecture — the architecture is already drawn in §10.

## Scope
Decided here: runtime for orchestrator and verifier, the sandbox boundary, the shape of the
first deliverable, and the determinism prerequisites. Not decided here: the hosted-runner
path, the cost model (PRD §10.1 defers the binding number to the pressure test), the scoring
function beyond the Tier A/B/C split, and the badge.

## Method
Read PRD §7 (determinism), §10 (execution architecture), §15 (open questions) and §16
(sequencing), then checked the artefacts the previous session actually committed — the
OpenAPI document and the Drizzle schema — to find out how much of the contract already
commits to a shape. The gap between "what the PRD draws" and "what the contract contains"
turned out to be the most useful input to the decision.

## Decisions & Findings

### Finding 1: the committed contract is read-only, and a runner needs the opposite

`openapi/archcode.yaml` declares three paths, all `get`: `/problems/{slug}`,
`/problems/{slug}/scenarios`, `/problems/{slug}/reference-runs/{scenarioSlug}`. The Drizzle
schema has `problems`, `problem_files`, `scenarios`, `reference_runs` — and no table for a
learner's attempt.

So the contract can *serve recorded reference runs* and cannot *accept a submission*. That is
correct for the frontend as built, and it is the wrong shape for a runner. The first backend
change is not an endpoint to add; it is recognising that attempts are first-class data with
their own lifecycle (`queued → running → verdicted`), which the current schema has nowhere to
put. Deciding the runner without deciding attempt storage would mean revisiting the schema
immediately.

### Finding 2: Workers cannot be the orchestrator, so "local" is forced rather than chosen

§10 draws a browser talking to an orchestrator over a websocket that spawns sandboxes from a
warm pool. The frontend deploys to Cloudflare Workers via Nitro. Workers has no container
runtime, no `initdb`, no ability to hold a warm Postgres pool, and no cheap way to run 500
concurrent buyers against a real database. A sandbox pool of that shape requires a process
that can run Docker.

This is the single most decision-relevant fact in the whole analysis and it is not in the PRD.
It means the §10 diagram is accurate for the *eventual hosted* product and impossible for the
*current deployment*, and that v1 has to run somewhere else — the developer's machine, or a
container host. PRD §16 already prefers the former, on cost grounds; this makes it necessary
on capability grounds.

### Decision 1: Python for the orchestrator and the verifier

PRD §7.4 already specifies the run topology in Python terms: "Single-node run; one process,
N asyncio workers, not N containers." The sandbox is `solution.py`. The verifier's job is
invariant signatures over Postgres state and an event log, which is unremarkable in Python.

The alternative — keeping the backend in TypeScript for one language and one deploy — was
rejected because there is no single deploy to unify: the orchestrator cannot live in the
Workers app, so "one language" would mean running Node beside Python *inside* the sandbox
boundary, adding a runtime to the hot path for no benefit. The real cost of Python is a
second runtime in the repository, and that cost is already paid at the boundary the PRD
mandates.

The two runtimes communicate only through committed data contracts — the OpenAPI document and
a JSONL event-log schema — so the language split does not leak across the boundary.

### Decision 2: the verifier stays a separate process, and that is a security property

§10 is explicit that verifier isolation "is a security property, not a packaging choice",
because the verifier holds the invariant definitions and the reference answers. Concretely:
separate container, no shared filesystem, no shared network, and only the event log plus a
final DB snapshot cross. The tempting shortcut — running the verifier as a library inside the
sandbox, where it can read anything — must be ruled out now, while it is cheap to rule out.

### Decision 3: CLI before UI, and the event log is the contract

The first deliverable is a CLI that runs one scenario end to end and writes the JSONL event
log, plus a verifier that consumes it and prints verdicts. Only after that log format has
survived a real run does any UI consume it.

The reasoning is that the UI is downstream of the log. Building a UI against a log format that
then has to change to accommodate real telemetry is how the frontend gets rewritten. A CLI
also makes the runner testable in the way this project has already committed to: assertions
over observable output rather than over a rendered screen.

### Finding 3: determinism is a prerequisite, not a hardening pass

§7.4 lists five nondeterminism sources, and §7.2/§7.3 make Tier A the only graded tier. But
the *timeline* is Tier C — recorded, ungraded, and still the product's centrepiece. So the
barrier and the seeded release order are needed for the visualization to be readable even
though nothing is being graded yet. They belong in the first slice, not after it.

"No random numbers anywhere in the run path" is the rule to enforce mechanically. That is a
good candidate for a guardrail in the same spirit as the frontend's: assert the run path
contains no `random`/`Math.random`/`time.time()`-seeded nondeterminism outside the recorded
seed.

### Finding 4: grading only Tier A keeps the first slice small

§7.3's margin-band recommendation means v1 grades invariant outcomes and reports performance
as unranked feedback. That is a genuine reduction in product appeal and the PRD is right to
take it. For the runner it has a useful side effect: the verifier's first version needs no
statistical machinery at all, so it is a pure function from the event log plus final DB state
to a set of invariant verdicts. The flakiness work becomes additive later rather than
requantifying a grading function that already shipped.

## Changes Made
None to code. This entry records a decision. The two artefacts it constrains —
`openapi/archcode.yaml` and `drizzle/schema.ts` — were committed in the frontend repository
under `93a1332` and are deliberately read-only at present; the attempt/run shape they are
missing is called out as Finding 1 for the schema change that follows this decision.

## Verification
No code was written, so there is nothing to run. What was verified:
- The committed OpenAPI document has three paths and no mutating method (checked directly).
- The committed Drizzle schema has four tables and none for an attempt (checked directly).
- The frontend's deployment target is Cloudflare Workers via Nitro, confirmed by the build
  output emitting `.output/server/wrangler.json` — this is the basis for Finding 2 and it is a
  build artefact, not an assumption.

## Follow-ups / Deferred
- **Confirm the Python runtime fork.** This is the one decision here that is a preference, not
  a constraint, and it is the author's to make.
- Add `runs`/`attempts` (or a run lifecycle on `reference_runs`) to the schema, plus a
  submission path to the OpenAPI document. The contract is currently viewer-only.
- Write the JSONL event-log schema down before the first run, and commit it — it is the
  boundary both runtimes agree on.
- Decide how the browser attaches to a local orchestrator (websocket to `localhost`, or
  recorded-run import). This is unresolved and is constrained by Workers having no inbound
  sockets to a developer's machine.
- Build the determinism harness (seeded barrier, fixed Toxiproxy latency profile) before
  grading anything.
- Revisit the hosted runner only after the local one proves the "feel" and the diagnostic
  layer, per §16.

## References
- `ARCHCODE-PRD.md` §7 (determinism), §10 (execution architecture), §10.1 (cost), §15 Q6,
  §16 (sequenced recommendation)
- `ARCHCODE-pressure-test.md` §3 (the cost number that binds the business)
- `pixel-perfect-replication/openapi/archcode.yaml`, `pixel-perfect-replication/drizzle/schema.ts`
- `pixel-perfect-replication/src/lib/runner.ts` (`CAPABILITIES.execution = false`)
- Related: `Frontend_and_UI/ARCHCODE-2026-09-26-primary-actions-live-but-inert.md`

---

**Completed By:** Claude (Anthropic), on behalf of the user
**Duration:** ~1 hour
