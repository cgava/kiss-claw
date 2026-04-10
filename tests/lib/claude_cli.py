"""claude_cli.py — Claude CLI subprocess wrapper for kiss-claw tests.

Invokes `claude -p` via subprocess with structured result objects.
Stdlib only: subprocess, json, dataclasses.
"""

import json
import subprocess
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional


@dataclass
class ClaudeResult:
    """Result of a Claude CLI invocation."""
    stdout: str = ""
    stderr: str = ""
    exit_code: int = 0
    json: Optional[Dict[str, Any]] = None
    session_id: Optional[str] = None


# Default flags applied to every invocation (unless overridden)
_DEFAULT_FLAGS = [
    "--no-session-persistence",
    "--dangerously-skip-permissions",
    "--effort", "low",
]


def invoke(
    prompt: str,
    *,
    output_format: Optional[str] = None,
    system_prompt: Optional[str] = None,
    max_turns: Optional[int] = None,
    model: Optional[str] = None,
    effort: Optional[str] = None,
    allowed_tools: Optional[List[str]] = None,
    disallowed_tools: Optional[List[str]] = None,
    resume_session: Optional[str] = None,
    max_budget_usd: Optional[float] = None,
    mcp_config: Optional[str] = None,
    settings: Optional[str] = None,
    timeout: int = 60,
    extra_flags: Optional[List[str]] = None,
    cwd: Optional[str] = None,
) -> ClaudeResult:
    """Run `claude -p "prompt"` and return a structured result.

    Args:
        prompt: The prompt text to send.
        output_format: --output-format value (e.g., "json").
        system_prompt: --system-prompt value.
        max_turns: --max-turns value.
        model: --model value (e.g., "haiku").
        effort: --effort value (overrides default "low").
        allowed_tools: --allowedTools values.
        disallowed_tools: --disallowedTools values.
        resume_session: --resume session ID (disables --no-session-persistence).
        max_budget_usd: --max-budget-usd value.
        mcp_config: --mcp-config JSON string.
        settings: --settings JSON string.
        timeout: Subprocess timeout in seconds (default 60).
        extra_flags: Additional raw CLI flags to append.
        cwd: Working directory for the subprocess.

    Returns:
        ClaudeResult with stdout, stderr, exit_code, json, session_id.
    """
    cmd = ["claude", "-p"]

    # Build flags — start with defaults, allow overrides
    if resume_session:
        # Session resume: skip --no-session-persistence, add --resume
        cmd.extend(["--resume", resume_session])
        cmd.extend(["--dangerously-skip-permissions"])
        # Apply effort (default or override)
        cmd.extend(["--effort", effort or "low"])
    else:
        # Apply default flags
        if effort:
            # Override default effort
            cmd.extend(["--no-session-persistence", "--dangerously-skip-permissions"])
            cmd.extend(["--effort", effort])
        else:
            cmd.extend(_DEFAULT_FLAGS)

    # Optional flags
    if output_format:
        cmd.extend(["--output-format", output_format])
    if system_prompt:
        cmd.extend(["--system-prompt", system_prompt])
    if max_turns is not None:
        cmd.extend(["--max-turns", str(max_turns)])
    if model:
        cmd.extend(["--model", model])
    if allowed_tools is not None:
        cmd.extend(["--allowedTools", ",".join(allowed_tools)])
    if disallowed_tools is not None:
        cmd.extend(["--disallowedTools", ",".join(disallowed_tools)])
    if max_budget_usd is not None:
        cmd.extend(["--max-budget-usd", str(max_budget_usd)])
    if mcp_config:
        cmd.extend(["--mcp-config", mcp_config])
    if settings:
        cmd.extend(["--settings", settings])
    if extra_flags:
        cmd.extend(extra_flags)

    # Prompt is always last
    cmd.append(prompt)

    # Execute
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=cwd,
        )
    except subprocess.TimeoutExpired as e:
        return ClaudeResult(
            stdout=e.stdout or "",
            stderr=e.stderr or "",
            exit_code=-1,
            json=None,
            session_id=None,
        )
    except FileNotFoundError:
        return ClaudeResult(
            stdout="",
            stderr="'claude' binary not found in PATH",
            exit_code=-2,
            json=None,
            session_id=None,
        )

    # Build result
    result = ClaudeResult(
        stdout=proc.stdout,
        stderr=proc.stderr,
        exit_code=proc.returncode,
    )

    # Try to parse JSON from stdout
    if output_format == "json" or _looks_like_json(proc.stdout):
        try:
            data = json.loads(proc.stdout)
            result.json = data
            result.session_id = data.get("session_id")
        except (json.JSONDecodeError, ValueError):
            pass

    return result


def _looks_like_json(text: str) -> bool:
    """Quick heuristic: does the text start with { or [?"""
    stripped = text.strip()
    return stripped.startswith("{") or stripped.startswith("[")
