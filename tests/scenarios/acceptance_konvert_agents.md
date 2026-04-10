# Acceptance Criteria: Konvert Agent Integration Test

> Written by kiss-verificator (TDD — criteria first, implementation second).
> Target file: `tests/scenarios/test_konvert_agents.py`

---

## Structure

- **ST-1**: File exists at `tests/scenarios/test_konvert_agents.py`.
- **ST-2**: File defines a `run(ctx)` function accepting one positional argument.
- **ST-3**: File imports `invoke` from `tests.lib.claude_cli`.
- **ST-4**: File imports assertion helpers from `tests.lib.assertions` (at minimum: `assert_exit_code`, `assert_file_exists`, `assert_file_contains`).
- **ST-5**: No external dependencies (stdlib + tests.lib only).

## Setup

- **SET-1**: Creates an isolated temporary workspace directory via `tempfile.mkdtemp()`. This directory is NOT inside the kiss-claw repo.
- **SET-2**: The temporary workspace is used as `cwd` for the `invoke()` call so all agent-generated files land there.
- **SET-3**: Cleanup strategy: delete workspace on success (all AC pass), preserve on failure for post-mortem inspection. The preserved workspace path must appear in the log (see LOG-5). The test must not silently leak temp dirs on success.

## Invocation

- **INV-1**: The prompt sent to `invoke()` is the full konvert directive (all 6 phases, in French as specified in the task).
- **INV-2**: Passes `output_format="json"`.
- **INV-3**: Passes `model="sonnet"` (agents need reasoning capacity beyond haiku).
- **INV-4**: Passes `max_turns=50` or higher (full agent loop: orchestrator planning, executor implementing multiple phases, verificator reviewing, improver analyzing — each involves multiple turns).
- **INV-5**: Passes `max_budget_usd` with a cap between 2.0 and 5.0 (prevents runaway cost).
- **INV-6**: Passes `timeout` between 600 and 900 seconds (10-15 minutes for multi-phase agent work).
- **INV-7**: Loads kiss-claw as a plugin. The test must pass `extra_flags=["--plugin-dir", "<kiss-claw-repo-root>"]` where the repo root is derived from `ctx["workspace"]` or from the test file's own location. This is how the orchestrator/executor/verificator/improver agents become available.
- **INV-8**: The system prompt or the user prompt itself must trigger kiss-orchestrator activation. Acceptable approaches: (a) prefix prompt with `/kiss-orchestrator` command invocation; (b) include explicit instruction like "Use kiss-orchestrator to plan and coordinate this work"; (c) rely on the agent-suggest hook to offer routing. The test must document which approach was chosen and why.
- **INV-9**: Passes `cwd` set to the temporary workspace directory from SET-1.

## Validations (must-pass)

Each validation must use assertion helpers from `tests.lib.assertions` or plain `assert` with a descriptive message. Failures must raise `AssertionError`.

| ID   | Criterion | How to verify |
|------|-----------|---------------|
| AC-1 | Exit code is 0 | `assert_exit_code(result, 0)` |
| AC-2 | JSON response is parseable | `assert result.json is not None` with descriptive message |
| AC-3 | `.kiss-claw/PLAN.md` exists in workspace and contains phase-related content | `assert_file_exists(ws / ".kiss-claw/PLAN.md")` then `assert_file_contains(path, r"(?i)(phase|etape)")` |
| AC-4 | `.kiss-claw/STATE.md` exists in workspace | `assert_file_exists(ws / ".kiss-claw/STATE.md")` |
| AC-5 | `konvert.sh` exists in workspace and is executable | `assert_file_exists(ws / "konvert.sh")` then check executable bit via `os.access(path, os.X_OK)` |
| AC-6 | `test_konvert.sh` exists in workspace and is executable | `assert_file_exists(ws / "test_konvert.sh")` then check executable bit via `os.access(path, os.X_OK)` |
| AC-7 | `.kiss-claw/REVIEWS.md` exists in workspace (proves kiss-verificator ran) | `assert_file_exists(ws / ".kiss-claw/REVIEWS.md")` |
| AC-8 | `.kiss-claw/INSIGHTS.md` exists in workspace (soft — improver may not run) | Check with `os.path.exists()`. If missing, log a note but do NOT fail the test. This is a soft criterion only. |

## Logging

- **LOG-1**: Test writes a log file to `ctx["workspace"]` (e.g., `tests/scenarios/konvert_agents_result.log` or similar path under workspace).
- **LOG-2**: Log file contains: test name, pass/fail status, exit code, duration in seconds, cost (from `result.json` if available — look for `"cost_usd"` or similar field), session_id (from `result.json`), and the workspace path used.
- **LOG-3**: Log writing must not cause the test to fail — wrap in try/except if needed (same pattern as hello-world test).
- **LOG-4**: Log must contain one line per criterion (AC-1 through AC-8) with the individual result: `AC-<N>: PASS — <description>` or `AC-<N>: FAIL — <description> — <error message>`. This is the verifiable evidence that each criterion was evaluated.
- **LOG-5**: On any AC FAIL, the workspace path must be printed to the log with an explicit message: `WORKSPACE PRESERVED FOR INSPECTION: <path>`. This enables post-mortem analysis of agent outputs.

## Error Handling

- **ERR-1**: If `invoke()` returns `exit_code == -1` (timeout), the test must raise `AssertionError` with a message mentioning "timeout" and including the timeout value used. Must not crash with unhandled exception.
- **ERR-2**: If `invoke()` returns `exit_code == -2` (claude binary not found), the test must raise `AssertionError` with a message mentioning "not found".
- **ERR-3**: If `max_budget_usd` is exceeded (indicated by non-zero exit code or specific error in stderr/JSON), the test should raise `AssertionError` with a message mentioning "budget exceeded" rather than producing a confusing generic failure.
- **ERR-4**: No bare `except:` clauses. Only catch specific exceptions (OSError, AssertionError, etc.).

## Non-Requirements

- **NR-1**: Do NOT verify that `konvert.sh` actually converts Markdown correctly. That is the agent's job to implement and test — this integration test only verifies the agent loop produced the expected artifacts.
- **NR-2**: Do NOT verify exact `PLAN.md` content beyond confirming it exists and mentions phases/steps.
- **NR-3**: Do NOT run `test_konvert.sh`. Only verify the file exists and is executable.
- **NR-4**: Do NOT verify `REVIEWS.md` content beyond existence. The review format is kiss-verificator's concern.
- **NR-5**: Do NOT verify `INSIGHTS.md` content. Its existence is a soft signal only (AC-8).
- **NR-6**: Do NOT attempt to verify which specific agents ran or in what order. The artifact checks (PLAN.md, REVIEWS.md) serve as indirect evidence.

---

## Verdict Mapping

When kiss-verificator reviews the implemented test, the verdict will be:

- **approved** — all ST, SET, INV, AC, LOG, ERR, NR criteria met.
- **approved-with-notes** — all AC criteria met (AC-8 soft is exempt); minor deviations in LOG, SET cleanup strategy, or INV-8 approach choice.
- **needs-rework** — any AC-1 through AC-7 criterion not testable, any ERR criterion violated, missing plugin-dir flag (INV-7), imports outside tests.lib + stdlib, or workspace not isolated (SET-1).
