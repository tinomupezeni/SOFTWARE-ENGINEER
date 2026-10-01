# Blue-Green: First Real Cutover — Blue Now Live

**Date:** 2026-10-01
**Project:** HBEC
**Type:** Production Cutover
**Status:** Completed

## Summary
Stood up real `-blue` containers for all 9 duplicated services on live
production, validated them thoroughly (including real AI API connectivity
end-to-end), found and fixed one real bug during that validation, then
executed the first-ever real blue-green cutover: singleton workers/beat
handed off to blue, public traffic switched via `render-caddyfile.sh`, and
`active_color` written. Every public domain confirmed served by blue
immediately after. The old (pre-blue-green) environment was never torn
down — it remains running, untouched, as the instant rollback target for
a deliberate bake period before any decommissioning.

## Context / Trigger
Direct continuation of the blue-green rollout: Phase 0 (isolated dry run),
the repo-side compose/CD rewrite, and the staging VPS teardown were all
already complete. This is the step those were building toward — the first
time any of this touches real public traffic. User's explicit instruction
before authorizing this: verify blue thoroughly, including real AI API
access, before any cutover — not just configuration checks.

## Scope
**Included**: bringing up all 9 `-blue` containers against the real,
shared production database; a multi-layered validation pass (live-data
match, same-color peer pinning via real signed calls, real AI provider
connectivity, a real end-to-end LLM completion); fixing a genuine bug found
during that validation; the singleton worker/beat handoff; the actual
public traffic cutover.

**Explicitly excluded**: decommissioning the old environment (deliberately
deferred to a separate, later step after a bake period); starting `green`
(not needed yet — this cutover proves the mechanism with blue alone);
`deploy-color`/`cutover` as automated CI jobs (this first cutover was done
by hand, mirroring exactly what those jobs will do, as planned — the CD
pipeline's first real exercise comes with the next ordinary commit).

## Method
Every step verified before moving to the next, consistent with this
session's established discipline: health status checked individually
(several of the 9 services have no compose-level healthcheck at all —
confirmed this matches the *old* environment's identical gap, not a new
one); real data checked against the shared database directly, not assumed;
every verification result compared against the old environment's own
behavior where a direct comparison was possible, to separate "blue-green
caused this" from "this was already true."

## Decisions & Findings

### AI API verification went beyond "is the key set"
Per explicit instruction, this wasn't a health-check-only pass. Triggered
the harness's real `provider_health` check (normally a background timer)
directly inside `harness-blue`, read the resulting Prometheus metrics, and
confirmed Groq and Google/Gemini both authenticate successfully against
their *real* provider catalogs, with every model `litellm_config.yaml`
depends on confirmed present upstream. Then went further and ran an actual
completion through `harness-blue`'s `call_llm()` — "What is 7 plus 5?" →
`"12"`, routed through Groq, confirming the full request path end-to-end,
not just connectivity. The self-hosted GPU-tunnel models showed
unreachable — confirmed identical on the *old* harness in the same check,
so a pre-existing condition, not something this work introduced.

### A real bug found by the verification process working as intended
`verify-service-links.sh -blue` surfaced that `student-backend-blue`'s
payment-related calls were hitting the *old* unsuffixed `payments`
container, not `payments-blue`. Root cause: `student-backend` never had
`PAYMENT_SERVICE_URL` explicitly set in the compose file at all (unlike
`admin-backend`, which did) — it fell through to Django's hardcoded
default, which happened to equal the correct value in today's
single-environment world but silently broke the same-color-pinned
invariant blue-green depends on. This is exactly the kind of gap the
verification step exists to catch before cutover, not after. Fixed,
redeployed just that one container, re-verified clean, committed and
pushed.

### Timing noise during verification, not a real problem
One check appeared to show a request hitting the old frontend instead of
blue immediately after the Caddy switch — a closer, precisely-timed retest
confirmed it was serving correctly from blue; the first check's log window
had simply already rolled past the request by the time it was inspected.
Documented here as a reminder that a single ambiguous log read during a
live cutover is worth a second, tighter-timed look before treating it as a
finding.

### A `school-api.hbca.tech` DNS gap, unrelated to this work
`curl` against `school-api.hbca.tech` returned "could not resolve host" —
confirmed this is a DNS-level gap (the domain has no A record), entirely
independent of which container Caddy would route it to. Not caused by this
cutover; flagged here so it isn't mistaken for a cutover regression later.

## Changes Made
- **VPS, `/opt/hbec`**: all 9 `-blue` containers created and running;
  `student-worker`/`student-beat`/`admin-worker`/`admin-beat`/
  `notifications-worker`/`notifications-beat` recreated in place (same
  container names, same singleton design) pointed at blue's peers;
  `docker/caddy/Caddyfile` regenerated via `render-caddyfile.sh` with all
  five public domains now routed to blue; `/opt/hbec/active_color` written
  (`blue`).
- **Repo** (`master`, one commit): `PAYMENT_SERVICE_URL` added to
  `student-backend-blue`/`student-backend-green`'s environment.
- **Old environment**: every old unsuffixed app-tier container
  (`student-backend`, `admin-backend`, `harness`, `payments`,
  `schools-backend`, `schools-dashboard`, the two frontends,
  `notifications`) left running, completely untouched, as the rollback
  target.

## Verification
- All 9 blue containers confirmed healthy (or, for the 3 with no
  compose-level healthcheck, confirmed behaving identically to their old
  counterparts via direct probes).
- A real, known user record pulled identically through both old and blue
  student-backend, directly against the same live Postgres — confirmed
  blue reads live data, not a copy.
- `verify-service-links.sh -blue`: every signed service-to-service link
  verified, including the one bug found and fixed mid-verification.
- Real AI API connectivity: provider-catalog authentication confirmed for
  Groq and Gemini; a real end-to-end completion returned the correct
  answer to a real question.
- Every public domain re-checked immediately after the Caddy switch,
  confirmed served by blue via direct log correlation (not just HTTP
  status) on `student`, `admin`, and `payments` (via `api.hbca.tech`).
- Exactly one instance of each singleton confirmed running post-handoff —
  no double-processing window.
- Old app-tier containers confirmed still running, untouched, immediately
  available as the rollback target.

## Follow-ups / Deferred
- **Bake period**: watch stability (public health, any monitoring
  available) before touching the old environment at all — this is a
  separate, later, deliberate action, not bundled with the cutover itself.
- **Decommission old**: only after the bake period — stop the old
  containers, then remove their now-dead compose blocks in a follow-up
  commit.
- **`deploy-color`/`cutover` CD jobs**: this cutover was executed by hand;
  the next ordinary commit to master will be the first real exercise of
  the automated `deploy-color` job (deploying to the now-inactive `green`),
  and a future manual `cutover` dispatch will be the first automated
  cutover.
- `school-api.hbca.tech`'s DNS gap — unrelated to this work, flagged for
  whoever owns DNS, not actioned here.

## References
- [`HBEC-2026-10-01-staging-vps-teardown.md`](HBEC-2026-10-01-staging-vps-teardown.md)
- The full blue-green report series from this session
  (`reports/HBEC-2026-10-01-blue-green-*.md`)

---

**Completed By:** Claude Sonnet 5
**Duration:** Single session (2026-10-01), continuing directly from the staging teardown and the architecture/rollout plan approved earlier in the session.
