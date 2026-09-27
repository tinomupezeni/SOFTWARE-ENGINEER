# ArchCode Run Latency Budget: Measured, Not Assumed

**Date:** 2026-09-27
**Project:** ArchCode
**Type:** Architecture Decision / Audit
**Status:** Completed

## Summary
The user set a hard product requirement: a submitted run must feel near-instant, not take
"like 30 minutes." That requirement collides with PRD §7.3, which budgets ~2.5 minutes for a
full Submit across 5 repetitions, and with pressure-test §3, which warns that the product's
most valuable teaching moment (a transaction holding a lock across a slow external call) is
the one it can least afford to simulate. Rather than argue from estimates, I built a
benchmark and measured every cost in the §10 critical path against real Postgres 16 and real
Toxiproxy. The measurements confirm the near-instant requirement is achievable — 2.5 s end to
end — but they overturn two assumptions in the PRD and surface one outright defect.

## Context / Trigger
The user asked for the runner architecture to be decided and stated four things: the admin
view must oversee *everything* (content authoring and ops), runs must respond near-instantly,
this is a simulation of real-world systems, and it should also cover AI-engineering scenarios
where a user supplies their own model API key. They asked explicitly whether the answer was a
distributed system or a monolith.

I had already recommended a Python runner, Django + FastAPI, WebSockets, and a CLI-first
approach, but every latency claim behind that recommendation was an estimate. Since the
entire architecture turns on latency, and since a wrong answer here either wastes a month of
building or ships a product that fails its own core loop, I measured it.

## Scope
**In scope:** per-attempt database cost, the 500-buyer contention workload, Toxiproxy fault
injection overhead, the Postgres connection ceiling, and the resulting critical path.

**Out of scope, deliberately:**
- *Learner-visible run latency.* This measures the harness's own floor (a correct solution
  competing for seats). The user-facing figure adds container start, the learner's own code,
  grading, and websocket fan-out. It cannot be measured until the sandbox exists, and the
  point of this exercise is to fix the budget the sandbox must fit inside.
- *Tier B performance grading.* PRD §7.3 already decides not to grade timing, so the flakiness
  tax never touches a score and does not belong in a verdict budget.
- *AI/LLM scenario latency.* Real model calls take seconds and are non-deterministic, so they
  cannot be on the graded fast path at all. They need the deterministic replay path first.
- *A deliberately broken solution.* The workload here is a correct atomic
  `UPDATE ... WHERE taken = false`, so `over_allocation = 0` is the expected passing case. This
  benchmark proves the fast path works; it does not yet prove a *failing* solution is detected
  quickly. That is the natural next measurement.

## Method
A single self-contained harness, `runner/bench/latency.py`, brings up its own Postgres 16,
Toxiproxy, and Python 3.13 worker on a private Docker network, measures each cost in
isolation, tears everything down, and writes a timestamped JSON result file. Real components
throughout — no mocks, because a mocked number here is worse than no number: it would get
quoted as a budget.

Two deliberate methodological choices, both of which changed conclusions:

1. **Every database cost is measured with one round trip, against a measured floor.** A bare
   `docker exec psql 'SELECT 1'` costs ~130–142 ms of pure harness overhead. An early version
   of the reset benchmark issued two `psql` calls for `TRUNCATE` and made the *cheaper* option
   look more expensive than the clone. The floor is now measured and subtracted.
2. **The harness refuses to measure if its own environment is ambiguous.** See the stale-alias
   bug below; this guardrail exists because a benchmark that silently mixes two database
   servers is worse than no benchmark.

Buyer interleaving is a fixed seeded permutation, never a shuffle, per PRD §7.4. Latency
profiles are fixed values with `jitter=0`, also per §7.4. The invariant checked is Tier A and
serious: exactly `SEATS` winners and `over_allocation = 0`, i.e. 500 buyers racing for 100
seats must never over-allocate, under any connection topology.

Two independent samples were run to check stability; every figure below reproduced within
noise except the per-attempt container, which is discussed separately.

## Decisions & Findings

### 1. The near-instant requirement is met: 2.5 s, not 30 minutes

Warm-pool + connection pooling + `TRUNCATE`-and-reseed, end to end: **~2.5 s**. This validates
the requirement rather than merely accommodating it. The user's fear of a 30-minute run is
about 700x off the real figure.

### 2. A fresh container per attempt costs ~92 s — the warm pool is not an optimization, it is the whole design

| Path | DB reset | Workload | **Total** |
|---|---|---|---|
| Fresh container + `initdb` | 92,169 ms | 10,332 ms | **~101.3 s** |
| Template clone (`CREATE DATABASE ... TEMPLATE`) | 60 ms | 10,163 ms | **~10.2 s** |
| Warm pool + `TRUNCATE` + reseed | 5 ms | 2,478 ms | **~2.5 s** |

PRD §10 already specified a "warm pool," but left it as a detail. Measured, it is a **40x**
difference between viable and non-viable — the difference between a 2.5-second tight loop and
a 101-second one that no learner will sit through. Any implementation that reaches for
per-attempt isolation on convenience grounds must be rejected on these numbers.

Caveat: 92 s is this machine (shared, container-backed storage). The absolute figure is
host-specific; the **40x ratio** is the portable result and is what should drive the decision.

### 3. Defect: 500 buyers cannot be 500 connections — Postgres defaults to 100

The first run failed outright:

```
psycopg.OperationalError: connection failed: connection to server at "172.24.0.2", port 5432 failed:
FATAL: sorry, too many clients already
```

Postgres defaults to `max_connections = 100`. PRD §7.3's "500 concurrent buyers" cannot mean
500 connections without explicitly raising that limit, which the PRD never mentions. Worse,
**opening** 500 connections costs ~7.0 s of the ~10.3 s workload — roughly 70% of the run is
connection setup, not the seat-claiming work the exercise is about.

So "500 buyers" must mean 500 *logical* workers multiplexed over a bounded connection pool
(50 connections → 0.8 s to open, comfortably inside the default of 100). This is not a
performance tweak: it changes what the scenario is simulating, and it belongs in the PRD
because a learner reading "500 concurrent buyers" will reason about connections.

### 4. Finding: Toxiproxy costs ~2.2–2.6 s, not the 5 ms it advertises

With a fixed +5 ms profile and `jitter=0`, routing the 50-connection workload through
Toxiproxy took **4.7–5.4 s** versus 2.5–2.8 s direct: **+2.2–2.6 s**, roughly 90% overhead.
Connection setup alone went from ~0.7 s to ~2.1 s.

The arithmetic explains it: 5 ms per direction per connection, multiplied across 50 connections
and several round trips each, is thousands of milliseconds of aggregate queueing. The nominal
per-packet figure is real; the naive reading of it is not.

Design consequence: **the fault injector must not sit in the request path for the whole run.**
It should be attached only to the specific calls a scenario is teaching (the external HTTP
call that holds the lock), not to the database path that carries the workload. This directly
resolves pressure-test §3's dilemma in favour of the product's thesis: keep real network
semantics for the mechanism being taught, and keep the fast path clean everywhere else.

### 5. Confirmed: monolith, and latency does not argue otherwise

The user asked whether this should be distributed. It should not, and the measurements
strengthen the case. Nothing in this critical path is a service-to-service hop; every
millisecond is Postgres, the container runtime, or the proxy. A distributed control plane
would *add* latency to the path being measured and solve a scaling problem the design does not
have. It would also mean debugging two layers of the same class of bug at once in a product
whose entire subject is that class of bug — making it ambiguous whether a failed run was the
learner's fault or the orchestrator's.

The one thing that must be *pooled* is connections, not split into services: one Postgres
behind a bounded pool, queue via `SELECT ... FOR UPDATE SKIP LOCKED`, no Redis, no Kafka.

### 6. Confirmed: split the admin, because Django admin cannot do half of it

- **Django admin → content authoring.** Problems, scenarios, invariants. Excellent fit; §14
  makes content the product.
- **Ops dashboard → the existing React app.** "Oversee everything" means a live run queue,
  worker health, and streaming telemetry. Django admin cannot do live updates, and the React
  app already has the websocket channel, the colour-role table, and the accessibility
  constraints. The ops page belongs there and reuses all three.

This is a scope decision, not a framework preference: it removes any temptation to build
polling into Django admin to fake liveness.

### 7. AI scenarios cannot be on the graded fast path

Real model calls take seconds and are non-deterministic, so latency- or correctness-graded AI
scenarios are impossible. Two paths, matching PRD §7.4:
- **Default: deterministic replay** — recorded responses keyed by a hash of the request
  payload. Instant, reproducible, gradeable. PRD §10's "stub gateway" is already the right
  mechanism; it just hasn't been built, and it now serves both fault injection and AI responses.
- **Opt-in: user's own key + endpoint.** Seconds, feedback only, never graded. The key must
  never touch the database or the logs: browser → sandbox as an ephemeral value, discarded at
  run end. Self-hosted models (Ollama/vLLM) are the cleanest path since they need no egress and
  keep the sandbox's isolation intact.

I also pushed back on sequencing: do not expand into AI scenarios before Tier A works end to
end. A flash-sale problem with a sub-5-second verdict is the product thesis; the AI track is a
second content genre inheriting every determinism problem the first has, plus key management.

## Changes Made
- **New:** `Club Zero/runner/bench/latency.py` — the benchmark harness (~430 lines, brings up
  and tears down its own containers, writes timestamped JSON).
- **New:** `Club Zero/runner/bench/results-*.json` — raw measurements from both samples.
- **No production code changed.** This is a measurement and decision pass; nothing in
  `pixel-perfect-replication` was touched.
- **Docs:** this report, plus five bug-log entries (see References).

Harness bugs found and fixed while building it, all of which had produced wrong or misleading
numbers first: the `pg_isready` string comparison, the missing network aliases, `-c` being
docker's `--cpu-shares` rather than a Postgres flag, the wrong Toxiproxy CLI verb (`create`, not
`add`), the unbalanced two-round-trip reset, and the `TRUNCATE`-after-seed ordering that
silently emptied the seat table and made every buyer legitimately fail.

## Verification
- Invariant `winners == SEATS (100)` and `over_allocation == 0` held in **all three**
  configurations (500 connections, 50 connections, 50 connections via Toxiproxy), both samples.
  This is the Tier A check that matters: 500 buyers racing for 100 seats never over-allocated.
- Two independent full runs; every figure reproduced within noise.
- A deliberate pre-flight now asserts the `postgres` alias resolves to exactly one endpoint
  before any measurement is taken, after the stale-container bug described in the References.
- The measured floor (`SELECT 1` round trip, ~130–142 ms) is subtracted from database costs so
  the comparison reflects server work, not harness overhead.

## Follow-ups / Deferred
1. **Measure the failing case.** The workload is a correct solution, so this proves the fast
   path, not the detection path. Next: a deliberately broken solution (read-then-write instead of
   atomic `UPDATE`) to confirm the invariant violation is surfaced *fast*. This is the number
   that actually matters for the product, and it is the one thing still missing.
2. **Fold the numbers into PRD §7.3**, replacing the ~2.5-minute Submit budget, and correct
   §7.3's connection assumption and §10's unquantified warm pool.
3. **Pin container images by digest.** `shopify/toxiproxy:latest` currently ships CLI 2.1.4;
   the verb surface and behaviour could change under a tag, which would make fault profiles
   irreproducible across time.
4. **Decide the fault-injection topology** — proxy only the taught call, versus proxy the whole
   run at a ~2.3 s cost. Finding 4 argues strongly for the former but it needs a design note.
5. **Container warm-up cost** was measured cold. A genuinely pre-warmed pool would be faster
   than 2.5 s; the budget above is therefore conservative.
6. **Native command registration** (Tauri/Electron vs. web) and **formal shortcut sign-off**
   remain open, unrelated to this pass.

## References
**Bug-log entries filed alongside this report:**
- `Architecture_and_Design/ARCHCODE-2026-09-27-prd-500-buyers-exceeds-postgres-max-connections.md`
- `Architecture_and_Design/ARCHCODE-2026-09-27-toxiproxy-request-path-costs-2s-not-5ms.md`
- `Architecture_and_Design/ARCHCODE-2026-09-27-per-attempt-container-costs-92s.md`
- `DevOps_and_Infrastructure/ARCHCODE-2026-09-27-bench-stale-container-alias-mixed-servers.md`
- `DevOps_and_Infrastructure/ARCHCODE-2026-09-27-toxiproxy-latest-tag-cli-drift.md`

**Related reports:**
- `reports/ARCHCODE-2026-09-27-runner-architecture-decision.md` — the runtime/transport
  decision this report quantifies and amends.
- `reports/ARCHCODE-2026-09-26-step5-product-surface.md` — frontend, now complete and committed.

**Key source documents:**
- `ARCHCODE-PRD.md` §§7.3, 7.4, 10, 14, 16 — the budgets and constraints measured against.
- `ARCHCODE-pressure-test.md` §3 — the realism-vs-latency dilemma Finding 4 resolves.

**Key files:**
- `Club Zero/runner/bench/latency.py` — the harness.
- `Club Zero/runner/bench/results-*.json` — raw measurements.

---

**Completed By:** Claude (Claude Code)
**Duration:** ~2h (benchmark build, debugging, two measured samples, write-up)
