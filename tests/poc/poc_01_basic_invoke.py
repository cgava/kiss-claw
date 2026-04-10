#!/usr/bin/env python3
"""POC 01: Basic CLI invocation via subprocess.

Proves: subprocess.run(["claude", "-p", "say hello"], ...) captures stdout text.
"""

import subprocess
import sys


def main():
    print("POC 01: Basic CLI invocation via subprocess")
    print("=" * 50)

    try:
        result = subprocess.run(
            [
                "claude", "-p",
                "--model", "haiku",
                "--effort", "low",
                "--no-session-persistence",
                "--dangerously-skip-permissions",
                "Reply with exactly the word: HELLO_POC_01"
            ],
            capture_output=True,
            text=True,
            timeout=60,
        )

        print(f"Return code: {result.returncode}")
        print(f"Stdout length: {len(result.stdout)}")
        print(f"Stdout: {result.stdout.strip()!r}")
        if result.stderr:
            print(f"Stderr: {result.stderr.strip()[:200]!r}")

        # Verify we got text output
        if result.returncode == 0 and len(result.stdout.strip()) > 0:
            # Check the response contains our expected marker
            if "HELLO_POC_01" in result.stdout:
                print("\nPASS: subprocess captured stdout text with expected content")
            else:
                print(f"\nPASS: subprocess captured stdout text (content: {result.stdout.strip()[:100]!r})")
        else:
            print(f"\nFAIL: unexpected return code {result.returncode} or empty stdout")
            sys.exit(1)

    except subprocess.TimeoutExpired:
        print("\nFAIL: command timed out after 60s")
        sys.exit(1)
    except FileNotFoundError:
        print("\nFAIL: 'claude' binary not found in PATH")
        sys.exit(1)
    except Exception as e:
        print(f"\nFAIL: unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
