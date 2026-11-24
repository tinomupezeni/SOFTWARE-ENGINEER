# Shared GitHub Actions PR-review workflow

**Date:** 2026-11-24
**Project:** SOFTWARE-ENGINEER (cross-project tooling)
**Type:** Architecture Decision / New Capability
**Status:** Completed

## Summary
Added a reusable GitHub Actions workflow that auto-reviews pull requests
against the standard in `Principal_Engineer/engineering-guides/24. Code
Review.md`, using Claude Code. Routine findings post as a normal review
comment; the agent only stops the check and @mentions the user when it hits
something that genuinely needs a human decision (ambiguous intent, a real
architectural trade-off, a Tier 3/4-risk issue). The review logic lives in
exactly one place in this repo and every project only needs a ~15-line
caller file, so improving the review protocol never requires touching more
than one project's config again.

## Context / Trigger
User asked for PR auto-review across projects that pings them with the
specific reason when the agent can't resolve something on its own, and
asked explicitly for this to be a single reusable template in this repo
rather than new per-project setup each time.

## Scope
**Included:** the reusable workflow, the per-project caller template, the
condensed review prompt (derived from guide 24's decision tree, defect
taxonomy, and Conventional Comments format), setup docs, and manifest/index
cross-references so the template is discoverable the way the repo's other
guides are.

**Excluded:**
- Rolling the caller file out into any actual project repo — none were
  copied in this session; that's a per-project follow-up.
- Slack/email notification — deliberately not built. A GitHub `@mention` in
  a PR comment already triggers a GitHub notification (and email, if the
  user's notification settings route PR mentions to email), so no second
  notification channel was added.
- Verifying `anthropics/claude-code-action`'s exact current input schema
  live against its repo — flagged as an assumption to confirm on first run
  (see Follow-ups).

## Method
Read the existing guide library conventions first (`index.md`'s "rewire a
guide into a project" pattern, `MANIFEST.md`'s per-guide `applies_to`
structure) and followed the same shape: one shared source of truth, each
project absorbs only a small pointer/copy, not the whole thing. Condensed
guide 24's decision tree (7 ordered gates), defect taxonomy (6 categories +
merge-policy), and Conventional Comments format into a prompt file rather
than having CI fetch and parse the full guide at runtime — keeps the prompt
small and the dependency direction simple (one `curl` of a flat prompt
file, not a guide-library clone).

Confirmed the repo is public (`gh repo view` → `visibility: PUBLIC`), which
is what makes the reusable-workflow call from other (possibly private)
project repos work via `uses: tinomupezeni/SOFTWARE-ENGINEER/.github/workflows/...@main`
without extra cross-repo permission configuration.

## Decisions & Findings
- **One reusable workflow, not a copy-pasted template per project.** GitHub
  Actions' `workflow_call` reuse mechanism supports this directly when the
  called repo is public, which this one is — so the "don't want new stuff
  per project" ask is satisfiable exactly as asked, not just approximated.
- **The prompt is fetched at run time from `main`**, not copied into each
  project, so a protocol change propagates to every project's next PR
  without touching any project repo. A `ref` input exists on the reusable
  workflow if a project ever needs to pin an older prompt version during a
  rollout.
- **Ping scope is narrow by design.** The prompt explicitly separates
  "ordinary blocker, just report it" from "stop and ping" — only the latter
  gets the `@mention` + label + failed check. This was a deliberate
  reading of the user's ask ("if there are decisions, bugs, or stuff like
  that") as wanting escalation for judgment calls specifically, not a ping
  on every routine finding, which would defeat the point of automating
  review at all.

## Changes Made
- `.github/workflows/claude-pr-review.yml` — the reusable workflow (new)
- `templates/github-workflows/pr-review.yml` — per-project caller template (new)
- `templates/github-workflows/review-prompt.md` — condensed review protocol (new)
- `templates/github-workflows/README.md` — setup instructions (new)
- `Principal_Engineer/engineering-guides/MANIFEST.md` — added an
  **Automation** note under guide 24 pointing at the template
- `index.md` — added a folder-map note and a "what are you trying to do"
  entry pointing at `templates/github-workflows/README.md`

## Verification
- Both workflow YAML files parsed successfully with `yaml.safe_load`.
- No live PR was run against this yet — nothing to verify behaviorally
  until a project copies in the caller file and opens a PR.

## Follow-ups / Deferred
- **Verify `anthropics/claude-code-action`'s current `with:` input names**
  (`anthropic_api_key`, `prompt_file`, `allowed_tools`, etc.) against its
  own README before the first real run — the workflow file carries an
  inline comment flagging this, since action interfaces shift across major
  versions and this was written from a point-in-time understanding, not
  verified live against the action's current docs.
- Copy `pr-review.yml` into an actual project repo (e.g. HBEC, TESC) and add
  the `ANTHROPIC_API_KEY` secret, then watch the first real PR run.
- Decide whether `ANTHROPIC_API_KEY` should be an organization-level secret
  instead of per-repo, if more projects adopt this.

## References
- `Principal_Engineer/engineering-guides/24. Code Review.md` — the
  underlying review standard this automates
- `Principal_Engineer/engineering-guides/Code Integration.md` — surrounding
  CI/branching mechanics, not duplicated here

---

**Completed By:** Claude (Sonnet 5.5), on behalf of Tino
**Duration:** Single session
