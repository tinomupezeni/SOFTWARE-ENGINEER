# Student paper generation truncated mid-JSON: flat 4096-token budget was never actually sufficient

**Date:** 2026-10-13
**Project:** HBEC Platform
**Environment:** Production (`hbca-vps`)
**Severity:** Medium (real student-facing failure, but a retryable one; no data loss)
**Status:** Resolved

## Summary
A student's AI-generated practice paper request failed with "The AI response
was not valid JSON." The LLM call itself succeeded (through the paid
`google/gemini-flash` pool, not the GPU), but its response was cut off at
exactly the configured 4096-token output ceiling. The student path had never
actually adopted the scaled token budget that was already built and applied
to the admin path for the same root cause.

## Symptoms
- A 10-question Animal Science paper generation job failed.
- Harness logs: `paper_generation_failed`, `ValueError: The AI response was
  not valid JSON`, raised from `_extract_json()` in `paper_generator.py`.
- Not visible in the HTTP error tracker — this is an async generation-job
  failure, not a 4xx/5xx response, so it only showed up by reading
  `hbec-harness-blue`'s own logs directly.

## Environment Details
- **Server/Host:** hbca-vps, `hbec-harness-blue`
- **Services Affected:** `AGENTIC_HARNESS` (`app/exam_practice/services/paper_generator.py`)
- **Related Components:** `google/gemini-flash` litellm pool (paid, correct — not the GPU)
- **Time First Observed:** 2026-10-13T13:32:04Z

## Investigation Steps

### 1. Initial Diagnosis
User reported "AI generated an invalid response" on student-side paper
generation, explicitly noting students use the paid model path, not the free
GPU (ruling out the already-known, separate GPU-tunnel outage).

### 2. Root Cause Analysis
```bash
ssh hbca-vps "sudo docker logs hbec-harness-blue --since 2h 2>&1 | grep -iE 'invalid.*response|generation_failed'"
```
Found the full traceback: `_extract_json()` raised `ValueError("The AI
response was not valid JSON")` after `json.loads()` failed on a response that
had been cut off mid-structure. The preceding `llm_call_success` log line
showed `output_tokens: 4096` — exactly the configured ceiling, not a
coincidence.

### 3. Key Findings
- `paper_generator.py` already had a per-question scaled budget,
  `admin_max_tokens = min(16000, 1200 + count * {mcq:200, mixed:380,
  structured:550}.get(question_type, 380))`, built specifically because the
  same truncation bug had already hit *admin* bulk generation once
  `question_count` could go up to 50.
- The call site used `max_tokens=admin_max_tokens if is_admin else 4096` — a
  flat 4096 for every student request, on the theory (stated in a code
  comment) that capping student `count` at 10 made a fixed budget
  "already-sufficient."
- That assumption was simply wrong by the project's own later calibration:
  10 "mixed" questions need `1200 + 10*380 = 5000` tokens, and 10
  "structured" need `6700` — both already over 4096. The flat budget had
  never actually been safe; it was just rarely exercised near the cap.

## Root Cause
The student path's token budget was never updated when the admin path's
truncation bug was fixed with a scaled formula — the fix addressed admin
specifically and the student path kept its original flat ceiling under an
incorrect "already sufficient" assumption that was never re-verified against
the scaling formula introduced right next to it.

## Prevention / Rule
**Guardrail:** the scaled budget computation (`generation_max_tokens`, after
this fix) is now unconditional — there is no second, divergent ceiling for
any caller to drift back to. Any future caller of `_call_generator_llm` gets
the same scaling by construction; there is nothing left to forget to apply.

The regression test (`test_student_path_truncation_bug_is_fixed`) pins the
exact live-failure shape (`count=10, question_type="structured"`) to a
budget `> 4096`, so a future change that reintroduces a smaller hard-coded
ceiling on either path fails this test immediately.

## Solution

### Immediate Fix
None needed beyond the code fix — the failure is a retryable job failure
(the student can re-request generation), no stuck state, no data loss.

### Long-term Fix
`AGENTIC_HARNESS/app/exam_practice/services/paper_generator.py`: removed the
student-specific flat 4096 branch; both admin and student paths now use the
same scaled formula (renamed `admin_max_tokens` → `generation_max_tokens`
since it's no longer admin-only). `num_ctx` (Ollama-specific) remains
admin/GPU-only, unaffected.

Deployed to the idle (`green`) blue-green color on `hbca-vps`, verified
(revisions, signed links, secret drift all pass) — not yet cut over to live
traffic as of this writing; that's a separate, deliberate step.

## Prevention
- [x] Code changed: scaled budget applied unconditionally
- [x] Regression tests added, pinned to the exact live-failure parameters
- [ ] Monitoring/alerts: `paper_generation_failed` events aren't currently
      wired into the HTTP error tracker (they're async job failures); a
      Grafana panel or alert on this specific `structlog` event would catch
      the next instance of this class faster than reading logs by hand.

## Related Issues
- `HBEC-2026-10-12-gpu-tunnel-down-paper-generation-gpu-unavailable.md` (if
  logged separately) — a different, unrelated root cause on the *admin*
  free-GPU path, found the same day; do not conflate the two.

## References
- `AGENTIC_HARNESS/app/exam_practice/services/paper_generator.py`
  (`_call_generator_llm`, `_extract_json`)
- `AGENTIC_HARNESS/tests/exam_practice/test_paper_generator.py`
- HBEC PR #97

---

**Resolved By:** Tinotenda Mupezeni
**Time to Resolution:** ~40 minutes (investigation to deployed fix)
