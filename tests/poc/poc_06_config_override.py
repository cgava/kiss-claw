#!/usr/bin/env python3
"""POC 06: Config override — clean session.

Proves: we can start claude with a clean/restricted config:
- No MCP servers (--mcp-config with empty config)
- Restricted settings via --settings
- Goal: prove a "clean" session with no extensions interfering.
"""

import json
import subprocess
import sys


def main():
    print("POC 06: Config override — clean session")
    print("=" * 50)

    failures = []

    # Test 1: --mcp-config with empty MCP config
    print("\n--- Test 1: --mcp-config with empty config ---")
    try:
        empty_mcp = json.dumps({"mcpServers": {}})

        result = subprocess.run(
            [
                "claude", "-p",
                "--output-format", "json",
                "--model", "haiku",
                "--effort", "low",
                "--no-session-persistence",
                "--dangerously-skip-permissions",
                "--mcp-config", empty_mcp,
                "--system-prompt", "Reply with exactly: CLEAN_MCP",
                "say hello"
            ],
            capture_output=True,
            text=True,
            timeout=60,
        )

        data = json.loads(result.stdout)
        print(f"  is_error: {data['is_error']}")
        print(f"  result: {data['result'][:100]!r}")
        if not data["is_error"]:
            print("  PASS: --mcp-config with empty config accepted")
        else:
            print(f"  FAIL: is_error=True, errors: {data.get('errors', [])}")
            failures.append("mcp-config-empty")
    except json.JSONDecodeError as e:
        print(f"  JSON parse error: {e}")
        print(f"  Stdout: {result.stdout[:300]!r}")
        print(f"  Stderr: {result.stderr[:300]!r}")
        failures.append("mcp-config-empty")
    except Exception as e:
        print(f"  FAIL: {e}")
        failures.append("mcp-config-empty")

    # Test 2: --settings with restrictive settings JSON
    print("\n--- Test 2: --settings with restrictive JSON ---")
    try:
        settings = json.dumps({
            "permissions": {
                "allow": [],
                "deny": []
            }
        })

        result = subprocess.run(
            [
                "claude", "-p",
                "--output-format", "json",
                "--model", "haiku",
                "--effort", "low",
                "--no-session-persistence",
                "--dangerously-skip-permissions",
                "--settings", settings,
                "--system-prompt", "Reply with exactly: SETTINGS_OK",
                "say hello"
            ],
            capture_output=True,
            text=True,
            timeout=60,
        )

        data = json.loads(result.stdout)
        print(f"  is_error: {data['is_error']}")
        print(f"  result: {data['result'][:100]!r}")
        if not data["is_error"]:
            print("  PASS: --settings with restrictive JSON accepted")
        else:
            print(f"  FAIL: is_error=True, errors: {data.get('errors', [])}")
            failures.append("settings-json")
    except json.JSONDecodeError as e:
        print(f"  JSON parse error: {e}")
        print(f"  Stdout: {result.stdout[:300]!r}")
        print(f"  Stderr: {result.stderr[:300]!r}")
        failures.append("settings-json")
    except Exception as e:
        print(f"  FAIL: {e}")
        failures.append("settings-json")

    # Test 3: --tools "" + --mcp-config empty + --settings = fully clean session
    print("\n--- Test 3: fully clean session (no tools, no MCP, restrictive settings) ---")
    try:
        empty_mcp = json.dumps({"mcpServers": {}})
        settings = json.dumps({"permissions": {"allow": [], "deny": []}})

        result = subprocess.run(
            [
                "claude", "-p",
                "--output-format", "json",
                "--model", "haiku",
                "--effort", "low",
                "--no-session-persistence",
                "--dangerously-skip-permissions",
                "--tools", "",
                "--mcp-config", empty_mcp,
                "--settings", settings,
                "--system-prompt", "Reply with exactly: FULLY_CLEAN",
                "say hello"
            ],
            capture_output=True,
            text=True,
            timeout=60,
        )

        data = json.loads(result.stdout)
        print(f"  is_error: {data['is_error']}")
        print(f"  result: {data['result'][:100]!r}")
        if not data["is_error"]:
            print("  PASS: fully clean session works")
        else:
            print(f"  FAIL: is_error=True, errors: {data.get('errors', [])}")
            failures.append("fully-clean")
    except json.JSONDecodeError as e:
        print(f"  JSON parse error: {e}")
        print(f"  Stdout: {result.stdout[:300]!r}")
        print(f"  Stderr: {result.stderr[:300]!r}")
        failures.append("fully-clean")
    except Exception as e:
        print(f"  FAIL: {e}")
        failures.append("fully-clean")

    # Summary
    print("\n" + "=" * 50)
    if not failures:
        print("PASS: config override for clean sessions works correctly")
    else:
        print(f"FAIL: these tests had issues: {failures}")
        sys.exit(1)


if __name__ == "__main__":
    main()
