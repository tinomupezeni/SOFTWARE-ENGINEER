# Blue-Green: Green Stood Up, Staging Domains Reused for the Inactive Color

**Date:** 2026-10-01
**Project:** HBEC
**Type:** Infrastructure Completion
**Status:** Completed

## Summary
Brought up all 9 `-green` containers (same real shared database, same
pattern already proven for blue) and changed `render-caddyfile.sh`'s design
on user request: instead of new `blue-*`/`green-*` debug-vhost subdomains
(which would have needed new DNS records), the retired `staging-*.hbca.tech`
domains — real DNS already in place — are reused, always routed to
whichever color is currently *inactive*. Both colors are now live
simultaneously for the first time on real infrastructure: blue serving all
public traffic, green reachable only via the basic-auth-gated staging
domains.

## Context / Trigger
Direct follow-up to the first real cutover. User asked whether green was
up and reachable via "the staging domains" — it wasn't (only blue had been
started) — and on clarifying that the original design used new `blue-*`/
`green-*` names instead, explicitly chose to reuse the real
`staging-*.hbca.tech` domains instead, since their DNS already exists.

## Scope
**Included**: redesigning the debug-vhost section of
`render-caddyfile.sh` to route `staging-*` domains to the inactive color
(computed from `active_color`, not fixed); bringing up all 9 `-green`
containers; confirming DNS still resolves for the reused domains;
verifying the new routing is actually live, both via direct Caddy config
inspection and via HTTP response.

**Explicitly excluded**: any change to which color serves real public
traffic (still blue, untouched by this work) or to the already-completed
cutover.

## Decisions & Findings

### `staging-*` must mean "the inactive one," not a fixed color
The domains' entire value is letting someone check the *candidate* before
it goes live. If they were hardwired to one literal color, they'd point at
real production traffic's own color after the next cutover — exactly
backwards. `render-caddyfile.sh` now computes `INACTIVE` as the opposite of
`active_color` on every render, so these domains automatically track
"whichever one isn't live" as cutovers happen over time, with no separate
bookkeeping.

### Reusing real domains avoided a real unknown
The original `blue-*`/`green-*` naming would have needed new DNS records
whose existence hadn't been confirmed — exactly the kind of gap that caused
repeated certificate-renewal failures for the old `staging-*` domains
earlier in this session, once their upstreams became unreachable. Checking
first (`getent hosts` against all five reused domains) confirmed 4 of 5
already resolve to this VPS; the fifth (`staging-school-api.hbca.tech`)
doesn't — consistent with `school-api.hbca.tech` itself not resolving
either, a pre-existing, unrelated DNS gap flagged in the previous report,
not something this change introduces.

### Verification needed a workaround for an unknown credential
The basic-auth password protecting these domains is only available as a
bcrypt hash in the compose file (by design — rotated via `caddy
hash-password`, plaintext never stored). Couldn't do a fully authenticated
`curl` test without it. Verified correctness a different way instead:
read Caddy's own loaded, live config directly
(`docker exec hbec-gateway cat /etc/caddy/Caddyfile`) and confirmed
`staging-student.hbca.tech`'s block explicitly names
`hbec-student-frontend-green` as its upstream — a direct, conclusive check
that didn't depend on having the credential.

## Changes Made
- **Repo** (`master`, one commit): `render-caddyfile.sh` rewritten —
  `blue-*`/`green-*` debug vhosts replaced with `staging-*.hbca.tech`
  blocks routed to the computed inactive color.
- **VPS, `/opt/hbec`**: updated script deployed; all 9 `-green` containers
  created and confirmed healthy; Caddy re-rendered and reloaded with both
  the (unchanged) public-domain routing and the new staging-domain
  routing.

## Verification
- All 9 green containers healthy (or, for the 3 services with no
  compose-level healthcheck, consistent with the same already-established
  gap in blue/old).
- `staging-student.hbca.tech`/`staging-admin.hbca.tech` both returned 401
  (the basic-auth gate correctly engaging) rather than 404/timeout,
  confirming the routing block itself is live.
- Direct inspection of Caddy's own loaded config confirmed
  `staging-student.hbca.tech` routes to `hbec-student-frontend-green`
  specifically.
- Public domains re-confirmed unaffected — `student.hbca.tech` still 200,
  still served by blue.
- Resources confirmed healthy with both colors now running simultaneously:
  43GB RAM available, 91GB disk available.

## Follow-ups / Deferred
- Same bake-period and eventual decommission-of-old plan as the previous
  report — unaffected by this change.
- `staging-school-api.hbca.tech`'s DNS gap remains open, same as
  `school-api.hbca.tech` — not actioned, flagged for whoever owns DNS.

## References
- [`HBEC-2026-10-01-first-real-bluegreen-cutover.md`](HBEC-2026-10-01-first-real-bluegreen-cutover.md)

---

**Completed By:** Claude Sonnet 5
**Duration:** Single session (2026-10-01), continuing directly from the first real cutover.
