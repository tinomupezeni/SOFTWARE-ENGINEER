# Engineering Skills — Sync with 2026-11-23 Guide Updates

**Date:** 2026-11-23
**Project:** Global Engineering / engineering-skills (public distribution)
**Type:** Standards Update
**Status:** Completed

## Summary
Propagated the guardrails added to this repo's canonical engineering guides
(the 2026-11-23 cross-sector dev-log audit, see
`reports/Global-Engineering-2026-11-14-all-logs-reading.md`) into the public
`engineering-skills` pack (`/home/shadowe/Projects/engineering-skills`,
`github.com/tinomupezeni/engineering-skills`), which is a generated-and-
curated distribution of this repo's guides as portable `SKILL.md` files for
Claude/Codex/Cursor/Copilot.

## Context / Trigger
Having just finished converting the cross-sector log audit's findings into
guide sections, the user asked to check whether the separate "engineering
skills" distribution derived from these guides needed updating to match.

## Scope
**In scope:** the 12 individual skills and the `manifests/source-map.yaml` /
`CHANGELOG.md` bookkeeping in `engineering-skills`. Updates were limited to
skills whose declared `source-map.yaml` guide numbers were touched in the
2026-11-23 and 2026-11-23-continuation passes (guides 1, 5, 6, 7, 10, 11, 18,
20), plus adding guide 1 and guide 7 to the source lists for
`engineering-baseline`/`task-contract` and `agent-delegation` respectively,
since those skills' existing scope was the natural home for new material that
guide 1's "Potemkin generalization" and guide 7's "prompt injection targeting
the agent" sections introduced.

**Explicitly excluded:** guides 12 (HCI) and 3 (Mobile App Agent-First
Development) were also updated with new sections in the guide-library pass
(design-token contrast/distinctness, parity-tooling blind spots), but no
public skill currently sources from either guide — there is no
UX/accessibility or mobile-parity skill in the pack. Propagating those two
findings would require creating new skills, which was not requested and is
left as a follow-up. The `bundles/` router files were checked and contain no
duplicated skill content, so none needed editing.

## Method
Read each target skill's current `SKILL.md`, cross-referenced it against the
specific new guide sections per `manifests/source-map.yaml`'s existing
source-to-skill mapping, and added the smallest guardrail-level addition that
captured the new rule in the pack's existing compact style (the pack is
"intentionally smaller than the source guides," per its own README) rather
than copying guide prose verbatim. Ran `npm run validate` after all edits.

## Decisions & Findings
- `database-change-safety` and `distributed-consistency` (sources 6, 22):
  added the check-then-act/lock-ownership guardrail and the seed/sync
  atomic-reconciliation guardrail respectively.
- `security-boundaries` (sources 7, 24): added the singular-authorization-
  predicate guardrail.
- `agent-delegation` (source 16, now also 7): added the prompt-injection-
  targeting-the-agent guardrail — this fit agent-delegation's existing
  handoff/trust framing better than security-boundaries, which is scoped to
  product-facing security boundaries rather than the agent's own trust in
  tool output.
- `deployment-truth` (sources 10, 18, 19): added the stateful-service-
  migration-not-deploy guardrail, the proxy-stale-upstream check, and the
  frontend-only-change stale-asset check.
- `contract-integrity` (sources 8, 11, 24): broadened bidirectional contract
  checks to internal boundaries (validation pairs, write/read paths,
  reshaping proxies) and added the error-shape-honesty guardrail.
- `configuration-parity` (source 5b): added the build-time-variable-actually-
  inlined guardrail, distinct from the existing forbidden-string bundle scan.
- `task-contract` and `engineering-baseline` (source 20, now task-contract
  and engineering-baseline also source 1): added the generalized
  declared-but-not-wired ("Potemkin component") completion check and the
  boundary-value/sentinel-exhaustiveness acceptance-criteria addition.
- Bumped `manifests/source-map.yaml`'s `generated_from_commit` to
  `79107a89e7cb88ab0e0f02f0bb8ab12efb47ff49` (the SOFTWARE-ENGINEER commit
  containing both guide-update passes) and added guide 1 to
  `engineering-baseline`/`task-contract` sources and guide 7 to
  `agent-delegation` sources, since the pack's own freshness-check script
  (`scripts/check-source-freshness.js`) compares this field against the
  canonical repo's latest commit touching `engineering-guides/`.
- Added a `CHANGELOG.md` entry under `[Unreleased]` summarizing the sync, per
  the pack's own `CONTRIBUTING.md` checklist.

## Changes Made
11 files changed in `engineering-skills` (commit `0ae33ce`): the 9 skill
`SKILL.md` files listed above, `manifests/source-map.yaml`, and
`CHANGELOG.md`. No skill's YAML frontmatter (`name`/`description`) changed.
Pushed to `github.com/tinomupezeni/engineering-skills` (main) after explicit
user confirmation, since it is a separate public repository from this one.

## Verification
- `npm run validate` in `engineering-skills` passed: "Validated 15 skill
  surfaces."
- `npm run source:check` was not run in this session (requires a live GitHub
  API call); the `generated_from_commit` bump was done by hand against the
  known SOFTWARE-ENGINEER HEAD at the time of the sync.
- Confirmed via `cat` that `bundles/*/SKILL.md` files only reference skill
  names and contain no content needing a parallel edit.

## 2026-11-23 Continuation — Added the Two Deferred Skills

Per follow-up, the user asked to close the guide-12/guide-3 gap rather than
leave it deferred. Added two new skills to `engineering-skills`:

- `accessibility-usability` (source: guide 12 HCI) — design-token
  contrast/distinctness regression checks, error-state honesty (no coercing
  an error into a generic/empty state), form/dialog recoverability rules, and
  boundary-case input-device/state testing (multitouch, memoized-value
  staleness, per-attempt state leakage — the last also overlaps guide 20,
  intentionally, since it's a UI-correctness concern from both angles).
- `mobile-parity` (source: guide 3 Mobile App Agent-First Development) —
  cross-client (web/mobile) contract drift as a first-class failure mode, and
  auditing parity/screen-map tooling itself rather than trusting a "0 gaps
  found" result, since the tooling was found blind to nested features in the
  source incident.

Wired both into `manifests/pack.yaml` (skills list), `manifests/source-map.yaml`
(sources 12 and 3 respectively), the README's skill-selection table, and
`CHANGELOG.md`; lightly trimmed the now-delivered "accessibility" item out of
`ROADMAP.md`'s "Later" section. `npm run validate` passed at 17 skill
surfaces (up from 15). Committed and pushed to
`github.com/tinomupezeni/engineering-skills` (commit `4ba4c5a`).

Neither skill was added to an existing bundle (`production-engineering-pack`,
`agent-engineering-pack`, `ai-systems-engineering-pack`) — both are
domain-specific (UI/mobile) rather than a universal production control, so
forcing them into a general bundle would blur those bundles' scope; a project
installing them does so by name, same as any other specialist skill not in a
bundle.

## 2026-11-23 Continuation — Local Install Refreshed Across Agents

The user asked whether the public-repo updates were actually live for any
agent on this machine. They were not: the shared local install at
`~/.agents/skills/` (installed via the `skills` CLI from
`tinomupezeni/engineering-skills` on 2026-10-17, per `~/.agents/.skill-lock.json`)
predated every change made in this session, and the two new skills didn't
exist at install time. Refreshed it:

- `npx skills update -g -y` updated the 9 skills whose content changed in the
  first guide-sync pass (`agent-delegation`, `configuration-parity`,
  `contract-integrity`, `database-change-safety`, `deployment-truth`,
  `distributed-consistency`, `engineering-baseline`, `security-boundaries`,
  `task-contract`).
- `npx skills add . -g -a '*' -s accessibility-usability -s mobile-parity -y`
  installed the two new skills, universal-copied or symlinked into 77 of 79
  agent integrations the `skills` CLI recognizes on this machine (everything
  except Eve and PromptScript, which the CLI reports don't support global
  skill installation at all).
- `issue-to-production` and `observability-correctness` were found scoped to
  only 7 agents from the original 2026-10-17 install (narrower than the other
  ten skills' 61+), and were widened to the same 77-agent footprint for
  consistency.
- Verified byte-for-byte parity between every file in
  `/home/shadowe/Projects/engineering-skills/skills/*/SKILL.md` and its
  installed copy under `~/.agents/skills/`, and ran `npm run source:check`,
  which confirmed the local pack is current against the live
  `tinomupezeni/SOFTWARE-ENGINEER` commit (`79107a89e7cb88ab0e0f02f0bb8ab12efb47ff49`).

**Finding, separate from this refresh:** before today, only Claude Code's
`~/.claude/skills/` actually symlinked the full `tinomupezeni/engineering-skills`
pack from `~/.agents/skills/`. Every other agent-tool config directory this
machine has (Codex, Grok, Qwen, Trae, Kiro, Augment, and dozens more) only had
an unrelated third-party skill (`cloudflare/security-audit-skill`) linked in,
not this pack — despite `~/.agents/skills/` existing since 2026-10-17 and the
`skills` CLI being fully capable of targeting all of them with `-a '*'`. The
2026-10-17 install evidently only ever targeted a handful of agents (or
Claude Code specifically) rather than the full agent list this CLI supports.
This refresh is the first time the pack was actually installed broadly.

## Follow-ups / Deferred
- Confirm with the user whether the Eve and PromptScript agent integrations
  (the two the `skills` CLI reports as unsupported for global install) are
  actually in use on this machine; if so, their skill-loading convention
  would need to be investigated separately since this CLI can't reach them.
- Re-run `npx skills update -g -y` the next time a guide-driven skill edit
  lands, rather than relying on a future session to notice the drift — this
  refresh step was missing from the original sync in this session and had to
  be added as a follow-up fix.
- Consider whether either new skill belongs in a bundle once real usage shows
  it's commonly installed alongside an existing pack rather than alone.

## References
- `reports/Global-Engineering-2026-11-14-all-logs-reading.md` (the guide
  updates this sync propagates)
- `/home/shadowe/Projects/engineering-skills/manifests/source-map.yaml`
- `/home/shadowe/Projects/engineering-skills/CONTRIBUTING.md`

---

**Completed By:** Claude Sonnet 5
**Duration:** ~20 minutes
