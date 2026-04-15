"""assertions.py — Assertion helpers for kiss-claw test scenarios.

All functions raise AssertionError with a clear message on failure.
Stdlib only: re, json, os, pathlib.
"""

import json
import os
import re
from pathlib import Path


def assert_exit_code(result, expected):
    """Check that result.exit_code equals expected.

    Args:
        result: Object with .exit_code attribute (from claude_cli.invoke).
        expected: Expected integer exit code.
    """
    actual = result.exit_code
    if actual != expected:
        raise AssertionError(
            f"Exit code mismatch: expected {expected}, got {actual}\n"
            f"  stderr: {result.stderr[:300] if result.stderr else '(empty)'}"
        )


def assert_file_exists(path):
    """Check that a file exists at the given path.

    Args:
        path: str or Path to the file.
    """
    p = Path(path)
    if not p.exists():
        raise AssertionError(f"File does not exist: {p}")
    if not p.is_file():
        raise AssertionError(f"Path exists but is not a file: {p}")


def assert_file_contains(path, pattern):
    """Check that file content matches a regex pattern.

    Args:
        path: str or Path to the file.
        pattern: Regex pattern string to search for in file content.
    """
    p = Path(path)
    if not p.exists():
        raise AssertionError(f"File does not exist: {p}")
    content = p.read_text()
    if not re.search(pattern, content):
        preview = content[:500] + ("..." if len(content) > 500 else "")
        raise AssertionError(
            f"File {p} does not match pattern: {pattern!r}\n"
            f"  content preview: {preview!r}"
        )


def assert_stdout_contains(result, pattern):
    """Check that result.stdout matches a regex pattern.

    Args:
        result: Object with .stdout attribute.
        pattern: Regex pattern string to search for in stdout.
    """
    if not re.search(pattern, result.stdout):
        preview = result.stdout[:500] + ("..." if len(result.stdout) > 500 else "")
        raise AssertionError(
            f"stdout does not match pattern: {pattern!r}\n"
            f"  stdout preview: {preview!r}"
        )


def assert_file_executable(path):
    """Check that a file exists and is executable.

    Args:
        path: str or Path to the file.
    """
    p = Path(path)
    if not p.exists():
        raise AssertionError(f"File does not exist: {p}")
    if not p.is_file():
        raise AssertionError(f"Path exists but is not a file: {p}")
    if not os.access(str(p), os.X_OK):
        raise AssertionError(f"File exists but is not executable: {p}")


def assert_glob_exists(base_dir, pattern):
    """Check that at least one file matches a glob pattern under base_dir.

    Args:
        base_dir: str or Path to the base directory to search from.
        pattern: Glob pattern string (e.g., ".kiss-claw/sessions/*/PLAN.md").

    Returns:
        Path to the first matching file (for further assertions).
    """
    base = Path(base_dir)
    if not base.is_dir():
        raise AssertionError(f"Base directory does not exist: {base}")
    matches = sorted(base.glob(pattern))
    if not matches:
        raise AssertionError(
            f"No files match glob pattern: {pattern}\n"
            f"  base_dir: {base}"
        )
    return matches[0]


def assert_json_field(result, field, expected):
    """Parse JSON from result and check that a field has the expected value.

    Args:
        result: Object with .json attribute (parsed dict or None) and .stdout.
        field: Dot-separated field path (e.g., "result" or "nested.field").
        expected: Expected value for the field.
    """
    data = result.json
    if data is None:
        # Try parsing stdout as fallback
        try:
            data = json.loads(result.stdout)
        except (json.JSONDecodeError, ValueError) as e:
            raise AssertionError(
                f"Cannot check field {field!r}: response is not JSON.\n"
                f"  parse error: {e}\n"
                f"  stdout preview: {result.stdout[:300]!r}"
            )

    # Support dot-separated field paths
    parts = field.split(".")
    current = data
    for part in parts:
        if not isinstance(current, dict):
            raise AssertionError(
                f"Cannot traverse field path {field!r}: "
                f"value at {part!r} is {type(current).__name__}, not dict"
            )
        if part not in current:
            raise AssertionError(
                f"Field {field!r} not found in JSON response.\n"
                f"  available keys at this level: {sorted(current.keys())}"
            )
        current = current[part]

    if current != expected:
        raise AssertionError(
            f"JSON field {field!r}: expected {expected!r}, got {current!r}"
        )
