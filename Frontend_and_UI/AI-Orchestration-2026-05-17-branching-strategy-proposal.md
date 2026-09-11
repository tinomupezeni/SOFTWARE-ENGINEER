# Proposing the CRM Branching Strategy

**Objective:** Define the Git workflow for Winston (Implementer) and Tino (Reviewer) to maximize velocity while maintaining architectural integrity.

---

## Option 1: Trunk-Based Development (Direct Push to Main)
*Everything is pushed directly to the `main` branch once verified.*

### ✅ Pros:
- **Maximum Velocity**: Zero latency waiting for PR reviews.
- **Continuous Integration**: AI agents can pull the absolute latest code immediately.
- **Simplicity**: No complex merging or branch management.

### ❌ Cons:
- **High Risk**: A single "LLM Hallucination" that slips through verification can break the production build for everyone.
- **Passive Oversight**: Tino only discovers errors *after* they are in the codebase.

---

## Option 2: Feature Branching (The PR Model)
*Winston pushes to `feature/CRM-XXX` and creates a Pull Request for Tino to review.*

### ✅ Pros:
- **Total Oversight**: Tino must manually approve every line before it enters `main`.
- **Safety Gate**: Allows for automated CI (GitHub Actions) to run the Verification Loop on the branch first.
- **Clean History**: `main` remains a stable record of "Verified Wins."

### ❌ Cons:
- **Review Latency**: Work stops if Tino is busy.
- **Merge Hell**: In high-velocity teams, branches can drift quickly, leading to complex merge conflicts.

---

## 🚀 The Recommendation: The "Blueprint-Gated" Hybrid

Since Winston is using an LLM, we should prioritize **Automation** over **Manual Review**, but maintain a **Gate**.

### The Proposed Workflow:
1. **Develop**: Winston works on a branch: `winston/CRM-001`.
2. **Auto-Verify**: Winston's LLM must run the **Verification Loop Protocol**.
3. **Draft PR**: Winston opens a PR. 
4. **The Gate**:
   - If **Verification Report** is attached and **100% PASS**: Tino performs a "Snap Review" (Check the analytics/metadata) and clicks Merge.
   - If **ANY FAIL**: The PR is automatically blocked.

### Why this works:
It uses the **Blueprint** as the judge. Tino doesn't have to read every line of code—he just checks if the **Blueprint Mandate** was followed and the **Verification Loop** passed.

---
**Decision Needed:** Tino, do you prefer the **Velocity** of Trunk-Based (Direct Push) or the **Safety** of the PR Model?
