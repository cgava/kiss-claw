# Acceptance Criteria: Hello-World Smoke Test

> Written by kiss-verificator (TDD — criteria first, implementation second).
> Target file: `tests/scenarios/test_hello_world.py`

---

## Structure

- **ST-1**: File exists at `tests/scenarios/test_hello_world.py`.
- **ST-2**: File defines a `run(ctx)` function accepting one positional argument.
- **ST-3**: File imports `invoke` from `tests.lib.claude_cli`.
- **ST-4**: File imports at least `assert_exit_code` from `tests.lib.assertions`.
- **ST-5**: No other external dependencies (stdlib + tests.lib only).

## Invocation

- **INV-1**: Calls `invoke()` with a deterministic prompt that instructs Claude to say "hello world" (e.g., `"Say exactly: hello world"`).
- **INV-2**: Passes `max_turns=1`.
- **INV-3**: Passes `output_format="json"`.
- **INV-4**: Passes `model="haiku"`.
- **INV-5**: Uses default or explicit `effort="low"` (the wrapper default is already "low", so omitting is acceptable).
- **INV-6**: Does NOT pass `resume_session`, `mcp_config`, `allowed_tools`, or `settings` — clean session only.

## Validations (must-pass)

Each validation must use the assertion helpers from `tests.lib.assertions` or plain `assert` with a descriptive message. Failures must raise `AssertionError` (the runner contract).

| ID   | Criterion | How to verify |
|------|-----------|---------------|
| AC-1 | Exit code is 0 | `assert_exit_code(result, 0)` |
| AC-2 | `result.stdout` is non-empty | `assert len(result.stdout.strip()) > 0` or equivalent, with message |
| AC-3 | `result.json` is not None and contains key `"result"` | `assert result.json is not None`; `assert "result" in result.json` |
| AC-4 | `result.json["is_error"]` is `False` | `assert_json_field(result, "is_error", False)` |
| AC-5 | Response content contains "hello" (case-insensitive) | `assert_stdout_contains(result, r"(?i)hello")` or check `result.json["result"]` with `re.search` |
| AC-6 | `result.json` contains `"session_id"` as a non-empty string | `assert isinstance(result.json.get("session_id"), str)` and `assert len(result.json["session_id"]) > 0` |

## Logging

- **LOG-1**: Test writes a summary log file to `ctx["workspace"]` (e.g., `tests/scenarios/hello_world_result.log` or similar path under workspace).
- **LOG-2**: Log file contains: test name, pass/fail status, exit code, and a preview of the response (first 200 chars of stdout).
- **LOG-3**: Log writing must not cause the test to fail — wrap in try/except if needed.

## Error Handling

- **ERR-1**: If `invoke()` returns `exit_code == -1` (timeout), the test must raise `AssertionError` with a message mentioning "timeout" — not crash with an unhandled exception.
- **ERR-2**: If `invoke()` returns `exit_code == -2` (claude binary not found), the test must raise `AssertionError` with a message mentioning "not found" — not crash.
- **ERR-3**: No bare `except:` clauses. Only catch specific exceptions.

## Non-Requirements

- **NR-1**: Claude must NOT be asked to write files or use tools.
- **NR-2**: No multi-turn conversation (max_turns=1 enforces this).
- **NR-3**: No MCP servers or custom settings.
- **NR-4**: No permission grants beyond `--dangerously-skip-permissions` (already in wrapper defaults).

---

## Verdict Mapping

When kiss-verificator reviews the implemented test, the verdict will be:

- **approved** — all ST, INV, AC, LOG, ERR, NR criteria met.
- **approved-with-notes** — all AC criteria met; minor deviations in LOG or style.
- **needs-rework** — any AC criterion not testable, any ERR criterion violated, or imports outside tests.lib + stdlib.
