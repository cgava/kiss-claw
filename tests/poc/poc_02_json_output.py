#!/usr/bin/env python3
"""POC 02: JSON output format.

Proves: --output-format json returns parseable JSON with result, is_error,
session_id, and total_cost_usd fields.
"""

import json
import subprocess
import sys


def main():
    print("POC 02: JSON output format")
    print("=" * 50)

    try:
        result = subprocess.run(
            [
                "claude", "-p",
                "--output-format", "json",
                "--model", "haiku",
                "--effort", "low",
                "--no-session-persistence",
                "--dangerously-skip-permissions",
                "Reply with exactly: JSON_TEST_OK"
            ],
            capture_output=True,
            text=True,
            timeout=60,
        )

        print(f"Return code: {result.returncode}")
        print(f"Stdout length: {len(result.stdout)}")

        # Parse JSON
        data = json.loads(result.stdout)
        print(f"Parsed JSON keys: {sorted(data.keys())}")

        # Check required fields
        required_fields = ["result", "is_error", "session_id", "total_cost_usd"]
        missing = [f for f in required_fields if f not in data]

        if missing:
            print(f"\nFAIL: missing fields: {missing}")
            sys.exit(1)

        print(f"  result: {data['result'][:100]!r}")
        print(f"  is_error: {data['is_error']}")
        print(f"  session_id: {data['session_id']}")
        print(f"  total_cost_usd: {data['total_cost_usd']}")
        print(f"  type: {data.get('type')}")
        print(f"  subtype: {data.get('subtype')}")

        if not data["is_error"] and data["session_id"] and data["total_cost_usd"] is not None:
            print("\nPASS: JSON output is parseable with all required fields present")
        else:
            print("\nFAIL: fields present but values unexpected")
            sys.exit(1)

    except json.JSONDecodeError as e:
        print(f"\nFAIL: could not parse JSON: {e}")
        print(f"Raw stdout: {result.stdout[:500]!r}")
        sys.exit(1)
    except subprocess.TimeoutExpired:
        print("\nFAIL: command timed out after 60s")
        sys.exit(1)
    except Exception as e:
        print(f"\nFAIL: unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
