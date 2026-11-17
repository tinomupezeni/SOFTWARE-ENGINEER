# Frugal V1: LLM-Backed IGM Generator (Built, Not Yet Exercised)

**Date:** 2026-11-17
**Project:** Frugal
**Type:** Architecture Decision / Scope Decision (implementation)
**Status:** In Progress — code complete, blocked on credentials for live verification

## Summary
Built a second IGM generator, `igm/generate_candidate_llm.py`, that calls
the Anthropic Messages API to produce a candidate fix instead of the
hand-authored deterministic generator from the prior session. Unlike every
other Sprint-1 step so far, this one is explicitly **not** being reported
as proven end to end: this dev environment has neither `ANTHROPIC_API_KEY`
set nor `pip` available to install the `anthropic` SDK, so the live API
call path has not actually been exercised. This report exists to record
that distinction honestly rather than let "built" read as "done."

## Context / Trigger
Continuation of the same-day Frugal V1 implementation session. README.md's
Sprint-1 checklist named "make IGM's generation step LLM-backed" as the
next follow-up after the orchestrator job loop; user asked to proceed
with it.

## Scope
Included: `igm/llm_backend.py` (stdlib-only Anthropic API client, no SDK
dependency since `pip` isn't available here), `igm/generate_candidate_llm.py`
(same read/write contract as the deterministic generator, LLM-produced
candidate body).

Excluded (because untestable in this environment, not skipped silently):
an actual live API call and its resulting candidate going through
`iem/run_evaluation.py`.

## Method
Checked for `ANTHROPIC_API_KEY` and `pip`/`anthropic` availability before
writing any code, per this session's "verify before claiming" discipline.
Neither was present. Rather than installing nothing and writing untested
code that silently assumes a key will show up later, wrote the client to
fail loudly and specifically (`LLMBackendError`, a named refusal message)
when the key is absent, and proved that refusal path actually works by
running the script with no key set.

## Decisions & Findings
- **stdlib over SDK:** used `urllib.request` directly rather than the
  `anthropic` package, since this environment has no `pip` to install it.
  This is a deliberate environment-driven choice, not a general
  recommendation to avoid the SDK elsewhere.
- **Fail loudly, not silently:** `call_claude()` raises `LLMBackendError`
  with a specific message when `ANTHROPIC_API_KEY` is unset; the caller
  script prints that and exits 1, producing no candidate file. Verified
  by running `generate_candidate_llm.py FINDING-001-distributed-ssh-bruteforce`
  with no key in the environment.
- **Same governing constraint applies:** the system prompt explicitly
  tells the model it is not the one deciding acceptance, and the output
  is JSON-parsed defensively (an unparseable response is discarded with a
  printed reason, not silently accepted as a candidate). This is the same
  "IGM output is untrusted input to IEM" principle from ADR-001, applied
  to a literal LLM response this time rather than a hand-authored one.

## Changes Made
- `igm/llm_backend.py`, `igm/generate_candidate_llm.py` (new).
- `README.md` updated with an explicit "not yet proven" status and the
  exact command sequence to actually prove it once a key is available.

## Verification
- `python3 igm/generate_candidate_llm.py FINDING-001-distributed-ssh-bruteforce`
  with no `ANTHROPIC_API_KEY` set: printed
  `"ANTHROPIC_API_KEY is not set... refusing to fabricate a response"`,
  exit code 1, no candidate directory created. Confirmed via directory
  listing.
- Live API call path: **not verified.** Explicitly called out as
  unverified in both this report and README.md, rather than assumed to
  work because the code compiles/parses.

## Follow-ups / Deferred
1. Run `igm/generate_candidate_llm.py` with a real `ANTHROPIC_API_KEY` and
   push the resulting candidate through `iem/run_evaluation.py`, exactly
   as was already done for the deterministic candidate. Only after that
   should this step be marked Completed.
2. Wazuh + Suricata + OpenVAS integration.
3. Postgres-backed job table and DB-role separation of duties.

## References
- `Frugal/igm/llm_backend.py`, `Frugal/igm/generate_candidate_llm.py`.
- `reports/FRUGAL-2026-11-17-v1-orchestrator-job-loop.md` (prior report,
  same day).

---

**Completed By:** Claude (Sonnet 5), with tinomupezeni
**Duration:** Single session (continuation) — explicitly incomplete
