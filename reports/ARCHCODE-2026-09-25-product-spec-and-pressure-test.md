# ArchCode — Product Spec and Adversarial Pressure Test

**Date:** 2026-09-25
**Project:** ArchCode (new product concept, pre-implementation)
**Type:** Scope Decision / Architecture Decision
**Status:** Completed (spec authored; implementation not started)

## Summary

The ArchCode concept was reviewed, hardened into a product and technical specification,
and then deliberately attacked to find reasons not to build it. The review surfaced one
correctness bug in the original concept (a read-only `schema.sql` that would have made two
of the four scored axes unfalsifiable), one load-bearing tension with no clean resolution
(the tight feedback loop vs. statistically honest performance grading), and two existential
business risks (unit economics at hosted scale, and the product being a solvable LLM
benchmark). The spec landed on a sequenced recommendation that deliberately starts with the
cheapest test of the riskiest assumption rather than with infrastructure.

## Context / Trigger

The user presented a raw product concept for a service positioned as "LeetCode for systems
architecture" — replacing LeetCode's deterministic scalar test cases with real chaos
injection (thundering herd, network asphyxiation, `kill -9` mid-execution) and replacing the
`AssertionError` verdict with a derived architectural-collapse diagnosis plus a race-condition
timeline visualization. The request was to write the PRD and to pressure-test the concept.

No code exists yet. The working directory (`Club Zero`) contains only a vendored copy of
Apple's HIG design-review skill, which was reviewed for project conventions but contributed
nothing to the output — this is a product/architecture exercise, not a design review.

## Scope

**Included:** product thesis and positioning, user segmentation, the cockpit UI specification,
multi-file editor model, the assault-scenario library, execution/sandbox architecture, the
determinism model, diagnostics design, scoring and anti-gaming, accessibility, content cost
model, and a sequenced build recommendation.

**Excluded and why:**

- **UI implementation or design review.** No framework was chosen and none was needed. The
  HIG skill was available and deliberately not used: the deliverable was a product and
  architecture spec, not an interface audit. Accessibility is specified as a *design input*
  rather than deferred to an audit pass, which is the substantive part of that concern.
- **Hosted infrastructure design in detail.** Deferred pending the LLM-baseline test, which
  the review identified as capable of invalidating the entire assessment premise for the cost
  of an afternoon.
- **Validation study design** for the "falsifiable badge" claim. Identified as a 6–12 month
  prerequisite for all B2B value; scoped out because it is a research project, not a spec task.
- **Multi-language runners.** Scoped out explicitly (see Decisions).

## Method

1. Read the concept and asked the question the concept had not: *what must be true for this to
   work, and does the design as stated make it true?* This surfaced the four load-bearing
   requirements (R1 legibility, R2 loop length, R3 verdict stability) that the rest of the spec
   is derived from.
2. Used the repo's own conventions to place the two deliverables at the project root.
3. Wrote the spec first, then wrote the pressure test against the spec rather than against the
   original concept — so the critique targets the hardened design, which is a harder and more
   useful target.
4. Distinguished **existential** from **annoying** findings explicitly, so the sequencing
   recommendation could be weighted by consequence rather than by ease.

## Decisions & Findings

### Finding 1 — Read-only `schema.sql` would have made two scored axes unfalsifiable (correction)

The concept lists `schema.sql` as "Read-only or Editable" while scoring the learner on a radar
axis of *Performance & Query Optimization — index design, query planner mastery* and *Schema
Rigor — normalization, constraints*. If the schema is read-only the learner cannot demonstrate
either skill and the grader is scoring the author's schema, not the learner's work.

**Decision:** `schema.sql` is editable in v1. `env.yml` remains read-only, because the sandbox
constraints are the *given* of the problem — letting a learner raise `max_connections`
trivializes the pool-exhaustion scenarios.

### Finding 2 — The determinism problem is softer than it first appears, but only if split

A concurrency bug is nondeterministic, which naively destroys the LeetCode-style loop. The
resolution is a distinction the concept did not make: **the timeline must be recorded, never
predicted; the verdict must be a function of invariants, not of the timeline.**

- Tier A (invariants — zero over-sell, deadlock count, post-`kill -9` integrity) is made
  deterministic by *scenario design* rather than by machinery: 500 workers against 10 units of
  stock fails with probability ≈ 1. No statistical machinery required.
- Tier B (performance — p95, peak connections) is inherently noisy and cannot be boolean.
- Tier C (visuals) is recorded and ungraded.

**Decision:** record the timeline, never synthesize it. Synthesizing the expected interleaving
would have been easier and would have quietly destroyed the product's credibility.

### Finding 3 — Performance grading has no clean resolution (existential tension)

Real p95 on shared cloud Postgres varies 15–30% between byte-identical runs. Every option
costs something the concept promised: single measurement gives ~20% spurious failure rate on
correct solutions; median-of-5 costs ~2.5 min per Submit, which is not a tight loop; dropping
performance grading removes the EXPLAIN view, the flamegraph, and half the differentiating
thesis.

**Decision:** margin bands with an honest third state. A threshold defines PASS / INDETERMINATE
/ FAIL zones, and inside the noise floor the UI declines to grade. Grade Tier A strictly;
promote Tier B only once the reference solution's own measurement variance has been
characterised per scenario. Ship as less than the concept describes.

### Finding 4 — Unit economics break at hosted scale (existential)

Rough sizing: $0.004–$0.02 per attempt, 20 attempts per session, → **$24k–$120k/month** of
compute at 10k DAU. That requires 1,200–6,000 paying subscribers at $20/mo before any other
cost.

**Decision:** the only lever that breaks this is **running on the learner's own machine**, which
also eliminates the cheat surface as a side effect. Consequently the sequenced recommendation
puts the local docker-compose runner *first*, and defers the hosted-vs-local decision until
real usage data exists rather than projections.

### Finding 5 — The product is an LLM benchmark and will likely be solved (existential, time-limited)

Given the schema, the source, and the event log — the last being a fully machine-readable causal
trace of the bug — a current frontier model should find the lost update in one shot.

**Decision:** run this test as **step 0**, before the content pipeline and before any
infrastructure. The plausible counter-argument (that the product tests judgment, not
bug-finding) implies a repositioning to design-review-with-tradeoffs, which is *harder to
build and demos worse*. That trade should be made deliberately rather than discovered later.

### Finding 6 — The verdict UI risks teaching cargo-cult fixes (most underrated risk)

A red timeline plus "use `SELECT ... FOR UPDATE`" can produce memorised incantation instead of
understanding — precisely the shallow mimicry the product claims to destroy. This is a failure
mode that *looks like success*: engagement metrics would rise.

**Decision:** (a) a metered hint ladder whose third step requires the learner to *type the
mechanism* before the fix is revealed; (b) every reference solution ships at least two
structurally different correct approaches with their tradeoffs; (c) scenarios where the obvious
fix is wrong. Items (b) and (c) roughly double content cost, which is a budget line, not a
detail.

### Finding 7 — Content throughput, not infrastructure, is the binding constraint

8–40 senior hours per problem (schema, env, ≥2 reference solutions, 3–4 distinct teachable
failures, signature predicates, captured timeline, content review). Two people for 18 months
yields **30–50 problems**, against a LeetCode catalog built over a decade by a large team.
Content also decays as Postgres versions and planner behaviour change.

**Decision:** plan the content calendar before the content pipeline, and treat content as the
primary cost line. The concept's own framing (infrastructure, UI, scheduler) understates this.

### Finding 8 — Signal layer is inaccessible by default

The entire communication channel is red/green on a coloured timeline, unreadable for ~8% of
men. Cheap to design in (glyph + silhouette + hatch alongside hue, greyscale-legible status
column, Reduce Motion, structured screen-reader verdict since a canvas timeline announces
nothing).

**Decision:** specified as a first-design-pass constraint, not an audit item. Retrofitting it
means redesigning the core visual language.

### Finding 9 — Name and positioning

"ArchCode" promises code review; the product delivers chaos testing and judgment. The concept's
own metaphor is stronger: **a load-bearing wall passes every inspection, then fails
catastrophically without warning** — which is also the stated UX goal.

Also: the concept claims it cannot use LeetCode's layout, then keeps it. The top-left pane as a
**problem statement** is the untouched part; as an **incident report** (a 03:00 p99 alert, a
partial postmortem, a topology diagram) it would distinguish the product structurally rather
than cosmetically.

**Decision:** flagged for reconsideration before the brand hardens. No change made — the name
is the user's call.

### Finding 10 — Kill criteria

Written down while the reasoning was available: LLM solves Medium in one attempt;
second-problem return < 25%; infra cost > $0.50/DAU/mo at 1k DAU; no senior completes a Medium
unaided in < 30 min; reviewers can't read the cause off the verdict > 20% of the time; content
throughput < 2 problems/month by month 6. The last two measure the actual thesis and are both
cheaply testable before any infrastructure exists.

## Changes Made

No code. Two documents authored at the project root:

- `ARCHCODE-PRD.md` — product and technical specification: thesis, load-bearing requirements,
  users, competitive position, cockpit UI, multi-file editor model, scenario library,
  determinism model (three verdict tiers), execution architecture, scoring and anti-gaming,
  accessibility, content cost model, open questions, sequenced recommendation.
- `ARCHCODE-pressure-test.md` — adversarial review, written against the hardened spec rather
  than the original concept: the scoring/loop tension, unit economics, the real-vs-simulated
  load-bearing wall, audience ceiling, badge validation, content throughput, cargo-cult risk,
  LLM obsolescence, layout, naming, gamification exploits, accessibility, the untested
  engagement assumption, the bull case, kill criteria, and a four-step plan.

## Verification

No executable verification applies (no code). The verification performed was internal
consistency review of the spec against the source concept, which is how Findings 1 and 9 were
found: both are contradictions *within* the concept's own stated requirements rather than
objections to it.

Unit economics in Finding 4 are an order-of-magnitude estimate from public instance pricing,
not a quoted vendor figure. It is the correct order of magnitude for a go/no-go decision and
must be replaced with real numbers before any hosted commitment.

## Follow-ups / Deferred

- **Step 0 (blocking):** baseline three current frontier models against a hand-built
  thundering-herd event log. Determines assessment-vs-teaching and invalidates or confirms
  the assessment premise. One afternoon.
- **Reference-solution variance measurement** (Q5 in the spec) — required before any Tier B
  margin band can be set defensibly.
- **Virtual-clock feasibility** (Q2) — whether simulated time can coexist with diagnosing real
  blocking-connection semantics. This is the cost/realism dilemma in pressure test §3 and is
  the largest unresolved architecture question.
- **Validation study** for the badge, before any B2B positioning.
- **`migrate.sql` tab** for migration-safety exercises (v1.5).
- **Revisit the top-left pane as an incident report** rather than a problem statement.

## References

- `ARCHCODE-PRD.md` — the specification this report reviews and hardens
- `ARCHCODE-pressure-test.md` — the adversarial review produced in the same session
- Jepsen — the closest prior art in the space, and aimed at practitioners rather than learners
- k6, Toxiproxy, Chaos Monkey — real chaos tooling the concept reuses rather than rebuilds
