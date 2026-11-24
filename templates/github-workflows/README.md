# GitHub Actions PR review template

One reusable workflow, shared by every project, that auto-reviews pull
requests with Claude Code against the standard in
`Principal_Engineer/engineering-guides/24. Code Review.md`. Ordinary findings
get posted as a normal review comment. If the review hits something that
needs a human decision (an architectural trade-off, a Tier 3/4 risk, an
ambiguous intent) it stops, pings you by @mention, and fails the check instead
of guessing.

## Why one shared workflow instead of copying a full file per project

The review logic (prompt, decision tree, stop/ping protocol) lives in exactly
one place: `.github/workflows/claude-pr-review.yml` in this repo, called as a
[reusable workflow](https://docs.github.com/en/actions/using-workflows/reusing-workflows).
Each project only needs the ~15-line caller file below. Fixing or improving
the review protocol means editing it once here — every project's next PR
picks it up automatically, no per-project sync.

## Setup (per project, one time)

1. Copy `pr-review.yml` from this folder into `<project>/.github/workflows/pr-review.yml`
   unmodified.
2. Add the `ANTHROPIC_API_KEY` secret to the project repo (Settings → Secrets
   and variables → Actions). If you'd rather set it once for every repo, add
   it as an **organization**-level secret instead (or, for personal repos,
   there's no shared "all my repos" scope — you still set it per repo).
3. If you want pings to go to someone other than `tinomupezeni`, change the
   `ping_username:` input in the copied `pr-review.yml`.
4. Open a PR and confirm the check runs. First run: double-check the
   `with:` keys in `claude-pr-review.yml` against the current
   [anthropics/claude-code-action](https://github.com/anthropics/claude-code-action)
   README — action input names shift across major versions and this template
   was written against a point-in-time understanding of its interface, not
   verified live.

## What "ping" means here

A GitHub `@username` mention in a PR comment triggers a normal GitHub
notification (and email, if the user's notification settings send PR mentions
to email) — no Slack/email integration needed. This only fires on the stop
condition in `review-prompt.md`; routine findings are posted without a
mention so they don't page you for every ordinary bug.

## Files

| File | Purpose |
|---|---|
| `pr-review.yml` | Copy this into each project's `.github/workflows/` |
| `review-prompt.md` | The actual review protocol/prompt — fetched at run time from this repo's `main` branch, not copied per project |
| (shared logic) | `../../.github/workflows/claude-pr-review.yml` — the reusable workflow itself |

## Changing the review protocol

Edit `review-prompt.md` (and/or the taxonomy/decision-tree source,
`Principal_Engineer/engineering-guides/24. Code Review.md`, if the standard
itself changed) and push to `main`. Every project's next PR run fetches the
updated prompt — no action needed in any project repo. If you need a project
to pin an older version while you roll out a prompt change, add a `ref:`
input to its `pr-review.yml` call (a tag or commit SHA in this repo) — it
defaults to `main` when omitted.
