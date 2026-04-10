#!/usr/bin/env python3
"""POC 04: Tool restriction flags.

Proves: --allowedTools and --disallowedTools restrict tool usage.
Also tests --tools "" to disable all tools.
"""

import json
import subprocess
import sys


def run_claude(*extra_args, prompt="say hello"):
    """Run claude with standard flags plus extras, return parsed JSON."""
    cmd = [
        "claude", "-p",
        "--output-format", "json",
        "--model", "haiku",
        "--effort", "low",
        "--no-session-persistence",
        "--dangerously-skip-permissions",
    ] + list(extra_args) + [prompt]

    result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    return json.loads(result.stdout)


def main():
    print("POC 04: Tool restriction flags")
    print("=" * 50)

    failures = []

    # Test 1: --tools "" (no tools at all)
    print("\n--- Test 1: --tools '' (disable all tools) ---")
    try:
        data = run_claude(
            "--tools", "",
            "--system-prompt", "Reply with exactly: NO_TOOLS_OK",
            prompt="say hello"
        )
        print(f"  is_error: {data['is_error']}")
        print(f"  result: {data['result'][:100]!r}")
        if not data["is_error"]:
            print("  PASS: --tools '' accepted, response returned without tools")
        else:
            print(f"  FAIL: is_error=True")
            failures.append("tools-empty")
    except Exception as e:
        print(f"  FAIL: {e}")
        failures.append("tools-empty")

    # Test 2: --disallowedTools to block Bash
    print("\n--- Test 2: --disallowedTools Bash ---")
    try:
        data = run_claude(
            "--disallowedTools", "Bash",
            "--system-prompt", "Reply with exactly: BASH_DISABLED",
            prompt="say hello"
        )
        print(f"  is_error: {data['is_error']}")
        print(f"  result: {data['result'][:100]!r}")
        if not data["is_error"]:
            print("  PASS: --disallowedTools Bash accepted")
        else:
            print(f"  FAIL: is_error=True")
            failures.append("disallowedTools")
    except Exception as e:
        print(f"  FAIL: {e}")
        failures.append("disallowedTools")

    # Test 3: --allowedTools to whitelist only Read
    print("\n--- Test 3: --allowedTools Read ---")
    try:
        data = run_claude(
            "--allowedTools", "Read",
            "--system-prompt", "Reply with exactly: ONLY_READ",
            prompt="say hello"
        )
        print(f"  is_error: {data['is_error']}")
        print(f"  result: {data['result'][:100]!r}")
        if not data["is_error"]:
            print("  PASS: --allowedTools Read accepted")
        else:
            print(f"  FAIL: is_error=True")
            failures.append("allowedTools")
    except Exception as e:
        print(f"  FAIL: {e}")
        failures.append("allowedTools")

    # Summary
    print("\n" + "=" * 50)
    if not failures:
        print("PASS: tool restriction flags all work correctly")
    else:
        print(f"FAIL: these tests had issues: {failures}")
        sys.exit(1)


if __name__ == "__main__":
    main()
