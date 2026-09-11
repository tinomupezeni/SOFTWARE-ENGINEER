# Development Issues & Solutions Log

A centralized repository for tracking production issues, bugs, and their solutions across all projects.

## Purpose
- Document critical issues and their resolutions
- Build a knowledge base for future debugging
- Track patterns and recurring problems
- Share learnings across projects

## Structure

```
dev-logs/
├── [PROJECT_NAME]/
│   ├── README.md                    # Project-specific issue index
│   └── YYYY-MM-DD-issue-name.md     # Individual issue logs
└── templates/
    └── issue-template.md            # Template for new issues
```

## Projects Tracked

- [Shipwright](./shipwright/) - DevOps deployment automation tool
- [CRM Professional](./CRM/)
- [SMEPULSE](./SMEPULSE/) (coming soon)
- [HBEC](./HBEC/) (coming soon)
- [Market-Link](./Market-Link/)
- [chemglee-concept-site](./chemglee-concept-site/)

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
# Auto-detect project from current directory
cd C:\Users\Dell\Documents\projects\CRM\crm
C:\Users\Dell\Documents\projects\dev-logs\log-issue.ps1 -Title "backend-crash" -Severity Critical

# Or specify project explicitly
C:\Users\Dell\Documents\projects\dev-logs\log-issue.ps1 -Project CRM -Title "nginx-down" -Severity High
```

### Manual (Traditional)
1. Copy template: `templates/issue-template.md`
2. Name it: `[PROJECT]/YYYY-MM-DD-brief-description.md`
3. Fill in all sections
4. Commit and push

## Quick Links

- [Issue Template](./templates/issue-template.md)
- [Recent Issues](./CRM/)

---

**Last Updated:** 2026-05-17
