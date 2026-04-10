"""runner.py — Test scenario runner for kiss-claw.

Discovers test_*.py files under tests/scenarios/, imports each,
calls run(ctx), and collects pass/fail/error results.

Usage:
    python -m tests.lib.runner
    python tests/lib/runner.py
"""

import importlib.util
import sys
import time
import traceback
from pathlib import Path


def discover_scenarios(scenarios_dir: Path) -> list:
    """Find all test_*.py files under scenarios_dir, sorted by name."""
    if not scenarios_dir.is_dir():
        return []
    return sorted(scenarios_dir.glob("test_*.py"))


def load_and_run(scenario_path: Path, ctx: dict) -> dict:
    """Load a scenario module and call its run(ctx) function.

    Returns:
        {"name": str, "status": "pass"|"fail"|"error", "message": str, "duration": float}
    """
    name = scenario_path.stem
    start = time.time()

    try:
        # Dynamic import from file path
        spec = importlib.util.spec_from_file_location(name, str(scenario_path))
        if spec is None or spec.loader is None:
            return {
                "name": name,
                "status": "error",
                "message": f"Could not load module spec from {scenario_path}",
                "duration": time.time() - start,
            }

        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        if not hasattr(module, "run"):
            return {
                "name": name,
                "status": "error",
                "message": f"Scenario {name} has no run(ctx) function",
                "duration": time.time() - start,
            }

        # Call run(ctx) — if it raises AssertionError, it's a fail;
        # any other exception is an error.
        module.run(ctx)

        return {
            "name": name,
            "status": "pass",
            "message": "",
            "duration": time.time() - start,
        }

    except AssertionError as e:
        return {
            "name": name,
            "status": "fail",
            "message": str(e),
            "duration": time.time() - start,
        }

    except Exception as e:
        return {
            "name": name,
            "status": "error",
            "message": f"{type(e).__name__}: {e}\n{traceback.format_exc()}",
            "duration": time.time() - start,
        }


def run_all(scenarios_dir: Path, workspace: Path) -> list:
    """Discover and run all scenarios. Returns list of result dicts."""
    scenarios = discover_scenarios(scenarios_dir)

    if not scenarios:
        print(f"No test scenarios found in {scenarios_dir}")
        return []

    print(f"Found {len(scenarios)} scenario(s) in {scenarios_dir}\n")

    ctx = {
        "scenario_dir": str(scenarios_dir),
        "workspace": str(workspace),
    }

    results = []
    for scenario_path in scenarios:
        name = scenario_path.stem
        print(f"  Running: {name} ... ", end="", flush=True)
        result = load_and_run(scenario_path, ctx)
        results.append(result)

        status_label = {
            "pass": "PASS",
            "fail": "FAIL",
            "error": "ERROR",
        }[result["status"]]

        duration_str = f"({result['duration']:.1f}s)"
        print(f"{status_label} {duration_str}")

        if result["status"] in ("fail", "error") and result["message"]:
            # Indent the message for readability
            for line in result["message"].split("\n")[:10]:
                print(f"    {line}")

    return results


def print_summary(results: list) -> int:
    """Print summary and return exit code (0 = all pass, 1 = any fail/error)."""
    total = len(results)
    passed = sum(1 for r in results if r["status"] == "pass")
    failed = sum(1 for r in results if r["status"] == "fail")
    errors = sum(1 for r in results if r["status"] == "error")
    total_duration = sum(r["duration"] for r in results)

    print(f"\n{'=' * 50}")
    print(f"Results: {total} total, {passed} passed, {failed} failed, {errors} errors")
    print(f"Duration: {total_duration:.1f}s")

    if failed == 0 and errors == 0:
        print("Status: ALL PASSED")
        return 0
    else:
        print("Status: FAILURES DETECTED")
        if failed > 0:
            print("\nFailed scenarios:")
            for r in results:
                if r["status"] == "fail":
                    print(f"  - {r['name']}: {r['message'][:200]}")
        if errors > 0:
            print("\nError scenarios:")
            for r in results:
                if r["status"] == "error":
                    print(f"  - {r['name']}: {r['message'][:200]}")
        return 1


def main():
    """Entry point — discover and run all test scenarios."""
    # Determine project root (tests/lib/runner.py -> project root is 2 levels up)
    runner_path = Path(__file__).resolve()
    tests_dir = runner_path.parent.parent
    project_root = tests_dir.parent

    scenarios_dir = tests_dir / "scenarios"
    workspace = project_root

    print(f"kiss-claw test runner")
    print(f"Scenarios: {scenarios_dir}")
    print(f"Workspace: {workspace}")
    print(f"{'=' * 50}\n")

    results = run_all(scenarios_dir, workspace)

    if not results:
        print("No scenarios to run. Create test_*.py files in tests/scenarios/")
        sys.exit(0)

    exit_code = print_summary(results)
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
