# Runner API: first green test suite, and the threading model it exposed

**Date:** 2026-09-27
**Project:** ArchCode
**Type:** Refactor / Design Decision
**Status:** Completed

## Summary
Took the ArchCode runner's FastAPI surface from "code written, nothing verified" to a green
suite of 18 tests, and in doing so established the project's test-isolation model and a durable
submission snapshot. The valuable part is not the test count: it is that debugging surfaced four
real defects, three of them in code that had looked correct on review, and that the diagnosis
method — asking each thread directly what it could see rather than inferring from symptoms —
converted three days' worth of plausible-but-wrong hypotheses into one answer in a single run.

## Context / Trigger
The runner scaffold (Django schema + content admin, FastAPI run API and WebSocket telemetry) had
been written and its migrations applied, but `pytest` had never been run to completion. The first
full run produced 11 failures across 14 tests, several of them apparently contradictory: a
`404` where a fixture had just created the row, an `AttributeError` on a setting that was plainly
defined, and a teardown error about an unknown extra database session. Four independent bugs were
interleaved behind those symptoms.

## Scope
Included: the API test suite, the async ORM bridge's test-isolation model, WebSocket replay
semantics, submission durability, settings export, and lint/test tooling configuration.

Excluded, deliberately:
- **The executor, queue, and warm pool.** No execution exists; `CAPABILITIES.execution` stays
  `false` and `/healthz` reports `execution_enabled: false`. The runner is not a runner yet, and
  pretending otherwise in either the API or the UI is the failure mode
  `Frontend_and_UI/ARCHCODE-2026-09-26-fabricated-verdicts-and-editable-overclaim.md` already
  documents.
- **The verifier.** `VerifierResult` exists as a boundary; nothing computes a verdict.
- **Django/FastAPI Compose services and README.** Scaffolding only; no runnable stack yet.
- **Repository placement for `runner/`**, which is still not a git repo and was left that way
  pending a decision.

## Method
Symptom-first debugging was abandoned early and replaced with direct interrogation. When a 404
disagreed with an obviously-present fixture row, the two threads were asked to identify themselves
rather than the code being re-read:

```python
cur.execute("SELECT current_database()")   # in the fixture's thread
# and again inside sync_to_async(thread_sensitive=True)
```

The output — *same database name, different row counts* — eliminated misconfiguration in one step
and located the fault in transaction visibility. Every subsequent fix was then verified by
**reintroducing the bug and confirming the new test fails**, which is how the WebSocket replay
regression test was proven load-bearing rather than decorative.

Regression tests were also checked for the opposite failure: passing vacuously. The first version
of the replay test *hung* under the bug instead of failing, because a queued run is non-terminal
and the stream polls forever. That produced a global `pytest-timeout`, protecting all future
stream tests rather than just this one.

## Decisions & Findings

**1. `transactional_db` is mandatory, not a preference.** pytest-django's `db` fixture isolates by
writing in a transaction and rolling back. The ORM is reached through
`sync_to_async(thread_sensitive=True)`, which uses a *second* connection — and a second connection
cannot see uncommitted rows. Any test touching the database must use `transactional_db`
(commit + truncate), which is slower but is the only isolation model compatible with the
production threading design. Enforced structurally: the shared `scenario` fixture depends on
`transactional_db`, so no test can casually select the wrong one.

**2. Connection cleanup must be dispatched to the thread that opened the connection.** Django's
`ConnectionHandler` is context-local, so `connections.close_all()` in the test thread is a silent
no-op for the executor's connection. That is what produced the "1 other session" teardown failure.
The closer is an **async** autouse fixture that awaits `close_all` on the same
`thread_sensitive=True` executor — a sync fixture cannot await it, which surfaced as a
`RuntimeWarning` about a never-awaited coroutine on the first attempt.

**3. Runs must be reproducible from their own rows.** Submission originally validated file paths
and discarded the contents while returning 202 "accepted and durable". Rather than adding a
foreign key to the editable `ProblemFile`, submissions are now **copied** into a `RunFile` table
with a `sha256`. A pointer would mean a re-verified or disputed run saw today's `solution.py`
instead of the bytes that were graded. `test_submission_survives_the_problem_being_edited_afterwards`
exists specifically to make that decision enforceable.

**4. "Unknown" is a distinct value wherever a measurement is exposed.** `Run.exceeds_budget`
returned `False` for in-flight runs, which reads to any client as "within budget" — a fabricated
result on a headline field (latency is the product's central claim: ~2.5s warm vs ~92s fresh). It
now returns `bool | None`, matching the `bool | None` the schema already declared.

**5. Replay cursors come from the client, never from a "highest seen" value.** `stream_run` derived
its cursor from the snapshot's `last_seq` and then queried for events *after* it — an empty set by
construction. It passed its own test because `0 or -1` is `-1`, so a one-event run replayed by
accident; the bug only appears at seq ≥ 1, i.e. once a run is actually running. `after_seq`, which
the module's docstring already documented, is now real.

**6. Lint config must know it is a Django project.** `RUF012` (mutable class default) flags
Django's `Meta` options, where mutable literals are required by Django itself — 31 false
positives. Migrations are machine-generated and rewritten on every `makemigrations`; linting them
means fighting the generator. Both are excluded, with reasons recorded in `pyproject.toml` so the
exclusion reads as a decision rather than a suppression.

## Changes Made
Files under `/home/shadowe/Projects/Club Zero/runner/` (not yet a git repository):

- `archcode/settings.py` — export `ATTEMPT_BUDGET_MS`; document the uppercase requirement
- `attempts/models.py` — correct `verdict_only_when_graded` polarity; tri-state `exceeds_budget`;
  new `RunFile` model
- `attempts/migrations/0001_initial.py`, `0002_runfile.py` — regenerated, then added
- `api/routes/runs.py` — persist submissions in the run's transaction with hashes; record files
  in the queued event; `HTTP_422_UNPROCESSABLE_CONTENT`
- `api/routes/ws.py` — `after_seq` resume, correct replay cursor, `Annotated`/`Query` params
- `core/db.py` — PEP 695 generics
- `tests/conftest.py` — new: async autouse closer; `scenario` fixture on `transactional_db`
- `tests/test_api.py` — 14 → 18 tests; fixtures removed in favour of `conftest`
- `pyproject.toml` — `pytest-django` + `pytest-timeout` declared, `timeout = 20`, ruff excludes

Four bug-log entries filed alongside this report (see References) rather than folded into it.

## Verification
```
ruff check .                                  -> All checks passed!
ruff format --check .                         -> 23 files already formatted
python manage.py check                        -> System check identified no issues
python manage.py makemigrations --check       -> No changes detected
python -m pytest -q                           -> 18 passed
```

Migrations applied cleanly to a live Postgres 16 and constraints verified. The two WebSocket
regression tests were re-run with the bug deliberately reintroduced and **failed** (`2 failed, 3
passed`), then restored — so they are known to catch the defect, not merely to pass.

Known remaining warning: `StarletteDeprecationWarning: Using httpx with starlette.testclient is
deprecated; install httpx2 instead` — upstream Starlette 1.7 behaviour, not actionable here.

## Follow-ups / Deferred
- **Executor, warm pool, JSONL event boundary, isolated verifier.** The core of the product. Not
  started; nothing about it should be simulated in the API meanwhile.
- **Django and FastAPI Compose services + README**, so the stack is runnable rather than
  testable.
- **A deliberately broken solution in the benchmark.** Current numbers prove the passing fast
  path only; a failing case must be measured too, or "2.5s" is a best case presented as typical.
- **`Scenario.clean()` hardcodes 100 max connections while Compose sets 600.** Unresolved
  tension between the measured 500-connection requirement and the authoring-time guardrail.
- **Toxiproxy digest pinning** and `fault_targets` enforcement, from
  `DevOps_and_Infrastructure/ARCHCODE-2026-09-27-toxiproxy-latest-tag-cli-drift.md`.
- **PRD §§7.3 and 10** still need the measured numbers folded in.
- **Positive-branch coverage** for the remaining `CheckConstraint`s
  (`tier_b_never_graded`, `sandbox_file_not_editable`) has the same asymmetric-coverage gap that
  hid the inverted constraint.
- **Size cap on submission content** — `RunFile.content` is currently unbounded `TextField`.
- **Repository placement for `runner/`** — still undecided; not a git repo.

## References
Bug-log entries filed this session:
- `Database_and_State/ARCHCODE-2026-09-27-verdict-check-constraint-inverted-polarity.md`
- `Database_and_State/ARCHCODE-2026-09-27-submitted-code-discarded-despite-202-durability.md`
- `Backend_and_API/ARCHCODE-2026-09-27-django-lazysettings-drops-lowercase-names.md`
- `Backend_and_API/ARCHCODE-2026-09-27-websocket-replay-cursor-derived-from-max-seq.md`
- `Backend_and_API/ARCHCODE-2026-09-27-exceeds-budget-false-instead-of-null.md`
- `Backend_and_API/ARCHCODE-2026-09-27-django-tests-need-transactional-db-with-async-bridge.md`

Prior reports:
- `reports/ARCHCODE-2026-09-27-runner-architecture-decision.md` — Django owns the schema; the
  async bridge decision this report's isolation model follows from
- `reports/ARCHCODE-2026-09-27-run-latency-budget.md` — the ~2.5s vs ~92s figures that make
  `over_budget` a headline field
- `reports/ARCHCODE-2026-09-26-execution-availability.md` — why `execution` stays false

Key files: `runner/core/db.py`, `runner/tests/conftest.py`, `runner/attempts/models.py`,
`runner/api/routes/ws.py`, `runner/pyproject.toml`

---

**Completed By:** Claude (opencode)
**Duration:** ~2.5 hours
