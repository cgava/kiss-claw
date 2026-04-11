"""test_hello_world.py — Smoke test: invoke Claude and verify hello world response.

Validates that the Claude CLI can be invoked with a simple prompt,
returns valid JSON output, and responds with expected content.
"""

import os
import re
import sys
import time

# Ensure project root is on sys.path so "tests.lib" is importable
# when the runner loads this file via importlib.
# Path: tests/scenarios/01-hello-world/test_hello_world.py -> project root is 3 levels up
_project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if _project_root not in sys.path:
    sys.path.insert(0, _project_root)

from tests.lib.assertions import (
    assert_exit_code,
    assert_json_field,
    assert_stdout_contains,
)
from tests.lib.claude_cli import invoke
from tests.lib.report import generate_report


def run(ctx):
    """Execute the hello-world smoke test.

    Args:
        ctx: dict with keys 'scenario_dir', 'workspace', and 'dry_run'.

    Raises:
        AssertionError: If any acceptance criterion fails.
    """
    ac_results = []
    result = None
    start_time = time.time()
    dry_run = ctx.get("dry_run", False)

    # --- Invoke Claude with a deterministic prompt ---
    result = invoke(
        "Say exactly: hello world",
        max_turns=1,
        output_format="json",
        model="haiku",
        dry_run=dry_run,
    )

    # --- ERR-1 / ERR-2: Handle special exit codes before other checks ---
    if result.exit_code == -1:
        ac_results.append(("AC-1", False, "Exit code is 0", "timeout after 60s"))
        raise AssertionError("timeout: claude invocation timed out")
    if result.exit_code == -2:
        ac_results.append(("AC-1", False, "Exit code is 0", "claude binary not found"))
        raise AssertionError("not found: claude binary not found in PATH")

    # --- AC checks wrapped in try/finally so report is written on both
    #     success and failure (LOG-1/LOG-2/LOG-3). ---
    try:
        # --- AC-1: Exit code is 0 ---
        try:
            assert_exit_code(result, 0)
            ac_results.append(("AC-1", True, "Exit code is 0", ""))
        except AssertionError as e:
            ac_results.append(("AC-1", False, "Exit code is 0", str(e)))
            raise

        # --- AC-2: stdout is non-empty ---
        try:
            assert len(result.stdout.strip()) > 0, (
                "AC-2 failed: result.stdout is empty"
            )
            ac_results.append(("AC-2", True, "stdout is non-empty", ""))
        except AssertionError as e:
            ac_results.append(("AC-2", False, "stdout is non-empty", str(e)))
            raise

        # --- AC-3: JSON parsed and contains "result" key ---
        try:
            assert result.json is not None, (
                "AC-3 failed: result.json is None (stdout could not be parsed as JSON)"
            )
            assert "result" in result.json, (
                f"AC-3 failed: 'result' key not in JSON response. "
                f"Keys: {sorted(result.json.keys())}"
            )
            ac_results.append(("AC-3", True, "JSON parsed with 'result' key", ""))
        except AssertionError as e:
            ac_results.append(("AC-3", False, "JSON parsed with 'result' key", str(e)))
            raise

        # --- AC-4: is_error is False ---
        try:
            assert_json_field(result, "is_error", False)
            ac_results.append(("AC-4", True, "is_error is False", ""))
        except AssertionError as e:
            ac_results.append(("AC-4", False, "is_error is False", str(e)))
            raise

        # --- AC-5: Response contains "hello" (case-insensitive) ---
        # In dry-run mode the fake result contains "[dry-run]", not "hello".
        # We skip this check in dry-run mode.
        if dry_run:
            ac_results.append(("AC-5", True, "Response contains 'hello' — SKIP (dry-run)", ""))
        else:
            try:
                response_text = result.json.get("result", "")
                assert re.search(r"(?i)hello", response_text), (
                    f"AC-5 failed: response does not contain 'hello' (case-insensitive). "
                    f"Response: {response_text[:200]!r}"
                )
                ac_results.append(("AC-5", True, "Response contains 'hello'", ""))
            except AssertionError as e:
                ac_results.append(("AC-5", False, "Response contains 'hello'", str(e)))
                raise

        # --- AC-6: session_id is a non-empty string ---
        try:
            session_id = result.json.get("session_id")
            assert isinstance(session_id, str), (
                f"AC-6 failed: session_id is {type(session_id).__name__}, expected str"
            )
            assert len(session_id) > 0, (
                "AC-6 failed: session_id is an empty string"
            )
            ac_results.append(("AC-6", True, "session_id is non-empty string", ""))
        except AssertionError as e:
            ac_results.append(("AC-6", False, "session_id is non-empty string", str(e)))
            raise

    except AssertionError:
        raise
    finally:
        _write_report(ctx, result=result, ac_results=ac_results,
                       duration=time.time() - start_time)


def _write_report(ctx, *, result, ac_results, duration):
    """Write a structured Markdown test report.

    Wrapped to satisfy LOG-3: log writing must not cause the test to fail.
    """
    try:
        # Write report to the scenario's own directory
        log_dir = ctx.get("scenario_dir", ".")
        os.makedirs(log_dir, exist_ok=True)
        report_path = os.path.join(log_dir, "hello_world_report.md")

        session_id = "(unknown)"
        if result and result.json:
            session_id = result.json.get("session_id", "(unknown)")

        report = generate_report(
            test_name="test_hello_world",
            session_id=session_id,
            duration=duration,
            workspace="",
            ac_results=ac_results,
            result=result,
            preserved=False,
        )

        with open(report_path, "w") as f:
            f.write(report)

    except OSError:
        pass  # LOG-3: log failure must not break the test
