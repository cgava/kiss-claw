# kiss-claw

Multi-agent orchestration plugin for Claude Code. Four specialized agents (orchestrator, executor, verificator, improver) coordinate via persistent state files to plan, implement, review, and improve code — with dry-run mode, token budget tracking, and file protection.

## Folder structure

```
kiss-claw/
  CLAUDE.md                — This file
  agents/                  — Agent definitions (YAML frontmatter + Markdown instructions)
    kiss-orchestrator/     — Planner and coordinator: manages PLAN.md, STATE.md, delegates tasks
    kiss-executor/         — Implementer: executes tasks, respects dry-run and token budgets
    kiss-verificator/      — Reviewer: reviews executor output, writes REVIEWS.md
    kiss-improver/         — Improver: analyzes transcripts, writes INSIGHTS.md, TOKEN_STATS.md
  scripts/                 — Shell scripts
    init.sh                — Project initialization (creates .kiss-claw/ structure)
    store.sh               — Persistence layer (/kiss-store read/write/list/backup)
  hooks/                   — Claude Code lifecycle hooks
    hooks.json             — Hook configuration
    guard.sh               — PreToolUse: protects critical files by owner
    agent-suggest.sh       — Stop: agent routing menu
    session-end.sh         — SessionEnd: checkpoint and state persistence
  templates/               — Templates for MEMORY.md initialization
  commands/                — Slash command definitions (/kiss-store)
  tests/                   — Test framework (Python, stdlib only)
    lib/                   — Test library modules
      runner.py            — Scenario discovery (recursive) and execution engine
      assertions.py        — Assert helpers (exit code, JSON fields, file checks)
      claude_cli.py        — Claude CLI subprocess wrapper with dry-run support
      report.py            — Markdown test report generator
    poc/                   — Proof-of-concept scripts (Phase 2 experiments)
    docker/                — Docker infrastructure for isolated test environments
      Dockerfile           — Test container definition
      entrypoint.sh        — Container entry point
      build-and-test.sh    — Build image and run tests
    scenarios/             — Test scenarios (each in numbered subdirectory)
      01-hello-world/      — Smoke test: basic Claude CLI invocation
      02-konvert-agents/   — Integration test: full agent loop with konvert project
  .kiss-claw/              — Runtime state (created by init.sh, not committed)
    PLAN.md                — Current project plan
    STATE.md               — Execution state and progress
    MEMORY.md              — Shared project context for all agents
    REVIEWS.md             — Code review results from kiss-verificator
    INSIGHTS.md            — Improvement insights from kiss-improver
    TOKEN_STATS.md         — Token consumption tracking
    CHECKPOINT.md          — Session checkpoint data
```

## Key conventions

- **Python stdlib only** for tests — no pip dependencies. Use mandatory `.venv` for isolation.
- **Claude CLI via subprocess only** — no SDK, no API key. OAuth authentication only.
- **Test scenarios**: each is a `test_*.py` file with a `run(ctx)` function. Discovered recursively under `tests/scenarios/`.
- **`--dry-run` flag**: validates imports, paths, and command construction without calling the LLM. Run with `python tests/lib/runner.py --dry-run`.
- **Agent FQDN format**: `kiss-claw:kiss-orchestrator:kiss-orchestrator` (plugin:agent-dir:agent-name).
- **Persistence**: all agents use `/kiss-store` (backed by `scripts/store.sh`) instead of direct file access.
- **Protected files**: PLAN.md, STATE.md, MEMORY.md, REVIEWS.md, INSIGHTS.md, TOKEN_STATS.md, CHECKPOINT.md are owned by specific agents (enforced by guard.sh hook).
- **No external dependencies**: pure shell + Claude agent orchestration. No npm, no pip in production.

## Running tests

```bash
# Dry-run (validates deps/paths, no LLM cost)
python tests/lib/runner.py --dry-run

# Full run (requires Claude CLI with active OAuth session)
python tests/lib/runner.py

# Docker-isolated run
./tests/docker/build-and-test.sh
```
