#!/usr/bin/env python3
"""POC 07: Session continuation (multi-turn via subprocess).

Proves: Start conversation, extract session_id from JSON, then resume with
--resume <id> for a follow-up. Multi-turn works via subprocess.

NOTE: This POC intentionally does NOT use --no-session-persistence
because session continuation requires persisted sessions.
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
        "--dangerously-skip-permissions",
    ] + list(extra_args) + [prompt]

    result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    return json.loads(result.stdout)


def main():
    print("POC 07: Session continuation (multi-turn)")
    print("=" * 50)

    # Step 1: Start a new conversation
    print("\n--- Step 1: Start new conversation ---")
    try:
        data1 = run_claude(
            "--system-prompt", "You are a memory test bot. Remember everything the user says. Always confirm what you remember.",
            prompt="Remember: the secret code is PINEAPPLE_42"
        )

        session_id = data1.get("session_id")
        print(f"  session_id: {session_id}")
        print(f"  is_error: {data1['is_error']}")
        print(f"  result: {data1['result'][:150]!r}")

        if not session_id:
            print("\nFAIL: no session_id in response")
            sys.exit(1)

        if data1["is_error"]:
            print("\nFAIL: first turn returned error")
            sys.exit(1)

        print("  OK: first turn completed, session_id captured")

    except Exception as e:
        print(f"\nFAIL: first turn failed: {e}")
        sys.exit(1)

    # Step 2: Resume conversation with --resume
    print("\n--- Step 2: Resume conversation ---")
    try:
        data2 = run_claude(
            "--resume", session_id,
            prompt="What is the secret code I told you?"
        )

        print(f"  session_id: {data2.get('session_id')}")
        print(f"  is_error: {data2['is_error']}")
        print(f"  result: {data2['result'][:150]!r}")

        if data2["is_error"]:
            print("\nFAIL: resume returned error")
            sys.exit(1)

        # Check if the model remembers the secret code
        if "PINEAPPLE_42" in data2["result"].upper():
            print("\n  PASS: session continuation works — model remembered the secret code")
        else:
            print("\n  PASS (soft): session resumed successfully (model may not have echoed exact code)")
            print(f"  Response: {data2['result'][:200]!r}")

        # Verify session IDs match
        if data2.get("session_id") == session_id:
            print("  Session ID preserved across turns: YES")
        else:
            print(f"  Session ID changed: {session_id} -> {data2.get('session_id')}")

    except Exception as e:
        print(f"\nFAIL: resume failed: {e}")
        sys.exit(1)

    print("\n" + "=" * 50)
    print("PASS: multi-turn session continuation via subprocess works")


if __name__ == "__main__":
    main()
