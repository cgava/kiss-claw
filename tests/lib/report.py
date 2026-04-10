"""report.py — Reusable test report generator for kiss-claw tests.

Generates structured Markdown reports with environment info, agent activity,
artifact inspection, and acceptance criteria results.

Stdlib only.
"""

import json
import os
from datetime import datetime, timezone
from pathlib import Path


def generate_report(
    test_name: str,
    session_id: str,
    duration: float,
    workspace: str,
    ac_results: list,
    result=None,
    preserved: bool = True,
    diagnosis: str = "",
) -> str:
    """Generate a standard test report as a markdown string.

    Args:
        test_name: Name of the test (e.g., "test_konvert_agents").
        session_id: Claude session ID.
        duration: Test duration in seconds.
        workspace: Path to the test workspace directory.
        ac_results: List of (id, passed, description, error_msg) tuples.
        result: ClaudeResult from invoke(), or None.
        preserved: Whether the workspace was preserved after the test.
        diagnosis: Optional free-form analysis text.

    Returns:
        Full report as a markdown string.
    """
    sections = []

    # --- Header ---
    all_passed = all(passed for _, passed, _, _ in ac_results) if ac_results else False
    status = "PASS" if all_passed else "FAIL"
    now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    sections.append(f"# Test Report: {test_name}\n")
    sections.append(f"| Field | Value |")
    sections.append(f"|-------|-------|")
    sections.append(f"| Status | **{status}** |")
    sections.append(f"| Date | {now_iso} |")
    sections.append(f"| Duration | {duration:.1f}s |")
    sections.append(f"| Session ID | `{session_id}` |")

    # Cost from result JSON if available
    cost = _extract_cost(result)
    if cost is not None:
        sections.append(f"| Cost | ${cost} |")

    sections.append("")

    # --- Environment ---
    sections.append("## Environment\n")
    sections.append("| Setting | Value |")
    sections.append("|---------|-------|")

    env = _extract_environment(result, workspace)
    for key, value in env:
        sections.append(f"| {key} | {value} |")
    sections.append("")

    # --- Agent Activity ---
    sections.append("## Agent Activity\n")
    agent_section = _build_agent_activity(workspace)
    sections.append(agent_section)
    sections.append("")

    # --- Artifacts Produced ---
    sections.append("## Artifacts Produced\n")
    artifact_section = _build_artifacts(workspace)
    sections.append(artifact_section)
    sections.append("")

    # --- Acceptance Criteria ---
    sections.append("## Acceptance Criteria\n")
    sections.append("| AC | Result | Detail |")
    sections.append("|----|--------|--------|")
    for ac_id, passed, description, error_msg in ac_results:
        mark = "PASS" if passed else "FAIL"
        detail = description if passed else f"{description} -- {error_msg}"
        # Escape pipes in detail
        detail = detail.replace("|", "\\|")
        sections.append(f"| {ac_id} | {mark} | {detail} |")
    sections.append("")

    # --- Diagnosis ---
    sections.append("## Diagnosis\n")
    if diagnosis:
        sections.append(diagnosis)
    else:
        sections.append("_No diagnosis provided._")
    sections.append("")

    # --- Workspace ---
    sections.append("## Workspace\n")
    sections.append(f"- **Path**: `{workspace}`")
    sections.append(f"- **Preserved**: {'yes' if preserved else 'no (cleaned up)'}")
    sections.append("")

    return "\n".join(sections)


def _extract_cost(result):
    """Extract cost from ClaudeResult JSON, if available."""
    if result and result.json:
        cost = result.json.get("cost_usd", result.json.get("cost"))
        if cost is not None:
            return cost
    return None


def _extract_environment(result, workspace):
    """Extract environment settings from result metadata and workspace state.

    Returns list of (key, value) tuples.
    """
    env = []

    # These are not stored in ClaudeResult directly, so we inspect what we can.
    # The caller's invoke() kwargs are not available to us, but we can check
    # the result JSON for model info and inspect the workspace for init.sh traces.

    # Model
    model = "unknown"
    if result and result.json:
        model = result.json.get("model", "unknown")
    env.append(("Model", model))

    # Exit code
    exit_code = result.exit_code if result else "(no result)"
    env.append(("Exit code", str(exit_code)))

    # init.sh invoked — check if .kiss-claw/ structure exists
    ws = Path(workspace) if workspace else None
    init_invoked = False
    if ws:
        init_invoked = (
            (ws / ".kiss-claw" / "STATE.md").exists()
            or (ws / ".kiss-claw" / "PLAN.md").exists()
        )
    env.append(("init.sh invoked", "yes" if init_invoked else "no"))

    # Context window
    env.append(("Context window", "unknown"))

    return env


def _build_agent_activity(workspace):
    """Parse .omc/state/mission-state.json and build an agent activity table."""
    mission_path = os.path.join(workspace, ".omc", "state", "mission-state.json")

    if not os.path.isfile(mission_path):
        return "_No OMC mission state found._"

    try:
        with open(mission_path, "r") as f:
            data = json.load(f)
    except (json.JSONDecodeError, OSError):
        return "_Failed to parse mission-state.json._"

    missions = data.get("missions", [])
    if not missions:
        return "_No missions in mission-state.json._"

    # Build a lookup of timeline events per agent for duration calculation
    lines = []
    lines.append("| Agent | Role | Duration | Status |")
    lines.append("|-------|------|----------|--------|")

    for mission in missions:
        agents = mission.get("agents", [])
        timeline = mission.get("timeline", [])

        # Build start/stop times per agent from timeline
        agent_times = {}
        for event in timeline:
            agent_name = event.get("agent", "")
            ts = event.get("at", "")
            kind = event.get("kind", "")
            detail = event.get("detail", "")

            if agent_name not in agent_times:
                agent_times[agent_name] = {"start": None, "stop": None}

            try:
                dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
            except (ValueError, AttributeError):
                continue

            if "start" in detail:
                agent_times[agent_name]["start"] = dt
            if kind == "completion" or "stop" in event.get("sourceKey", ""):
                agent_times[agent_name]["stop"] = dt

        for agent in agents:
            name = agent.get("name", "unknown")
            role = agent.get("role", "unknown")
            status = agent.get("status", "unknown")

            # Short name: take last two segments
            short_name = ":".join(name.split(":")[-2:]) if ":" in name else name
            short_role = role.split(":")[-1] if ":" in role else role

            # Calculate duration
            times = agent_times.get(name, {})
            start = times.get("start") if times else None
            stop = times.get("stop") if times else None
            if start and stop:
                dur = (stop - start).total_seconds()
                dur_str = f"{dur:.0f}s"
            else:
                dur_str = "n/a"

            lines.append(f"| {short_name} | {short_role} | {dur_str} | {status} |")

    return "\n".join(lines)


def _build_artifacts(workspace):
    """Scan workspace for expected artifacts and report their status."""
    ws = Path(workspace) if workspace else None
    if not ws:
        return "_No workspace path provided._"

    # Define expected artifacts and their standard/alternate locations
    artifacts = [
        ("PLAN.md", [".kiss-claw/PLAN.md", "PLAN.md"]),
        ("STATE.md", [".kiss-claw/STATE.md", "STATE.md"]),
        ("REVIEWS.md", [".kiss-claw/REVIEWS.md", "REVIEW.md", "REVIEWS.md"]),
        ("INSIGHTS.md", [".kiss-claw/INSIGHTS.md", "IMPROVEMENTS.md", "INSIGHTS.md"]),
    ]

    lines = []
    lines.append("| Expected | Found at | Status |")
    lines.append("|----------|----------|--------|")

    for name, candidates in artifacts:
        preferred = candidates[0]  # .kiss-claw/ location is preferred
        found_at = None
        is_preferred = False

        for candidate in candidates:
            if (ws / candidate).exists():
                found_at = candidate
                is_preferred = (candidate == preferred)
                break

        if found_at is None:
            lines.append(f"| {name} | -- | MISSING |")
        elif is_preferred:
            lines.append(f"| {name} | `{found_at}` | OK |")
        else:
            lines.append(f"| {name} | `{found_at}` | WRONG LOCATION |")

    return "\n".join(lines)
