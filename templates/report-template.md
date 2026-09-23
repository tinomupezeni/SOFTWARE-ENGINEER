# [Title]

**Date:** YYYY-MM-DD
**Project:** [Name]
**Type:** [Audit / Refactor / Cleanup / Architecture Decision / Scope Decision / ...]
**Status:** [Completed / In Progress / Superseded]

## Summary
One paragraph: what was done and why it mattered.

## Context / Trigger
What prompted this — a user request, a suspicion, a scheduled review, a bug
that turned out to need broader investigation.

## Scope
What was included. What was explicitly excluded and why (so a later reader
doesn't wonder if X was overlooked vs. deliberately skipped).

## Method
How the work was approached — the actual methodology, especially if it's
reusable (e.g. "verify cross-service + DB-level dependency before removing
anything flagged unused").

## Decisions & Findings
The substance — what was found, what was decided, and the reasoning. This
is the section that varies most by report; a cleanup lists what was removed
and why each was safe, an architecture decision lists the options weighed
and why one won.

## Changes Made
Concrete: files/commits, what actually shipped.

## Verification
Tests run, staging checks, anything that confirms the decision held up.

## Follow-ups / Deferred
Things deliberately left for later, and why.

## References
Related bug-log entries, related reports, key files.

---

**Completed By:** [Name]
**Duration:** [...]
