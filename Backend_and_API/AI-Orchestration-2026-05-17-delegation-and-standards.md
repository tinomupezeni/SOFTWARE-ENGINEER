# The Engineering Delegation Framework

**Concept:** Shifting from "The Only Person Who Can Fix It" to "The Architect of the System."

## 1. The "Definition of Done" (DoD)
Success on any task in this workspace is not "it works on my machine." It is only "Done" when:
1. **Behavioral Proof**: A test case or curl command proves the fix works in the target environment.
2. **Structural Integrity**: No new bad patterns (copy-paste imports, shell escaping traps) are introduced.
3. **Observability**: The service reports its own health via `/health/deep`.
4. **Knowledge Persistence**: A log exists in `dev-logs` following the standard template.

## 2. The "3-Step Delegation" Workflow
When handing a task to the other engineer, provide these three things:

### A. The Directive (The "What")
*   **Bad**: "Fix the store-api crash."
*   **Good**: "Fix the NameError in `store-api/app/main.py`. Ensure `Depends` and `Session` are imported. Follow the Zero-Zombie template."

### B. The Verification Script (The "Prove It")
Provide the exact command they must run to prove they succeeded.
*   **Example**: `curl -f http://localhost:8001/api/v1/health/deep`

### C. The Standard Reference (The "How")
Point them to the `DEPLOYMENT-STANDARDS.md`. Tell them: "If your solution violates Section 2 (Critical Rules), it will be rejected."

## 3. The Oversight Loop
You (and I) are the **Reviewers**. Your job is no longer to type the code, but to:
1. **Approve the Plan**: Have them explain their approach before they touch a file.
2. **Verify the Log**: Read their `dev-logs` entry. If it doesn't explain the "Why," send it back.
3. **Audit the Chassis**: Periodically check if the new code follows the standardized microservice chassis.

## 4. Automation as the "Enforcer"
Delegate the "nagging" to the system:
*   **Shipwright**: Use it to enforce deployment gates. If the health check fails, the deployment is rejected automatically.
*   **Lints**: If the code doesn't pass `ruff` or `eslint`, it shouldn't even reach your desk.

---
**Guiding Principle:** "If you have to do it twice, write a standard. If you have to do it three times, write a script. If you want to delegate it, provide the verification."
