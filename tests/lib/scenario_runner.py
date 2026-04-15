"""scenario_runner.py — Interactive multi-turn scenario runner for kiss-claw tests.

Loads a scenario.json file describing a sequence of prompt/resume steps,
executes each step via the Claude CLI (using --resume chaining), evaluates
assertions per step and at the end, and returns structured results.

Stdlib only: json, re, os, time, dataclasses, pathlib.
"""

import json
import os
import re
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional

# Import invoke from the project's claude_cli wrapper
import sys

_project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if _project_root not in sys.path:
    sys.path.insert(0, _project_root)

from tests.lib.claude_cli import invoke
from tests.lib.assertions import (
    assert_file_exists,
    assert_file_executable,
    assert_file_contains,
    assert_glob_exists,
)


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class StepResult:
    """Result of a single scenario step."""
    id: str
    description: str
    passed: bool
    failures: list  # list of (assertion_type, description, error_msg)
    duration: float
    result: Any = None  # ClaudeResult from invoke, None for wait steps


@dataclass
class ScenarioResult:
    """Result of a complete scenario execution."""
    name: str
    description: str
    step_results: list  # list of StepResult
    final_results: list  # list of (assertion_id, passed, description, error)
    session_id: Optional[str] = None
    total_duration: float = 0.0
    workspace: str = ""

    @property
    def passed(self) -> bool:
        """True if all steps passed and all required final assertions passed."""
        steps_ok = all(s.passed for s in self.step_results)
        finals_ok = all(
            f[1] for f in self.final_results
            if not (len(f) > 3 and f[3] == "soft")
        )
        return steps_ok and finals_ok


# ---------------------------------------------------------------------------
# Scenario loading
# ---------------------------------------------------------------------------

def load_scenario(scenario_path: str) -> dict:
    """Load and validate a scenario.json file.

    Args:
        scenario_path: Path to the scenario.json file.

    Returns:
        Parsed scenario dict.

    Raises:
        ValueError: If the scenario is malformed.
        FileNotFoundError: If the file does not exist.
    """
    p = Path(scenario_path)
    if not p.exists():
        raise FileNotFoundError(f"Scenario file not found: {scenario_path}")

    with open(p, "r") as f:
        try:
            scenario = json.load(f)
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid JSON in {scenario_path}: {e}")

    # Validate required top-level fields
    for field_name in ("name", "steps"):
        if field_name not in scenario:
            raise ValueError(f"Scenario missing required field: {field_name}")

    if not isinstance(scenario["steps"], list) or len(scenario["steps"]) == 0:
        raise ValueError("Scenario must have at least one step")

    # Validate each step
    for i, step in enumerate(scenario["steps"]):
        if "id" not in step:
            raise ValueError(f"Step {i} missing required field: id")
        if "action" not in step:
            raise ValueError(f"Step {step['id']} missing required field: action")
        action = step["action"]
        if "type" not in action:
            raise ValueError(f"Step {step['id']} action missing required field: type")
        if action["type"] not in ("prompt", "resume", "wait"):
            raise ValueError(
                f"Step {step['id']} has unknown action type: {action['type']}"
            )
        if action["type"] in ("prompt", "resume") and "content" not in action:
            raise ValueError(
                f"Step {step['id']} action type {action['type']} requires 'content'"
            )

    return scenario


# ---------------------------------------------------------------------------
# Interpolation
# ---------------------------------------------------------------------------

def _interpolate(text: str, variables: dict) -> str:
    """Replace {{var}} placeholders in text with values from variables dict."""
    for key, value in variables.items():
        text = text.replace("{{" + key + "}}", str(value))
    return text


def _interpolate_flags(flags: list, variables: dict) -> list:
    """Interpolate variables in a list of CLI flag strings."""
    return [_interpolate(f, variables) for f in flags]


# ---------------------------------------------------------------------------
# Assertion evaluation
# ---------------------------------------------------------------------------

def _evaluate_assertion(assertion: dict, *, result=None, workspace: str = "") -> tuple:
    """Evaluate a single assertion.

    Returns:
        (passed: bool, error_msg: str)
    """
    atype = assertion.get("type", "")
    desc = assertion.get("description", atype)

    try:
        if atype == "output_matches":
            pattern = assertion["pattern"]
            stdout = result.stdout if result else ""
            if not re.search(pattern, stdout, re.DOTALL):
                preview = stdout[:500] + ("..." if len(stdout) > 500 else "")
                return (False, f"output does not match pattern: {pattern!r} -- preview: {preview!r}")
            return (True, "")

        elif atype == "output_not_matches":
            pattern = assertion["pattern"]
            stdout = result.stdout if result else ""
            if re.search(pattern, stdout, re.DOTALL):
                return (False, f"output unexpectedly matches pattern: {pattern!r}")
            return (True, "")

        elif atype == "file_exists":
            path_pattern = assertion["path"]
            # Resolve relative to workspace
            if not os.path.isabs(path_pattern):
                # Use glob if pattern contains wildcards
                if "*" in path_pattern or "?" in path_pattern:
                    assert_glob_exists(workspace, path_pattern)
                else:
                    assert_file_exists(os.path.join(workspace, path_pattern))
            else:
                assert_file_exists(path_pattern)
            return (True, "")

        elif atype == "file_not_exists":
            path = assertion["path"]
            full_path = path if os.path.isabs(path) else os.path.join(workspace, path)
            if Path(full_path).exists():
                return (False, f"file unexpectedly exists: {full_path}")
            return (True, "")

        elif atype == "file_contains":
            path_pattern = assertion["path"]
            pattern = assertion["pattern"]
            if not os.path.isabs(path_pattern) and ("*" in path_pattern or "?" in path_pattern):
                resolved = assert_glob_exists(workspace, path_pattern)
                assert_file_contains(str(resolved), pattern)
            else:
                full_path = path_pattern if os.path.isabs(path_pattern) else os.path.join(workspace, path_pattern)
                assert_file_contains(full_path, pattern)
            return (True, "")

        elif atype == "file_executable":
            path = assertion["path"]
            full_path = path if os.path.isabs(path) else os.path.join(workspace, path)
            assert_file_executable(full_path)
            return (True, "")

        elif atype == "exit_code":
            expected = assertion["value"]
            actual = result.exit_code if result else -99
            if actual != expected:
                return (False, f"exit code: expected {expected}, got {actual}")
            return (True, "")

        else:
            return (False, f"unknown assertion type: {atype}")

    except AssertionError as e:
        return (False, str(e))
    except Exception as e:
        return (False, f"assertion error: {type(e).__name__}: {e}")


def _evaluate_expects(expects: list, *, result=None, workspace: str = "",
                      dry_run: bool = False) -> tuple:
    """Evaluate a list of step expectations.

    In dry_run mode, output_matches assertions are skipped (no real stdout).
    File assertions are also skipped in dry_run mode.

    Returns:
        (all_passed: bool, failures: list of (type, description, error))
    """
    failures = []
    for expect in expects:
        atype = expect.get("type", "")
        desc = expect.get("description", atype)

        if dry_run:
            # Skip assertions that require real CLI output or filesystem artifacts
            if atype in ("output_matches", "output_not_matches",
                         "file_exists", "file_not_exists", "file_contains",
                         "file_executable"):
                continue
            # exit_code can be checked even in dry_run (fake result has exit_code=0)

        passed, error = _evaluate_assertion(expect, result=result, workspace=workspace)
        if not passed:
            failures.append((atype, desc, error))

    return (len(failures) == 0, failures)


# ---------------------------------------------------------------------------
# Main runner
# ---------------------------------------------------------------------------

def run_scenario(
    scenario_path: str,
    workspace: str,
    *,
    repo_root: str,
    dry_run: bool = False,
) -> ScenarioResult:
    """Execute a scenario step by step.

    Args:
        scenario_path: Path to scenario.json file.
        workspace: Path to test workspace directory.
        repo_root: Path to kiss-claw repository root.
        dry_run: If True, simulate without CLI calls.

    Returns:
        ScenarioResult with all step and final assertion results.
    """
    scenario = load_scenario(scenario_path)
    agent_config = scenario.get("agent", {})
    test_config = scenario.get("test", {})

    session_id = None
    step_results = []
    last_result = None
    total_start = time.time()

    # Variables for interpolation
    variables = {
        "repo_root": repo_root,
        "workspace": workspace,
        "session_id": "",
        "step_id": "",
    }

    prefix = "[DRY RUN] " if dry_run else ""

    for step in scenario["steps"]:
        step_id = step["id"]
        action = step["action"]
        action_type = action["type"]
        variables["step_id"] = step_id
        variables["session_id"] = session_id or ""

        desc = step.get("description", step_id)
        print(f"  {prefix}Step [{step_id}]: {desc} ... ", end="", flush=True)

        step_start = time.time()

        if action_type == "wait":
            duration = action.get("duration", 5)
            if not dry_run:
                time.sleep(duration)
            step_results.append(StepResult(
                id=step_id,
                description=desc,
                passed=True,
                failures=[],
                duration=time.time() - step_start,
                result=None,
            ))
            print(f"OK (wait {duration}s)")
            continue

        # Interpolate content
        content = _interpolate(action["content"], variables)

        # Build extra flags
        extra_flags = _interpolate_flags(
            agent_config.get("extra_flags", []), variables
        )

        # Debug file support
        if test_config.get("debug_file", False) and not dry_run:
            debug_dir = os.path.join(workspace, ".kiss-claw-debug")
            os.makedirs(debug_dir, exist_ok=True)
            debug_path = os.path.join(debug_dir, f"{step_id}.log")
        else:
            debug_path = None

        # Determine timeout
        step_timeout = action.get("timeout",
                                  agent_config.get("timeout_per_step", 300))

        # Determine max_turns (0 means no limit -> pass None to avoid --max-turns 0)
        max_turns_val = agent_config.get("max_turns", 0)
        max_turns_arg = max_turns_val if max_turns_val > 0 else None

        # Build invoke kwargs
        invoke_kwargs = dict(
            output_format="json",
            model=agent_config.get("model", "sonnet"),
            effort=agent_config.get("effort", "medium"),
            max_turns=max_turns_arg,
            timeout=step_timeout,
            extra_flags=extra_flags if extra_flags else None,
            cwd=workspace,
            dry_run=dry_run,
            debug_file=debug_path,
        )

        if action_type == "prompt":
            result = invoke(content, **invoke_kwargs)
            # Capture session_id from first prompt
            if result.session_id:
                session_id = result.session_id

        elif action_type == "resume":
            if not session_id and not dry_run:
                # Cannot resume without a session
                step_results.append(StepResult(
                    id=step_id,
                    description=desc,
                    passed=False,
                    failures=[("resume", desc, "no session_id to resume from")],
                    duration=time.time() - step_start,
                    result=None,
                ))
                print("FAIL (no session_id)")
                on_failure = step.get("on_failure", "abort")
                if on_failure == "abort":
                    break
                continue

            invoke_kwargs["resume_session"] = session_id
            result = invoke(content, **invoke_kwargs)
            # Update session_id if changed
            if result.session_id:
                session_id = result.session_id

        last_result = result
        step_duration = time.time() - step_start

        # Evaluate step expectations
        step_passed, step_failures = _evaluate_expects(
            step.get("expect", []),
            result=result,
            workspace=workspace,
            dry_run=dry_run,
        )

        step_results.append(StepResult(
            id=step_id,
            description=desc,
            passed=step_passed,
            failures=step_failures,
            duration=step_duration,
            result=result,
        ))

        status = "OK" if step_passed else "FAIL"
        print(f"{status} ({step_duration:.1f}s)")

        if step_failures:
            for ftype, fdesc, ferror in step_failures:
                print(f"    [{ftype}] {fdesc}: {ferror[:200]}")

        # Flow control on failure
        if not step_passed:
            on_failure = step.get("on_failure", "abort")
            if on_failure == "abort":
                print(f"  Aborting scenario (on_failure=abort at step {step_id})")
                break
            elif on_failure.startswith("skip_to:"):
                target = on_failure.split(":", 1)[1]
                # Find target step index and skip to it
                step_ids = [s["id"] for s in scenario["steps"]]
                if target in step_ids:
                    target_idx = step_ids.index(target)
                    current_idx = step_ids.index(step_id)
                    # Skip is handled by the outer loop naturally
                    # since we continue; the next iteration will
                    # process the next step in sequence.
                    # For skip_to, we'd need to restructure.
                    # For v1, treat as continue.
                    print(f"    (skip_to:{target} -- treated as continue in v1)")
            # "continue" = keep going

    # Final assertions
    final_results = []
    for i, assertion in enumerate(scenario.get("final_assertions", [])):
        atype = assertion.get("type", "")
        desc = assertion.get("description", f"final-{i}")
        required = assertion.get("required", True)
        assertion_id = f"FA-{i+1}"

        if dry_run:
            # In dry_run, skip all final assertions that need real data
            final_results.append((assertion_id, True, f"{desc} -- SKIP (dry-run)", ""))
            continue

        passed, error = _evaluate_assertion(
            assertion, result=last_result, workspace=workspace
        )
        if not passed and not required:
            # Soft criterion -- record but don't fail
            final_results.append((assertion_id, True, f"{desc} (soft -- not required)", error))
        else:
            final_results.append((assertion_id, passed, desc, error))

    total_duration = time.time() - total_start

    return ScenarioResult(
        name=scenario["name"],
        description=scenario.get("description", ""),
        step_results=step_results,
        final_results=final_results,
        session_id=session_id,
        total_duration=total_duration,
        workspace=workspace,
    )


# ---------------------------------------------------------------------------
# Helpers for integration with existing test framework
# ---------------------------------------------------------------------------

def scenario_to_ac_results(scenario_result: ScenarioResult) -> list:
    """Convert ScenarioResult to the (id, passed, description, error) format
    used by the existing report generator.

    Returns:
        List of (ac_id, passed, description, error_msg) tuples.
    """
    ac_results = []

    # Step results as AC entries
    for i, step in enumerate(scenario_result.step_results):
        ac_id = f"STEP-{i+1}"
        if step.passed:
            ac_results.append((ac_id, True, f"Step [{step.id}]: {step.description}", ""))
        else:
            errors = "; ".join(f"{f[0]}: {f[2][:100]}" for f in step.failures)
            ac_results.append((ac_id, False, f"Step [{step.id}]: {step.description}", errors))

    # Final assertions
    for fa in scenario_result.final_results:
        ac_results.append(fa)

    return ac_results
