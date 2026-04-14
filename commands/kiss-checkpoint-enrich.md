---
name: kiss-checkpoint-enrich
description: Enrich CHECKPOINT.yaml from Claude session transcripts
---

# /kiss-checkpoint-enrich

Extracts verbatim content from Claude session transcripts and enriches
the CHECKPOINT.yaml of the specified kiss-claw session.

## Usage

```
/kiss-checkpoint-enrich <session-id> [--step <claude_session_id>] [--dry-run] [--transcripts-dir <path>]
```

| Mode | Behavior |
|------|----------|
| `<session-id>` only | Batch: enriches ALL steps in the CHECKPOINT |
| `--step <id>` | Single step: enriches only the matching claude_session |
| `--dry-run` | Shows what would change without modifying |
| `--transcripts-dir` | Override transcript location (default: ~/.claude/projects/<slug>) |

## Execution

```bash
cd "$CLAUDE_PLUGIN_ROOT" && python3 scripts/checkpoint_enrich.py $ARGUMENTS
```

$ARGUMENTS
