# Development Issues & Solutions Log

A centralized repository for tracking production issues, bugs, and their
solutions across all projects — and, separately, reports on completed
engineering initiatives and decisions that weren't a bug but are still
worth a future reader knowing about.

## Purpose
- Document critical issues and their resolutions
- Record engineering initiatives, audits, and decisions — even ones that
  found no bug — so the reasoning behind them isn't lost
- Build a knowledge base for future debugging
- Track patterns and recurring problems
- Share learnings across projects

## Structure

```
dev-logs/
├── Architecture_and_Design/
├── Backend_and_API/
├── Database_and_State/
├── DevOps_and_Infrastructure/
├── Frontend_and_UI/
├── Integrations_and_Auth/
├── Mobile_Apps/
├── reports/
└── templates/
    ├── issue-template.md             # Template for bugs/misconfigurations
    └── report-template.md            # Template for engineering reports
```
*(Bug/issue logs are stored in the technical-area directories above and
named `[PROJECT]-YYYY-MM-DD-issue-name.md`. Reports live flat in `reports/`,
same naming convention, since a report usually spans more than one
technical area.)*

### Bug/issue logs vs. reports
- **Bug/issue log** (technical-area folders): a specific bug, misconfiguration,
  design flaw, or root-cause finding — something concrete that was broken.
- **Report** (`reports/`): a completed engineering initiative or decision —
  an audit, a refactor, a cleanup pass, an architecture choice — logged even
  when nothing was broken, because the scope, method, and reasoning behind
  the work are worth keeping. A bug found *during* a report's work still
  gets its own bug-log entry; the report cross-references it rather than
  duplicating it.

## Projects Tracked

- [Shipwright](./shipwright/) - DevOps deployment automation tool
- CRM Professional
- SMEPULSE
- HBEC
- Market-Link
- chemglee-concept-site

## How to Use

### Automatic (Recommended)
Claude Code and Gemini CLI are configured to automatically create issue logs when debugging production problems. Just work normally - they'll create logs for:
- Production outages
- Deployment failures
- Container/Docker issues
- SSH debugging sessions
- Critical errors

### Manual Logging
Use the helper script for quick manual logging:

```powershell
# Auto-detect project from current directory and prompt for Category
cd C:\Users\Dell\Documents\projects\CRM\crm
C:\Users\Dell\Documents\projects\dev-logs\log-issue.ps1 -Title "backend-crash" -Severity Critical

# Or specify project and category explicitly
C:\Users\Dell\Documents\projects\dev-logs\log-issue.ps1 -Project CRM -Title "nginx-down" -Severity High -Category DevOps_and_Infrastructure
```

### Manual (Traditional)
**Bug/issue:**
1. Copy template: `templates/issue-template.md`
2. Name it: `[TECHNICAL_CATEGORY]/[PROJECT]-YYYY-MM-DD-brief-description.md`
3. Fill in all sections
4. Commit and push

**Report:**
1. Copy template: `templates/report-template.md`
2. Name it: `reports/[PROJECT]-YYYY-MM-DD-brief-description.md`
3. Fill in all sections
4. Commit and push

## Quick Links

- [Issue Template](./templates/issue-template.md)
- [Report Template](./templates/report-template.md)
- [Reports](./reports/)
- [Recent Backend Logs](./Backend_and_API/)
- [Recent DevOps Logs](./DevOps_and_Infrastructure/)

---

**Last Updated:** 2026-05-17
