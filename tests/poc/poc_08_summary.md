# POC Summary: Claude CLI Subprocess Feasibility

> Date: 2026-04-10
> CLI Version: 2.1.90 (Claude Code)
> Auth: OAuth (no API key)
> All tests run with `--model haiku --effort low` to minimize cost

---

## Results

| POC | What was tested | Result | Notes |
|-----|----------------|--------|-------|
| 01 | Basic `subprocess.run(["claude", "-p", ...])` | PASS | stdout captured cleanly, text output works |
| 02 | `--output-format json` parsing | PASS | All required fields present: `result`, `is_error`, `session_id`, `total_cost_usd`, plus `usage`, `modelUsage`, `duration_ms`, etc. |
| 03 | Control flags: `--system-prompt`, `--max-turns`, `--model`, `--effort` | PASS | All 4 flags work as documented. `--system-prompt` produces deterministic output. `--max-turns 1` respected. `modelUsage` confirms haiku model. |
| 04 | Tool restriction: `--tools ""`, `--disallowedTools`, `--allowedTools` | PASS | All 3 mechanisms work. `--tools ""` disables all tools. `--disallowedTools Bash` accepted. `--allowedTools Read` accepted. |
| 05 | Error handling: timeout + budget exceeded | PASS | `subprocess.TimeoutExpired` caught correctly. `--max-budget-usd 0.001` returns `is_error: true`, `subtype: "error_max_budget_usd"`. |
| 06 | Config override: clean session | PASS | `--mcp-config '{"mcpServers":{}}'` works. `--settings` with JSON accepted. Combined clean session (no tools, no MCP, restrictive settings) works. |
| 07 | Session continuation via `--resume` | PASS | `session_id` extracted from JSON, `--resume <id>` resumes correctly. Model retains context across turns. Session ID preserved. |

**Overall: 7/7 PASS**

---

## What Works Reliably

1. **subprocess.run() is the right pattern.** Synchronous, zero dependencies, clean stdout capture. No need for the SDK.

2. **JSON output is self-contained.** A single `json.loads(result.stdout)` gives everything: result text, error status, cost, tokens, session ID, model used.

3. **System prompt override enables deterministic testing.** `--system-prompt "Reply with exactly: X"` produces predictable output for assertion-based tests.

4. **Tool restriction works three ways:**
   - `--tools ""` — disable all tools entirely
   - `--allowedTools "Read"` — whitelist specific tools
   - `--disallowedTools "Bash"` — blacklist specific tools

5. **Budget control works for error-path testing.** `--max-budget-usd 0.001` reliably triggers budget-exceeded error with structured JSON error info.

6. **Session continuation via subprocess is viable.** Extract `session_id` from JSON, pass to `--resume <id>` on next call. Multi-turn conversations work without the SDK.

7. **Config isolation is achievable.** Combining `--mcp-config`, `--settings`, and `--tools ""` creates a clean session with no extensions interfering.

---

## Corrections to Phase 1 Research

1. **Exit codes ARE informative for budget errors.** Phase 1 noted "exit code is still 0" for budget exceeded, but actual testing shows `returncode: 1`. JSON `is_error` field remains the authoritative source, but exit code is usable as a first check.

2. **POC 04 initially had CLAUDE.md content leaking into responses.** Tests 1-2 in the first version did not use `--system-prompt`, so the model's replies were influenced by project CLAUDE.md instructions rather than being deterministic. This was fixed in the final version by adding `--system-prompt` to all tests, ensuring clean and predictable output.

---

## What We Can Rely On for the Framework

### Core test invocation pattern (validated):
```python
result = subprocess.run(
    ["claude", "-p",
     "--output-format", "json",
     "--model", "haiku",
     "--effort", "low",
     "--no-session-persistence",
     "--dangerously-skip-permissions",
     "--system-prompt", "...",
     "prompt here"],
    capture_output=True, text=True, timeout=60,
)
data = json.loads(result.stdout)
assert not data["is_error"]
assert "expected" in data["result"]
```

### Available assertion targets in JSON response:
- `data["result"]` — the model's text response
- `data["is_error"]` — boolean error flag
- `data["subtype"]` — error type (e.g., `"error_max_budget_usd"`)
- `data["session_id"]` — for multi-turn tests
- `data["total_cost_usd"]` — for cost tracking/budgeting
- `data["num_turns"]` — verify turn limits
- `data["modelUsage"]` — verify which model was used
- `data["duration_ms"]` — for performance assertions

### Cost per test (observed with haiku + effort low):
- Simple prompt: ~$0.04-0.06 per call
- With system prompt override: same range
- Budget-exceeded test: charged for the attempt (~$0.05) then stops

### Recommended base flags for all tests:
- `--model haiku --effort low` — cheapest invocation
- `--no-session-persistence` — no disk pollution (except POC 07 multi-turn)
- `--dangerously-skip-permissions` — no interactive prompts
- `--output-format json` — structured output for assertions
- `--system-prompt "..."` — deterministic responses where needed
- `--max-turns 1` — prevent runaway tool loops

---

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Every test hits real API (no mock mode) | Use `--system-prompt` for determinism, `--max-budget-usd` as safety net |
| Cost accumulation across test suite | Track `total_cost_usd` per test, set per-run budget caps |
| Flaky responses (LLM non-determinism) | Use strict system prompts, assert on contains/patterns not exact match |
| CLI version changes breaking flags | Pin CLI version in CI, test flag availability at suite startup |
| OAuth token expiry in CI | Document token refresh procedure; always use OAuth-based `claude` CLI (never `--bare` + API key) |
