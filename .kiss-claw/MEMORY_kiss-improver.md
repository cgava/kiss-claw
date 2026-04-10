# kiss-improver learnings

## False positive patterns (suppress)
- **Pre-store direct edits**: Sessions that predate `/kiss-store` creation will show direct `.kiss-claw/*.md` edits. This is NOT a violation — check session date vs. store.sh creation date before flagging.
- **Parallel delegation claims**: kiss-verificator ALWAYS depends on kiss-executor output. Never classify verificator+executor on the same step as "parallel". The only valid parallelism is: verify step N (completed) while executing step N+1 (new).

## Deferred checks for future runs
- **INS-0002**: Verify that post-store sessions (after 2026-04-10) use `/kiss-store` exclusively for state access. If direct edits still occur, escalate.

## Signal calibration
- Token counts in Claude Code JSONL are low-fidelity (mostly in `usage` fields that may be sparse). Character-based estimation (~4 chars ≈ 1 token) is the fallback.
- Human messages in JSONL: filter out `isMeta: true` and tool_result content to isolate genuine human-typed messages for friction analysis.
