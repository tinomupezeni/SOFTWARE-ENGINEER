# New Caddy security headers pushed to app deploy dir, never merged into the live central Caddyfile

**Date:** 2026-11-17
**Project:** MARITCHO
**Environment:** Development (found in code review, PR #12, branch `pr-12`)
**Severity:** Medium
**Status:** Confirmed — not yet fixed (found during verification of a candidate code-review finding)

## Summary
This PR adds `deploy/production/Caddyfile.maricho` (HSTS, X-Frame-Options, Referrer-Policy,
Permissions-Policy headers, TLS settings, health/websocket routing), and `deploy.sh` now uploads it
via `push_file "$PRODUCTION_DIR/Caddyfile.maricho" "$MARICHO_REMOTE_DIR/Caddyfile.maricho"` —
landing it in the app's own deploy directory on the remote host (`$MARICHO_REMOTE_DIR`, default
`apps/maricho`), not the central/shared Caddy config directory the actual running `caddy-proxy`
container reads from. `README.md` separately documents the real activation step — manually `scp` the
file into `/home/winstontino/core/Caddyfile.maricho` and `docker restart caddy-proxy` — which
`deploy.sh` does not automate. `deploy.sh` prints `"Uploading production Compose & Caddy configuration"`
immediately before the no-op upload, which could lead an operator to believe Caddy is now
fully wired up by running `deploy.sh` alone and skip the still-required manual merge+restart, leaving
the new security headers inert in production despite `deploy.sh` reporting success.

## Symptoms
- Not yet observed in production; found via verification of a candidate finding surfaced during
  review of PR #12.
- Running `deploy.sh` reports success and prints a message implying Caddy config was uploaded, but the
  live reverse proxy never sees the new file unless a separate manual `scp`+restart (documented only in
  README.md) is performed.

## Environment Details
- **Server/Host:** Production VPS (deploy target), shared central Caddy instance (`caddy-proxy`)
- **Services Affected:** TLS/security headers for the Maricho domain
- **Related Components:** `deploy/production/deploy.sh`, `deploy/production/Caddyfile.maricho`,
  `deploy/production/README.md`
- **Time First Observed:** 2026-11-17, verifying a candidate finding against PR #12 (`pr-12`)

## Investigation Steps

### 1. Initial Diagnosis
A candidate finding claimed deploy.sh's Caddy-related upload only lands the file in the app's own
directory, not the shared Caddy config path, and that deploy.sh's own messaging could mislead an
operator into thinking the step was fully automated.

### 2. Root Cause Analysis
- `deploy.sh` (pr-12):
  ```
  retry push_file "$PRODUCTION_DIR/docker-compose.yml" "$MARICHO_REMOTE_DIR/docker-compose.yml"
  retry push_file "$PRODUCTION_DIR/Caddyfile.maricho" "$MARICHO_REMOTE_DIR/Caddyfile.maricho"
  ```
  `$MARICHO_REMOTE_DIR` defaults to `apps/maricho` — confirmed by the earlier
  `mkdir -p '$MARICHO_REMOTE_DIR' '$MARICHO_REMOTE_DIR/backups'`. Nothing in the rest of the remote
  SSH block (which only does `docker compose up -d`, migrations, pgvector check, health checks)
  references `caddy`, `/home/winstontino/core`, or a `caddy-proxy` restart — grep confirms zero
  mentions. `docker-compose.yml` for this stack also has zero Caddy references.
- `README.md` (pr-12) independently documents the real step under "Central Caddy
  (`Caddyfile.maricho`)": `scp deploy/production/Caddyfile.maricho deployer@vps:/home/winstontino/core/Caddyfile.maricho`
  then `ssh deployer@vps docker restart caddy-proxy` — explicitly separate from the `deploy.sh`
  invocation documented just above it, and nowhere invoked by `deploy.sh`.
- `deploy.sh` prints `"Uploading production Compose & Caddy configuration"` right before the two
  `push_file` calls, which land the file in the app's own directory only. The script's final success
  message (`"Deployment completed successfully: $MARICHO_IMAGE_TAG"`) gives no indication the Caddy
  headers are still inert.

### 3. Key Findings
- Caddy is a shared/central service this stack intentionally doesn't manage directly (by design, since
  multiple apps likely share one Caddy instance on the VPS) — the gap is specifically that `deploy.sh`'s
  own log output doesn't distinguish "uploaded for reference" from "activated," so the step is easy to
  believe is done when it isn't.

## Root Cause
`deploy.sh`'s banner text ("Uploading production Compose & Caddy configuration") describes both
`docker-compose.yml` and `Caddyfile.maricho` identically, even though only the former is actually
consumed by anything the script subsequently runs — the latter is uploaded purely for convenience/
reference and requires a separate, undocumented-in-script manual step to take effect.

## Prevention / Rule
**Guardrail:** Change `deploy.sh`'s echo immediately after the `Caddyfile.maricho` push to explicitly
state it is NOT yet active — e.g. `"Caddyfile.maricho staged at $MARICHO_REMOTE_DIR — merge into central Caddy manually per README.md to activate"` —
and/or print a final deploy summary section listing "Manual steps still required" sourced from
README.md's "Central Caddy" section, so a success run can never be silently mistaken for full
activation.

This targets the Root Cause directly: the misleading signal is in the script's own output text, so
fixing that text (without needing to change the actual manual-merge architecture) removes the
operator-facing ambiguity.

## Solution

### Immediate Fix
Not yet applied — this entry documents a confirmed operational gap found during review of PR #12; it
has not been fixed on `pr-12` or `main` as of this writing.

### Long-term Fix
- Update `deploy.sh`'s echo text per the guardrail above.
- Longer-term, consider making the central Caddy config auto-load per-app snippets (e.g. an
  `import ./sites-enabled/*.caddy` directive in the real central Caddyfile, with `deploy.sh` scp'ing
  straight into that imported directory) so no manual merge step exists at all.

## Prevention
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — none
- [x] Documentation to update — `deploy.sh`'s own output text, to stop implying Caddy is fully wired up
      (not yet done)
- [x] Code changes required — clarify the echo message in `deploy.sh` (not yet implemented)

## Related Issues
- Found while reviewing MARITCHO PR #12 (branch `pr-12`), the same PR that introduced
  `Caddyfile.maricho`.
- Related to `DevOps_and_Infrastructure/MARITCHO-2026-11-17-deploy-sh-no-longer-cycles-db-redis-containers.md`,
  same script, different area.

## References
- `deploy/production/deploy.sh` (push_file calls for `Caddyfile.maricho`)
- `deploy/production/Caddyfile.maricho`
- `deploy/production/README.md` ("Central Caddy" section)
- PR: MARITCHO #12, branch `pr-12`

---

**Resolved By:** Not yet resolved — documented by tinomupezeni (via Claude Code)
**Time to Resolution:** N/A (open)
