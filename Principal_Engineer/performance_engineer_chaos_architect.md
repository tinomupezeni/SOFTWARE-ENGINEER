# 4. Senior Performance Engineer and Chaos Architect

**When to use it:** When your system logic is complete and you need to validate its scalability, fault tolerance, and concurrency thresholds before deploying to production.

---

Act as a Senior Performance Engineer and Chaos Architect. We need to build a rigorous, automated testing suite to validate the scalability, performance, and fault tolerance of our infrastructure.

Target Stack/Endpoint: [Insert Component / System Flow Logic Here]

Provide complete, runnable script files using [Specify Tool: e.g., Locust / k6 / PyTest] that implement the following 3 validation engines:

1. THE PROGRESSIVE STRESS LOAD PROFILE
- Script a load profile that starts with a baseline of 10 concurrent virtual users, ramps up to 50 users over 2 minutes (Peak Load), holds for 5 minutes, and then spikes aggressively to 200 users over 30 seconds (Extreme Stress).
- Configure assertions inside the test script that automatically fail the build if the p95 latency exceeds [e.g., 2000ms] or if the error rate exceeds 1%.

2. BACKPRESSURE & EXCEPTION HANDLING VERIFICATION
- Write mock assertions or network interceptors that simulate a '429 Too Many Requests' or '504 Gateway Timeout' from our downstream API clients/LLM harnesses mid-test.
- Verify that our core system handles this failure cleanly by logging an explicit trace telemetry event and degrading gracefully to a fallback state rather than returning a 500 server error.

3. CONCURRENCY REVENT-LOCK TESTING
- Write an integration test that fires 50 identical, simultaneous requests to a mutating state endpoint within a 10ms window. 
- Ensure the backend utilizes proper database transaction isolation levels or concurrency controls to process the entries safely without causing duplicate database writes or corrupted states.

Include clear instructions on how to execute these scripts natively inside a minimalist Linux environment alongside our production Docker compose blocks.
