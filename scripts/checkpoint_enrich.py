#!/usr/bin/env python3
"""checkpoint-enrich.py — Enrich CHECKPOINT.yaml with classified transcript content.

Reads Claude session transcripts (.jsonl), extracts substantial text blocks,
classifies them (artifacts, decisions, issues, rationale), and enriches
sparse CHECKPOINT step fields.

Usage:
    python3 scripts/checkpoint-enrich.py <session-id> [--step <claude_session_id>] [--dry-run]
"""

import argparse
import json
import os
import re
import sys

import yaml


# ---------------------------------------------------------------------------
# Core functions
# ---------------------------------------------------------------------------

def parse_jsonl(path):
    """Extract substantial text blocks from a JSONL transcript.

    Only assistant messages with content type "text" and length >= 100 are kept.
    Thinking blocks, tool_use blocks, and user messages are excluded.

    Args:
        path: Path to a .jsonl transcript file.

    Returns:
        List of text strings (each >= 100 chars).
    """
    blocks = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            # Only assistant messages
            msg = entry.get("message", {})
            if msg.get("role") != "assistant":
                continue

            content_list = msg.get("content", [])
            for content in content_list:
                if content.get("type") != "text":
                    continue
                text = content.get("text", "")
                if len(text) >= 100:
                    blocks.append(text)

    return blocks


def classify_blocks(blocks):
    """Classify text blocks into artifacts, decisions, issues, and rationale.

    Classification signals:
        - artifacts: "=== TASK REPORT ===", "Verdict :", "REV-", markdown tables ("|---|")
        - decisions: "j'ai choisi", "plutot que", "plutôt que", "alternatives"
        - issues: "caveat", "issue", "limitation", "broken"
        - rationale: synthesized from decision blocks

    A block can match multiple categories.

    Args:
        blocks: List of text strings.

    Returns:
        Dict with keys: artifacts, decisions, issues, rationale (each a list of strings).
    """
    classified = {
        "artifacts": [],
        "decisions": [],
        "issues": [],
        "rationale": [],
    }

    for block in blocks:
        lower = block.lower()

        # Artifact signals
        if ("=== TASK REPORT ===" in block
                or "Verdict :" in block
                or "REV-" in block
                or "|---|" in block):
            classified["artifacts"].append(block)

        # Decision signals
        if any(kw in lower for kw in [
            "j'ai choisi", "plutot que", "plutôt que", "alternatives"
        ]):
            classified["decisions"].append(block)

        # Issue signals
        if any(kw in lower for kw in [
            "caveat", "issue", "limitation", "broken"
        ]):
            classified["issues"].append(block)

    # Rationale is synthesized from decision blocks
    classified["rationale"] = list(classified["decisions"])

    return classified


def enrich_step(step, blocks):
    """Enrich a CHECKPOINT step with classified transcript content.

    If task or result is shorter than 200 chars, it is replaced with
    the first (task) or last (result) substantial block.

    Classification fields (artifacts, decisions, issues, rationale) are always added.

    The original step dict is not mutated.

    Args:
        step: Dict with agent, claude_session, task, result, etc.
        blocks: List of text strings from parse_jsonl.

    Returns:
        New dict with enriched fields.
    """
    enriched = dict(step)
    classified = classify_blocks(blocks)

    # Enrich task if short
    task = enriched.get("task", "")
    if len(task) < 200 and blocks:
        enriched["task"] = blocks[0]

    # Enrich result if short
    result = enriched.get("result", "")
    if len(result) < 200 and blocks:
        enriched["result"] = blocks[-1]

    # Add classification fields
    enriched["artifacts"] = classified["artifacts"]
    enriched["decisions"] = classified["decisions"]
    enriched["issues"] = classified["issues"]
    enriched["rationale"] = classified["rationale"]

    return enriched


# ---------------------------------------------------------------------------
# CLI helpers
# ---------------------------------------------------------------------------

def _find_transcript(step, home_dir, cwd):
    """Locate the .jsonl transcript file for a given step.

    Args:
        step: Step dict with claude_session and optional parent_session.
        home_dir: HOME directory.
        cwd: Current working directory (used to derive the slug).

    Returns:
        Path to the .jsonl file, or None if not found.
    """
    slug = cwd.replace("/", "-").lstrip("-")
    claude_session = step.get("claude_session", "")
    parent_session = step.get("parent_session")

    base = os.path.join(home_dir, ".claude", "projects", slug)

    if parent_session:
        path = os.path.join(base, parent_session, "subagents", f"{claude_session}.jsonl")
    else:
        path = os.path.join(base, f"{claude_session}.jsonl")

    if os.path.isfile(path):
        return path
    return None


def main():
    parser = argparse.ArgumentParser(description="Enrich CHECKPOINT.yaml with transcript content")
    parser.add_argument("session_id", help="Session ID (e.g., 20260413-223433)")
    parser.add_argument("--step", dest="step_id", help="Only process this claude_session step")
    parser.add_argument("--dry-run", action="store_true", help="Print changes without writing")
    args = parser.parse_args()

    # Resolve paths
    kiss_claw_dir = os.environ.get("KISS_CLAW_DIR", os.path.join(".", ".kiss-claw"))
    home_dir = os.environ.get("HOME", os.path.expanduser("~"))
    cwd = os.getcwd()

    checkpoint_path = os.path.join(kiss_claw_dir, "sessions", args.session_id, "CHECKPOINT.yaml")

    if not os.path.isfile(checkpoint_path):
        print(f"Error: CHECKPOINT not found: {checkpoint_path}", file=sys.stderr)
        sys.exit(1)

    with open(checkpoint_path, "r", encoding="utf-8") as f:
        checkpoint = yaml.safe_load(f)

    modified = False

    for log_entry in checkpoint.get("log", []):
        steps = log_entry.get("steps", [])
        for i, step in enumerate(steps):
            cs = step.get("claude_session", "")

            # If --step specified, skip non-matching steps
            if args.step_id and cs != args.step_id:
                continue

            # Find transcript
            transcript_path = _find_transcript(step, home_dir, cwd)
            if transcript_path is None:
                print(
                    f"Warning: transcript not found for step {cs}",
                    file=sys.stderr,
                )
                continue

            # Parse and enrich
            blocks = parse_jsonl(transcript_path)
            enriched = enrich_step(step, blocks)

            if args.dry_run:
                print(f"[dry-run] Step {cs}:")
                if enriched.get("task") != step.get("task"):
                    print(f"  task: would update ({len(step.get('task', ''))} -> {len(enriched.get('task', ''))} chars)")
                if enriched.get("result") != step.get("result"):
                    print(f"  result: would update ({len(step.get('result', ''))} -> {len(enriched.get('result', ''))} chars)")
                for field in ("artifacts", "decisions", "issues", "rationale"):
                    items = enriched.get(field, [])
                    if items:
                        print(f"  {field}: {len(items)} item(s)")
            else:
                steps[i] = enriched
                modified = True

    if modified and not args.dry_run:
        with open(checkpoint_path, "w", encoding="utf-8") as f:
            yaml.dump(checkpoint, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

    sys.exit(0)


if __name__ == "__main__":
    main()
