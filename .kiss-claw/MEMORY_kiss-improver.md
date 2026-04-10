# MEMORY_kiss-improver.md

> kiss-improver-specific learnings. Auto-loaded by kiss-improver agent.
> Keep under 60 lines.

## Session discovery rules

- **Skip current session**: The .jsonl file matching the running kiss-improver session must NOT be analyzed. Detection: it is the most recent .jsonl in the project folder whose first line contains `"type":"user"` with kiss-improver invocation content. When in doubt, check timestamps — the file being actively written to (largest mtime) is the current session.
- **Subagent sessions**: Each parent session ID has a folder `<session-id>/subagents/` containing per-subagent `.jsonl` + `.meta.json` files. The `.meta.json` contains `agentType` (e.g. `kiss-claw:kiss-executor:kiss-executor`) and `description` — this is the authoritative source for identifying which agent ran. Always scan for these folders; they are far more valuable than the parent transcript alone.

## High-signal friction patterns (reliable)

<!-- Transcript signals that reliably indicate a real problem -->

## False positive patterns (suppress)

<!-- Signals that looked like friction but weren't — ignore these -->

## Proposal patterns

- Proposals targeting the wrong MEMORY file are consistently redirected by the user (e.g. MEMORY.md → MEMORY_kiss-orchestrator.md). Always scope proposals to the agent-specific memory file when the insight is about agent behavior.
- Overly specific pitfalls (e.g. exact build-backend string) get rejected — keep proposals at the pattern level, not the instance level.
