# `shopify/toxiproxy:latest` ships CLI 2.1.4 and its verb surface broke the harness

**Date:** 2026-09-27
**Project:** ArchCode
**Environment:** Development
**Severity:** Medium
**Status:** Workaround Applied

## Summary
The runner's fault-injection dependency was referenced as `shopify/toxiproxy:latest`. That tag
currently resolves to a build whose bundled CLI is version 2.1.4, whose command surface differs
from the modern documentation: the proxy verb is `create`, not `add`, and there is no
`populate` subcommand. The requested `shopify/toxiproxy:2.9.0` tag does not exist. Because
fault profiles are the mechanism the product's most valuable lesson depends on, an unpinned tag
means a scenario's exact network conditions are not reproducible across time or machines —
directly at odds with PRD §7.4's determinism requirement.

## Symptoms
- `docker pull shopify/toxiproxy:2.9.0` failed: `not found`.
- The CLI was not at the documented path: `exec: "/toxiproxy-cli": no such file or directory`.
  It lives at `/go/bin/toxiproxy-cli`.
- `toxiproxy-cli add` failed with `No help topic for 'add'`.
- Correct invocation is `create <name> --listen <addr> --upstream <addr>`, and toxics need
  `--type/-t`, `--toxicName/-n`, `--attribute/-a`, and an explicit `--upstream`/`--downstream`.
- The bundled binary self-reports `VERSION: 2.1.4`.

## Environment Details
- **Server/Host:** Local development host, Docker 29.8.0.
- **Services Affected:** Fault injection in the runner sandbox; scenario reproducibility.
- **Related Components:** `runner/bench/latency.py`, the stub gateway, PRD §7.4 (determinism).
- **Time First Observed:** 2026-09-27, while building the latency benchmark.

## Investigation Steps

### 1. Initial Diagnosis
Treated it as a wrong path and a wrong verb, assuming a recent CLI behind a moving tag.

### 2. Root Cause Analysis
```bash
docker inspect shopify/toxiproxy:latest --format '{{.Config.Entrypoint}} {{.Config.Cmd}}'
#   [/go/bin/toxiproxy] | [-host=0.0.0.0]

docker run --rm --entrypoint sh shopify/toxiproxy:latest -c \
  'find / -maxdepth 4 -name "*toxiproxy*" 2>/dev/null'
#   /go/bin/toxiproxy
#   /go/bin/toxiproxy-cli

docker exec <toxi> /go/bin/toxiproxy-cli    # VERSION: 2.1.4
```
The image predates the current documented CLI, and `:latest` is free to move.

### 3. Key Findings
- CLI lives at `/go/bin/toxiproxy-cli`; the common `/toxiproxy-cli` path does not exist.
- The verb is `create`; `add` and `populate` are unavailable in this build.
- Requested tag `2.9.0` does not exist, so there is no obvious intended pin.
- `:latest` on a Go tool means silent, unreviewed drift in both CLI and server behaviour.

## Root Cause
The dependency was specified by floating tag rather than by digest or a verified version, so
the harness was written against assumed documentation instead of the actual artifact, and no
mechanism guarantees the artifact stays the same. For a fault injector this is a correctness
risk, not just a maintenance one: the same scenario could produce different network conditions
on different days without any visible change.

## Prevention / Rule
**Guardrail:** Pin every container image in the runner by digest, and assert the Toxiproxy
version and CLI verb surface in a pre-flight check before a scenario runs.

An unpinned image makes "the same scenario" undefined over time, which silently violates
§7.4's determinism requirement. Asserting the version turns silent drift into an explicit,
failing check.

## Solution

### Immediate Fix
Used the correct 2.1.4 invocation, discovered from the binary's own help output rather than
from documentation:
```bash
docker exec <toxi> /go/bin/toxiproxy-cli create bench_pg \
  --listen 0.0.0.0:8666 --upstream postgres:5432
docker exec <toxi> /go/bin/toxiproxy-cli toxic add bench_pg \
  -t latency -n fixed5 -a latency=5 -a jitter=0 --upstream
```

### Long-term Fix
- Identify the intended Toxiproxy version and pin it by digest.
- Add a pre-flight version/verb-surface assertion to the harness (alongside the existing
  single-endpoint assertion).
- Record the pinned digest in the design docs so fault profiles are reproducible.

## Prevention
- [x] Correct invocation derived from the artifact's own help output
- [ ] Pin the image by digest
- [ ] Add a pre-flight version/verb-surface assertion
- [ ] Record the digest in the design docs

## Related Issues
- `DevOps_and_Infrastructure/ARCHCODE-2026-09-27-bench-stale-container-alias-mixed-servers.md`
  — the other reproducibility hazard found in the same harness.

## References
- `reports/ARCHCODE-2026-09-27-run-latency-budget.md` — Follow-ups item 3
- `ARCHCODE-PRD.md` §7.4 (determinism), §10
- `Club Zero/runner/bench/latency.py`

---

**Resolved By:** Claude (Claude Code)
**Time to Resolution:** ~20m
