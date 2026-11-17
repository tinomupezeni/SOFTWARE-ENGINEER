# Docker Compose lab network failed to create: subnet pool overlap

**Date:** 2026-11-17
**Project:** FRUGAL
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
Bringing up the Frugal lab's Docker Compose stack (victim + 3 attacker
containers with static IPs) failed because the hardcoded `172.28.0.0/24`
subnet overlapped an existing Docker network pool already allocated on the
host.

## Symptoms
```
Network frugal-lab_lab-net Error Error response from daemon: invalid pool request: Pool overlaps with other one on this address space
failed to create network frugal-lab_lab-net: Error response from daemon: invalid pool request: Pool overlaps with other one on this address space
```
Occurred after both images built successfully — the failure was purely at
network-creation time.

## Environment Details
- **Server/Host:** Local dev machine (Linux), Docker 29.9.2 / Compose v5.6.1
- **Services Affected:** `lab-net` bridge network in `lab/compose/docker-compose.yml`
- **Related Components:** `victim`, `attacker1-3` services (static IPv4 addresses)
- **Time First Observed:** First `docker compose up` of the newly scaffolded lab

## Investigation Steps

### 1. Initial Diagnosis
Both container images (`frugal-lab-victim`) built without error; the
failure trace pointed specifically at network + volume creation, not the
build.

### 2. Root Cause Analysis
`172.28.0.0/24` is a commonly-used default range (also used by some other
local Docker/VM tooling on this host), so it collided with an existing
pool allocation. Ran `docker compose up` again after swapping the subnet.

### 3. Key Findings
- The compose file hardcoded a specific /24 that is popular enough to
  collide with other local Docker networks (e.g. another project's
  default bridge, or a VPN/VM tool's range).
- No conflict detection happens before `docker compose up` attempts
  creation — it fails late, after images are already built.

## Root Cause
A statically chosen subnet (`172.28.0.0/24`) for a Compose-managed bridge
network collided with a pre-existing pool allocation on the host.

## Prevention / Rule
**Guardrail:** pick less-common private subnets for lab/test Compose
networks that need static IPs (e.g. the `10.211.x.0/24` ULA-adjacent
range) rather than the `172.1x–3x.0.0/16` ranges Docker's own default pool
and many other tools draw from first.

This doesn't eliminate collisions outright, but avoids the specific range
most likely to already be in use on a dev machine running multiple Docker
projects.

## Solution

### Immediate Fix
Changed `lab/compose/docker-compose.yml`'s `lab-net` subnet from
`172.28.0.0/24` to `10.211.55.0/24`, and updated the victim/attacker
static `ipv4_address` values to match. Re-ran `docker compose up` —
succeeded.

```bash
sed -i 's/172\.28\.0\./10.211.55./g' lab/compose/docker-compose.yml
```

### Long-term Fix
No further action needed for this specific project; noted as a reusable
guardrail for any future Compose network needing static IPs on a shared
dev host.

## Prevention
- [x] Configuration changes needed (subnet changed)
- [ ] Monitoring/alerts to add — not applicable, dev-only lab
- [ ] Documentation to update — covered by this log entry
- [ ] Code changes required — none beyond the subnet value

## Related Issues
None.

## References
- `/home/shadowe/Projects/Frugal/lab/compose/docker-compose.yml`

---

**Resolved By:** Claude (Sonnet 5), with tinomupezeni
**Time to Resolution:** < 5 minutes
