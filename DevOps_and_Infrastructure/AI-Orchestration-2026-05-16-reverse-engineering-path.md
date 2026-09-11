# The Reverse Engineering Learning Path

**Concept:** Instead of learning a language (like Rust) from a book, learn it by auditing and challenging a functional system built by an AI.

## The Strategy
When an AI generates a complex system, your job as the Architect is to "stress test" its logic through inquiry.

### 1. Security Auditing (The "Malicious Actor" Lens)
Ask the AI to identify vulnerabilities in its own code.
- **Example:** "Show me where we handle the Docker Socket connection. How are we ensuring a malicious container can't take over the host?"

### 2. Concurrency & Performance (The "Mechanical" Lens)
Understand the low-level primitives the AI chose and why.
- **Example:** "Explain how we are using `Tokio`. Are we using `select!` or `join!` for the build tasks? Why is one better for this?"

### 3. Failure Injection (The "Resilience" Lens)
Force the AI to handle the "worst-case" scenario.
- **Example:** "Write a failure-injection test. What happens if the VPS runs out of disk space in the middle of a build?"

## Implementation for Shipwright
- **Target:** Rust Agent logic.
- **Goal:** Build a "System Intuition" for memory safety and async execution without being the primary author of the syntax.
