"""test_konvert_agents.py — Integration test: full agent loop producing konvert artifacts.

Invokes Claude with the kiss-claw agent workflow (orchestrator, executor,
verificator, improver) to implement a Markdown-to-HTML converter (konvert.sh)
with tests, plan, reviews, and insights.

This test uses the interactive scenario runner to handle the multi-turn
INIT conversation with the orchestrator, then lets the agent work through
delegation.

This test validates that the agent loop produces the expected artifacts,
NOT that konvert.sh works correctly (see NR-1).
"""

import os
import shutil
import sys
import tempfile
import time
from pathlib import Path

# Ensure project root is on sys.path so "tests.lib" is importable
# when the runner loads this file via importlib.
# Path: tests/scenarios/02-konvert-agents/test_konvert_agents.py -> project root is 3 levels up
_project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if _project_root not in sys.path:
    sys.path.insert(0, _project_root)

from tests.lib.scenario_runner import load_scenario, run_scenario, scenario_to_ac_results
from tests.lib.report import generate_report

# Derive kiss-claw repo root from this file's location
_REPO_ROOT = str(Path(__file__).resolve().parents[3])


def run(ctx):
    """Execute the konvert agent integration test.

    Args:
        ctx: dict with keys 'scenario_dir', 'workspace', and 'dry_run'.

    Raises:
        AssertionError: If any must-pass acceptance criterion fails.
    """
    dry_run = ctx.get("dry_run", False)

    scenario_path = os.path.join(ctx["scenario_dir"], "scenario.json")

    # Validate scenario even in dry-run (catches JSON/schema errors early)
    scenario = load_scenario(scenario_path)

    # Create isolated temporary workspace (skip in dry-run)
    workspace = tempfile.mkdtemp(prefix="kiss-claw-konvert-") if not dry_run else "(dry-run)"
    all_passed = False
    start_time = time.time()

    try:
        # Execute the interactive scenario
        result = run_scenario(
            scenario_path,
            workspace,
            repo_root=_REPO_ROOT,
            dry_run=dry_run,
        )

        # Convert to AC results for report compatibility
        ac_results = scenario_to_ac_results(result)

        # Print consumption metrics from the last step that has a result
        last_cli_result = None
        for step in reversed(result.step_results):
            if step.result and step.result.json:
                last_cli_result = step.result
                break

        if last_cli_result and last_cli_result.json:
            _j = last_cli_result.json
            _cost = _j.get("total_cost_usd", "?")
            _turns = _j.get("num_turns", "?")
            _dur = _j.get("duration_ms", 0) / 1000
            _usage = _j.get("usage", {})
            _in = _usage.get("input_tokens", 0)
            _out = _usage.get("output_tokens", 0)
            _cache_c = _usage.get("cache_creation_input_tokens", 0)
            _cache_r = _usage.get("cache_read_input_tokens", 0)
            _stop = _j.get("stop_reason", "?")
            print(f"\n  === CONSUMPTION (last step) ===")
            print(f"  Cost     : ${_cost}")
            print(f"  Duration : {_dur:.0f}s ({_dur/60:.1f}min)")
            print(f"  Turns    : {_turns}")
            print(f"  Tokens   : {_in:,} in / {_out:,} out")
            print(f"  Cache    : {_cache_c:,} create / {_cache_r:,} read")
            print(f"  Stop     : {_stop}")
            print(f"  ====================\n")

        # Raise if any hard criterion failed
        if not result.passed:
            failed_steps = [s for s in result.step_results if not s.passed]
            failed_finals = [f for f in result.final_results if not f[1]]
            parts = []
            for s in failed_steps:
                parts.append(f"{s.id}: {'; '.join(f[2][:80] for f in s.failures)}")
            for f in failed_finals:
                parts.append(f"{f[0]}: {f[3][:80]}")
            raise AssertionError(f"Scenario failed: {'; '.join(parts)}")

        all_passed = True

    except AssertionError:
        raise

    finally:
        final_duration = time.time() - start_time
        preserved = True

        # Cleanup strategy: preserve workspace for inspection by default.
        # Set KISS_CLEANUP_ON_SUCCESS=1 to delete on success.
        if all_passed and os.environ.get("KISS_CLEANUP_ON_SUCCESS") == "1":
            preserved = False
            try:
                shutil.rmtree(workspace)
            except OSError:
                pass
        else:
            if not dry_run:
                print(f"  Workspace preserved: {workspace}")

        _write_report(
            ctx,
            result=result if "result" in dir() else None,
            ac_results=ac_results if "ac_results" in dir() else [],
            workspace=workspace,
            duration=final_duration,
            preserved=preserved,
        )


def _write_report(ctx, *, result, ac_results, workspace, duration, preserved):
    """Write a structured Markdown test report.

    Wrapped to satisfy LOG-3: log writing must not cause the test to fail.
    """
    try:
        log_dir = ctx.get("scenario_dir", ".")
        os.makedirs(log_dir, exist_ok=True)
        report_path = os.path.join(log_dir, "konvert_agents_report.md")

        session_id = "(unknown)"
        if result and result.session_id:
            session_id = result.session_id

        # Build step table for the report
        step_section = ""
        if result and result.step_results:
            lines = [
                "\n## Scenario Steps\n",
                "| # | Step | Duration | Status | Detail |",
                "|---|------|----------|--------|--------|",
            ]
            for i, step in enumerate(result.step_results):
                status = "PASS" if step.passed else "FAIL"
                detail = step.description
                if not step.passed and step.failures:
                    detail = "; ".join(f[1] for f in step.failures)
                detail = detail.replace("|", "\\|")[:100]
                lines.append(f"| {i+1} | {step.id} | {step.duration:.1f}s | {status} | {detail} |")
            step_section = "\n".join(lines)

        # Get the last CLI result for the report
        last_cli_result = None
        if result:
            for step in reversed(result.step_results):
                if step.result:
                    last_cli_result = step.result
                    break

        report = generate_report(
            test_name="test_konvert_agents",
            session_id=session_id,
            duration=duration,
            workspace=workspace,
            ac_results=ac_results,
            result=last_cli_result,
            preserved=preserved,
        )

        # Insert step section before "## Acceptance Criteria"
        if step_section:
            report = report.replace(
                "## Acceptance Criteria",
                step_section + "\n\n## Acceptance Criteria",
            )

        with open(report_path, "w") as f:
            f.write(report)

    except OSError:
        pass  # LOG-3: log failure must not break the test
