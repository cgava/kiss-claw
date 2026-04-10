"""test_hello_world.py — Smoke test: invoke Claude and verify hello world response.

Validates that the Claude CLI can be invoked with a simple prompt,
returns valid JSON output, and responds with expected content.
"""

import os
import re
import sys

# Ensure project root is on sys.path so "tests.lib" is importable
# when the runner loads this file via importlib.
_project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if _project_root not in sys.path:
    sys.path.insert(0, _project_root)

from tests.lib.assertions import (
    assert_exit_code,
    assert_json_field,
    assert_stdout_contains,
)
from tests.lib.claude_cli import invoke


def run(ctx):
    """Execute the hello-world smoke test.

    Args:
        ctx: dict with keys 'scenario_dir' and 'workspace'.

    Raises:
        AssertionError: If any acceptance criterion fails.
    """
    # --- Invoke Claude with a deterministic prompt ---
    result = invoke(
        "Say exactly: hello world",
        max_turns=1,
        output_format="json",
        model="haiku",
    )

    # --- ERR-1 / ERR-2: Handle special exit codes before other checks ---
    if result.exit_code == -1:
        raise AssertionError("timeout: claude invocation timed out")
    if result.exit_code == -2:
        raise AssertionError("not found: claude binary not found in PATH")

    # --- AC checks wrapped in try/finally so log is written on both
    #     success and failure (LOG-1/LOG-2/LOG-3). ---
    error_msg = None
    try:
        # --- AC-1: Exit code is 0 ---
        assert_exit_code(result, 0)

        # --- AC-2: stdout is non-empty ---
        assert len(result.stdout.strip()) > 0, (
            "AC-2 failed: result.stdout is empty"
        )

        # --- AC-3: JSON parsed and contains "result" key ---
        assert result.json is not None, (
            "AC-3 failed: result.json is None (stdout could not be parsed as JSON)"
        )
        assert "result" in result.json, (
            f"AC-3 failed: 'result' key not in JSON response. "
            f"Keys: {sorted(result.json.keys())}"
        )

        # --- AC-4: is_error is False ---
        assert_json_field(result, "is_error", False)

        # --- AC-5: Response contains "hello" (case-insensitive) ---
        response_text = result.json.get("result", "")
        assert re.search(r"(?i)hello", response_text), (
            f"AC-5 failed: response does not contain 'hello' (case-insensitive). "
            f"Response: {response_text[:200]!r}"
        )

        # --- AC-6: session_id is a non-empty string ---
        session_id = result.json.get("session_id")
        assert isinstance(session_id, str), (
            f"AC-6 failed: session_id is {type(session_id).__name__}, expected str"
        )
        assert len(session_id) > 0, (
            "AC-6 failed: session_id is an empty string"
        )
    except AssertionError as exc:
        error_msg = str(exc)
        raise
    finally:
        status = "FAIL" if error_msg else "PASS"
        _write_log(ctx, result, status, error_msg=error_msg)


def _write_log(ctx, result, status, *, error_msg=None):
    """Write a summary log file to the workspace directory.

    Wrapped to satisfy LOG-3: log writing must not cause the test to fail.
    """
    try:
        log_dir = os.path.join(
            ctx.get("workspace", ctx.get("scenario_dir", ".")),
            "tests",
            "scenarios",
        )
        os.makedirs(log_dir, exist_ok=True)
        log_path = os.path.join(log_dir, "hello_world_result.log")
        preview = result.stdout[:200] if result.stdout else "(empty)"
        lines = [
            f"test: test_hello_world",
            f"status: {status}",
            f"exit_code: {result.exit_code}",
            f"response_preview: {preview}",
        ]
        if error_msg:
            lines.append(f"error: {error_msg}")
        with open(log_path, "w") as f:
            f.write("\n".join(lines) + "\n")
    except OSError:
        pass  # LOG-3: log failure must not break the test
