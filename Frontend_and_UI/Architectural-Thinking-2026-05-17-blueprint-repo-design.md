# Blueprint: The Engineering Source of Truth

**Concept:** A centralized, LLM-optimized repository containing the architectural DNA, task directives, and verification protocols for all projects.

## Repository Structure

```text
blueprint/
├── standards/           # Immutable Engineering Standards
│   ├── deployment.md    # Vite Build Args, Nginx Reload, Registry Rules
│   ├── api-chassis.md   # Zero-Zombie API, Deep Health Check Specs
│   ├── identity.md      # UUID vs Name, Distributed Auth Rules
│   └── frontend.md      # HCI Standards, Optimistic UI, Asset Loading
├── directives/          # Active Task Definitions (LLM-Ready)
│   ├── active/          # Currently assigned tasks
│   └── completed/       # Historical directives (reference)
├── verification/        # Global Verification Protocols
│   ├── scripts/         # Standard check scripts (e.g., verify-deployment.ps1)
│   └── patterns.md      # "How to prove it" guide
└── README.md            # The "Prime Directive" and Repo Index
```

## The "Directive" Format (Optimized for LLMs)
Every file in `directives/active/` should follow this structure so an LLM (Claude/Gemini) can execute it with 100% accuracy:

1.  **Context**: Project name, environment, and relevant existing files.
2.  **Standards Reference**: Which files in `standards/` apply.
3.  **The Directive**: Concise, technical instruction (What, not How).
4.  **Verification**: The exact command/output required for completion.
5.  **Definition of Done**: Checklist for the "Other Guy" (and his LLM).

## How to use Blueprint
1.  **Draft**: You (or I) draft a new `.md` in `directives/active/`.
2.  **Commit**: Push to `blueprint` repo.
3.  **Delegate**: Send the link to the other engineer.
4.  **Execute**: He (and his LLM) pulls the file, follows the standard, and implements.
5.  **Verify**: He commits the `dev-logs` entry and the verification output.

---
**Guiding Principle:** "If it's not in the Blueprint, it doesn't exist. If it's in the Blueprint, it must be verified."
