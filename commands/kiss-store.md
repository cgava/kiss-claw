---
name: kiss-store
description: Read, write, and manage kiss-claw persistence resources via store.sh
---

# /kiss-store — Persistence Skill

Thin wrapper around `scripts/store.sh`. All kiss-claw state is accessed through this skill.

## Usage

```
/kiss-store <action> <resource> [content...]
```

## Actions

| Action   | Description                              |
|----------|------------------------------------------|
| `read`   | Print the contents of a resource         |
| `write`  | Overwrite a resource with new content    |
| `append` | Append content to a resource             |
| `update` | Update a single YAML field in a resource |
| `exists` | Check if a resource file exists          |
| `list`   | List all available resources             |

## Resources

`plan` `state` `scratch` `memory` `memory:<agent>` `reviews` `insights` `analyzed` `token-stats` `checkpoint`

## Examples

```bash
# Read the current plan
scripts/store.sh read plan

# Check if scratch exists
scripts/store.sh exists scratch

# List all resources
scripts/store.sh list

# Write content to scratch
scripts/store.sh write scratch "## Notes"

# Append a line to reviews
scripts/store.sh append reviews "- Step 1.2 verified OK"

# Update a field in state
scripts/store.sh update state current_step "1.3 Tests"

# Read agent-specific memory
scripts/store.sh read memory:kiss-executor
```

## Execution

Parse the arguments from `$ARGUMENTS` and delegate to `scripts/store.sh`.

- If `$ARGUMENTS` is empty or the action is unrecognized, show the usage summary above.
- Run the command via Bash and return its stdout.
- If the command exits non-zero, return the stderr output so the caller can see what went wrong.

```bash
cd "$CLAUDE_PLUGIN_ROOT" && bash scripts/store.sh $ARGUMENTS
```

$ARGUMENTS
