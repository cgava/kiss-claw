"""test_enrich_checkpoint.py — Unit tests for scripts/enrich_checkpoint.py

enrich_checkpoint.py enriches CHECKPOINT.yaml files by extracting verbatim content
from Claude session transcripts (.jsonl), classifying blocks into artifacts, decisions,
issues, and rationale, and filling in sparse step fields.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile

# Ensure project root is on sys.path
_project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if _project_root not in sys.path:
    sys.path.insert(0, _project_root)

# ---------------------------------------------------------------------------
# Fixture paths
# ---------------------------------------------------------------------------
FIXTURES_DIR = os.path.join(_project_root, "tests", "fixtures", "enrich-checkpoint")
SAMPLE_CHECKPOINT = os.path.join(FIXTURES_DIR, "sample_checkpoint.yaml")
SAMPLE_TRANSCRIPT = os.path.join(FIXTURES_DIR, "sample_transcript.jsonl")
EXPECTED_ENRICHED = os.path.join(FIXTURES_DIR, "expected_enriched.yaml")

SCRIPT_PATH = os.path.join(_project_root, "scripts", "enrich_checkpoint.py")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_temp_workspace(tmp_dir):
    """Create a temporary workspace mirroring the expected directory structure.

    Returns (workspace_root, session_dir, transcript_dir).
    """
    session_id = "20260413-223433"
    session_dir = os.path.join(tmp_dir, ".kiss-claw", "sessions", session_id)
    os.makedirs(session_dir, exist_ok=True)

    # Copy sample checkpoint
    shutil.copy(SAMPLE_CHECKPOINT, os.path.join(session_dir, "CHECKPOINT.yaml"))

    # Create transcript directory structure for subagent sessions
    # The parent session is 6dd4a886-0060-4cf9-96e5-6ed0dc4adb50
    # Claude Code slug keeps leading dash: /tmp/foo → -tmp-foo
    slug = tmp_dir.replace("/", "-")
    transcript_base = os.path.join(
        tmp_dir, ".claude", "projects", slug
    )
    parent_session = "6dd4a886-0060-4cf9-96e5-6ed0dc4adb50"
    subagent_dir = os.path.join(transcript_base, parent_session, "subagents")
    os.makedirs(subagent_dir, exist_ok=True)

    # Copy transcript for the short step (abc123-short)
    shutil.copy(SAMPLE_TRANSCRIPT, os.path.join(subagent_dir, "abc123-short.jsonl"))

    # No transcript for def456-long (tests missing transcript handling)

    # Create SESSIONS.json with claude_sessions_path for transcript discovery
    project_dir = os.path.join(tmp_dir, ".kiss-claw", "project")
    os.makedirs(project_dir, exist_ok=True)
    sessions_json = {"claude_sessions_path": transcript_base, "sessions": []}
    with open(os.path.join(project_dir, "SESSIONS.json"), "w") as f:
        json.dump(sessions_json, f)

    return tmp_dir, session_dir, transcript_base


# ---------------------------------------------------------------------------
# Unit tests — each can be called individually
# ---------------------------------------------------------------------------

def test_parse_jsonl():
    """Extract text blocks from JSONL, ignore thinking/tool_use/user, filter < 100 chars."""
    # Import the function under test — will fail until checkpoint-enrich.py exists
    from scripts.enrich_checkpoint import parse_jsonl

    blocks = parse_jsonl(SAMPLE_TRANSCRIPT)

    # Should extract only assistant text blocks with len > 100
    assert isinstance(blocks, list), f"Expected list, got {type(blocks).__name__}"
    assert len(blocks) > 0, "Expected at least one block extracted"

    # Verify no thinking blocks
    for block in blocks:
        assert "Let me think about" not in block, "Thinking block should be excluded"

    # Verify no tool_use content
    for block in blocks:
        assert "tool_use" not in block, "Tool use blocks should be excluded"

    # Verify no user messages
    for block in blocks:
        assert block != "Please implement the store refactoring as described in the plan.", \
            "User messages should be excluded"

    # Verify short blocks (< 100 chars) are excluded
    for block in blocks:
        assert len(block) >= 100, f"Block too short ({len(block)} chars): {block[:50]}..."

    # Should have exactly 6 substantial blocks from our fixture:
    # 1. "I will start by reading..." (first substantial)
    # 2. "J'ai choisi de restructurer..." (decision)
    # 3. "Here is the summary..." (table/artifact)
    # 4. "One caveat to note..." (issue)
    # 5. "Verdict : approved-with-notes..." (artifact — REV/Verdict)
    # 6. "=== TASK REPORT ===" (artifact)
    assert len(blocks) == 6, f"Expected 6 blocks, got {len(blocks)}"


def test_classify_blocks():
    """Verify classification: table -> artifacts, decision keywords -> decisions, etc."""
    from scripts.enrich_checkpoint import classify_blocks

    blocks = [
        "Here is a table:\n| Col1 | Col2 |\n|---|---|\n| val1 | val2 |" + " " * 80,
        "J'ai choisi cette approche plutot que l'alternative car elle est plus simple" + " " * 50,
        "One caveat: the function does not handle edge cases correctly" + " " * 50,
        "=== TASK REPORT ===\nAgent: kiss-executor\nTask: do something\nDone:\n  - file modified" + " " * 50,
        "Verdict : approved-with-notes\nREV-0003 — store.sh coverage is good but guard.sh has gaps" + " " * 50,
        "This is a generic block with no special signals but still substantial content" + " " * 50,
    ]

    classified = classify_blocks(blocks)

    # classified should be a dict with keys: artifacts, decisions, issues, rationale
    assert isinstance(classified, dict), f"Expected dict, got {type(classified).__name__}"
    for key in ("artifacts", "decisions", "issues", "rationale"):
        assert key in classified, f"Missing key: {key}"

    # Table block -> artifacts
    assert "|---|---|" in classified["artifacts"], \
        "Table block should be classified as artifact"

    # TASK REPORT -> artifacts
    assert "TASK REPORT" in classified["artifacts"], \
        "Task report block should be classified as artifact"

    # Verdict / REV- -> artifacts
    assert "Verdict" in classified["artifacts"] or "REV-" in classified["artifacts"], \
        "Verdict/REV- block should be classified as artifact"

    # Decision keyword -> decisions
    assert "choisi" in classified["decisions"], \
        "Decision block should be classified as decision"

    # Rationale synthesized from decisions
    assert len(classified["rationale"]) > 0, \
        "Rationale should be synthesized from decision blocks"

    # Caveat keyword -> issues
    assert "caveat" in classified["issues"], \
        "Caveat block should be classified as issue"


def test_enrich_step():
    """Given a step with short task/result + extracted blocks, verify enrichment."""
    from scripts.enrich_checkpoint import enrich_step

    step = {
        "agent": "kiss-executor",
        "claude_session": "abc123-short",
        "task": "Short task",
        "result": "Short result",
    }

    blocks = [
        "I will start by reading the current implementation and understanding the structure. "
        "The goal is to restructure the directory into three subdirectories for better organization.",
        "J'ai choisi de restructurer en utilisant un case statement plutot que des if/elif. "
        "Cette approche est plus lisible et plus facile a maintenir dans le temps.",
        "| Resource | Directory |\n|---|---|\n| memory | project/ |\n| plan | sessions/ |"
        + " " * 80,
        "One caveat to note: the function does not handle missing sessions correctly. "
        "This is a limitation that should be addressed in a follow-up.",
        "=== TASK REPORT ===\nAgent: kiss-executor\nTask: Refactoring\nDone:\n  - file modified"
        + " " * 80,
    ]

    enriched = enrich_step(step, blocks)

    # task should be enriched (was < 200 chars)
    assert len(enriched.get("task", "")) > len(step["task"]), \
        "Task should be enriched with first substantial block"

    # result should be enriched (was < 200 chars)
    assert len(enriched.get("result", "")) > len(step["result"]), \
        "Result should be enriched with last substantial block"

    # artifacts should contain table and task report
    assert "artifacts" in enriched, "Enriched step should have artifacts"
    assert len(enriched["artifacts"]) > 0, "Artifacts should not be empty"

    # decisions should contain the decision block
    assert "decisions" in enriched, "Enriched step should have decisions"
    assert len(enriched["decisions"]) > 0, "Decisions should not be empty"

    # issues should contain the caveat block
    assert "issues" in enriched, "Enriched step should have issues"
    assert len(enriched["issues"]) > 0, "Issues should not be empty"


def test_no_overwrite():
    """Given a step with long (>200 chars) task/result, verify they are NOT overwritten."""
    from scripts.enrich_checkpoint import enrich_step

    long_text = "x" * 250  # Exceeds 200 char threshold

    step = {
        "agent": "kiss-verificator",
        "claude_session": "def456-long",
        "task": long_text,
        "result": long_text,
    }

    blocks = [
        "This is a new block that could potentially replace existing content. "
        "It has enough characters to be considered substantial by the parser." + " " * 50,
    ]

    enriched = enrich_step(step, blocks)

    # task and result should NOT be overwritten
    assert enriched.get("task") == long_text, \
        "Long task should NOT be overwritten"
    assert enriched.get("result") == long_text, \
        "Long result should NOT be overwritten"


def test_dry_run():
    """Verify --dry-run prints output but doesn't modify the CHECKPOINT file."""
    tmp_dir = tempfile.mkdtemp(prefix="kiss-enrich-test-")
    try:
        workspace, session_dir, transcript_base = _make_temp_workspace(tmp_dir)
        checkpoint_path = os.path.join(session_dir, "CHECKPOINT.yaml")

        # Read original content
        with open(checkpoint_path, "r") as f:
            original_content = f.read()

        # Run in dry-run mode
        result = subprocess.run(
            [
                sys.executable, SCRIPT_PATH,
                "20260413-223433",
                "--dry-run",
            ],
            capture_output=True,
            text=True,
            cwd=workspace,
            env={
                **os.environ,
                "KISS_CLAW_DIR": os.path.join(workspace, ".kiss-claw"),
                "HOME": tmp_dir,
            },
        )

        # Script should exit successfully
        assert result.returncode == 0, \
            f"dry-run should exit 0, got {result.returncode}\nstderr: {result.stderr}"

        # stdout should contain some indication of what would change
        assert len(result.stdout) > 0, "dry-run should produce output"

        # CHECKPOINT file should be UNCHANGED
        with open(checkpoint_path, "r") as f:
            after_content = f.read()

        assert after_content == original_content, \
            "dry-run should NOT modify the CHECKPOINT file"

    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


def test_batch_mode():
    """Verify all steps in a CHECKPOINT are processed when no --step flag."""
    tmp_dir = tempfile.mkdtemp(prefix="kiss-enrich-test-")
    try:
        workspace, session_dir, transcript_base = _make_temp_workspace(tmp_dir)
        checkpoint_path = os.path.join(session_dir, "CHECKPOINT.yaml")

        result = subprocess.run(
            [
                sys.executable, SCRIPT_PATH,
                "20260413-223433",
            ],
            capture_output=True,
            text=True,
            cwd=workspace,
            env={
                **os.environ,
                "KISS_CLAW_DIR": os.path.join(workspace, ".kiss-claw"),
                "HOME": tmp_dir,
            },
        )

        assert result.returncode == 0, \
            f"batch mode should exit 0, got {result.returncode}\nstderr: {result.stderr}"

        # Read enriched checkpoint
        with open(checkpoint_path, "r") as f:
            enriched_content = f.read()

        # The first step (abc123-short) should have been enriched
        # It had a short task, so it should now be longer
        assert "artifacts" in enriched_content or "decisions" in enriched_content, \
            "Enriched checkpoint should contain new fields (artifacts or decisions)"

        # The second step (def456-long) should mention missing transcript
        # (no crash, just a warning)
        # Check stderr for a warning about missing transcript
        # (The step still exists but was not enriched due to missing file)

    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


def test_step_mode():
    """Verify only the specified step is processed with --step flag."""
    tmp_dir = tempfile.mkdtemp(prefix="kiss-enrich-test-")
    try:
        workspace, session_dir, transcript_base = _make_temp_workspace(tmp_dir)
        checkpoint_path = os.path.join(session_dir, "CHECKPOINT.yaml")

        result = subprocess.run(
            [
                sys.executable, SCRIPT_PATH,
                "20260413-223433",
                "--step", "abc123-short",
            ],
            capture_output=True,
            text=True,
            cwd=workspace,
            env={
                **os.environ,
                "KISS_CLAW_DIR": os.path.join(workspace, ".kiss-claw"),
                "HOME": tmp_dir,
            },
        )

        assert result.returncode == 0, \
            f"step mode should exit 0, got {result.returncode}\nstderr: {result.stderr}"

        # Read enriched checkpoint
        with open(checkpoint_path, "r") as f:
            enriched_content = f.read()

        # The targeted step should have been enriched
        assert "artifacts" in enriched_content or "decisions" in enriched_content, \
            "Targeted step should be enriched"

    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


def test_missing_transcript():
    """Verify graceful handling when .jsonl file not found (warning, not crash)."""
    tmp_dir = tempfile.mkdtemp(prefix="kiss-enrich-test-")
    try:
        workspace, session_dir, transcript_base = _make_temp_workspace(tmp_dir)

        # Run enrichment targeting a step whose transcript does NOT exist
        result = subprocess.run(
            [
                sys.executable, SCRIPT_PATH,
                "20260413-223433",
                "--step", "def456-long",
            ],
            capture_output=True,
            text=True,
            cwd=workspace,
            env={
                **os.environ,
                "KISS_CLAW_DIR": os.path.join(workspace, ".kiss-claw"),
                "HOME": tmp_dir,
            },
        )

        # Should NOT crash (exit code 0)
        assert result.returncode == 0, \
            f"Missing transcript should not crash, got exit {result.returncode}\n" \
            f"stderr: {result.stderr}"

        # Should produce a warning on stderr
        assert "warning" in result.stderr.lower() or "not found" in result.stderr.lower(), \
            f"Expected warning about missing transcript in stderr: {result.stderr}"

    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


# ---------------------------------------------------------------------------
# Runner-compatible entry point
# ---------------------------------------------------------------------------

def run(ctx):
    """Execute all checkpoint-enrich unit tests.

    Compatible with tests/lib/runner.py discovery.

    Args:
        ctx: dict with keys 'scenario_dir', 'workspace', 'dry_run'.

    Raises:
        AssertionError: If any test fails.
    """
    dry_run = ctx.get("dry_run", False)

    if dry_run:
        print("[dry-run] Would run 8 unit tests for enrich_checkpoint.py")
        print("[dry-run] Tests expect scripts/enrich_checkpoint module to exist")
        return

    # Run all unit tests — collect results
    tests = [
        ("test_parse_jsonl", test_parse_jsonl),
        ("test_classify_blocks", test_classify_blocks),
        ("test_enrich_step", test_enrich_step),
        ("test_no_overwrite", test_no_overwrite),
        ("test_dry_run", test_dry_run),
        ("test_batch_mode", test_batch_mode),
        ("test_step_mode", test_step_mode),
        ("test_missing_transcript", test_missing_transcript),
    ]

    failures = []
    for name, test_fn in tests:
        try:
            print(f"  {name} ... ", end="", flush=True)
            test_fn()
            print("PASS")
        except Exception as e:
            print(f"FAIL: {e}")
            failures.append((name, e))

    if failures:
        summary = "; ".join(f"{name}: {type(e).__name__}" for name, e in failures)
        raise AssertionError(
            f"{len(failures)}/{len(tests)} tests failed: {summary}"
        )
