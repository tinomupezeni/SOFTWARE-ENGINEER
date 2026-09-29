# GUIDE TEMPLATE — Engineering Guide

> Copy this file to `NN. Guide Name.md` when creating a new guide. The `## Metadata`
> block is MANDATORY — it is what makes the guide rewirable (see MANIFEST.md). Do not
> remove it. Keep front-matter minimal and machine-readable; put all prose below it.

## Metadata

```yaml
id: NN
title: Guide Name
scope: >-
  One or two sentences: what domain this guide covers and the engineering
  problem it solves.
stack:
  - postgres
  - docker
  - fastapi
  # list the stacks/tech this guide assumes or is written for
triggers:
  - "Project uses a relational database"
  - "Project deploys to a self-managed VPS"
  # the conditions under which this guide should be applied to a project
applies_to:
  - project: TESE-MARKET (BFF)
    fit: high
    notes: why it fits
  # keep this list synced with MANIFEST.md
rewire_notes: >-
  Optional: stack-specific caveats when porting this guide into a project
  (e.g. "guide assumes Caddy; project uses Traefik — adapt proxy section").
```

---

## 1. Section

Write content here. Lead with the conclusion, use tables for reference data,
code blocks for copy-paste commands, diagrams (Mermaid or ASCII) for 3+ interacting
components.

### 1.1 Subsection

- Front-load the takeaway.
- No filler, no hype language.
- Document *why* and invariants, not current line numbers that will drift.

---

## Checklist (copy into project's docs when applying)

- [ ] Item the project must satisfy to comply with this guide
- [ ] Another item
