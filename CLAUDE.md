# kiss-claw

Multi-agent orchestration plugin for Claude Code. Four specialized agents (orchestrator, executor, verificator, improver) coordinate via persistent state files to plan, implement, review, and improve code — with dry-run mode, multi-session support, and file protection.

## Folder structure

```
kiss-claw/
  CLAUDE.md                — This file
  agents/                  — Agent definitions (YAML frontmatter + Markdown instructions)
    kiss-orchestrator/     — Planner and coordinator: manages PLAN.md, STATE.md, delegates tasks
    kiss-executor/         — Implementer: executes tasks, respects dry-run and token budgets
    kiss-verificator/      — Reviewer: reviews executor output, writes REVIEWS.md
    kiss-improver/         — Improver: analyzes transcripts, writes INSIGHTS.md
  scripts/                 — Shell scripts
    init.sh                — Project initialization (creates .kiss-claw/ structure)
    store.sh               — Persistence layer (/kiss-store read/write/list)
    sync-sessions.sh       — Sync Claude Code sessions to .kiss-claw/claude-sessions/
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
    agents/                — Agent memories (configurable via KISS_CLAW_AGENTS_DIR)
      MEMORY_kiss-orchestrator.md
      MEMORY_kiss-executor.md
      MEMORY_kiss-verificator.md
      MEMORY_kiss-improver.md
      INSIGHTS.md          — Improvement insights from kiss-improver
      ANALYZED.md          — Session index (kiss-improver)
    project/               — Project data (configurable via KISS_CLAW_PROJECT_DIR)
      MEMORY.md            — Shared project context for all agents
      ISSUES.md            — Project issues tracking
      SESSIONS.json        — Session registry
    claude-sessions/       — Synced Claude Code session transcripts (.jsonl)
    sessions/              — Session data (configurable via KISS_CLAW_SESSIONS_DIR)
      20260413-153022/     — Individual session (YYYYMMDD-HHmmss format)
        PLAN.md            — Session plan
        STATE.md           — Execution state and progress
        REVIEWS.md         — Code review results from kiss-verificator
        SCRATCH.md         — Volatile notes
        CHECKPOINT.md      — Session checkpoint data
```

## Key conventions

- **Python stdlib only** for tests — no pip dependencies. Use mandatory `.venv` for isolation.
- **Claude CLI via subprocess only** — no SDK, no API key. OAuth authentication only.
- **Test scenarios**: each is a `test_*.py` file with a `run(ctx)` function. Discovered recursively under `tests/scenarios/`.
- **`--dry-run` flag**: validates imports, paths, and command construction without calling the LLM. Run with `python tests/lib/runner.py --dry-run`.
- **Agent FQDN format**: `kiss-claw:kiss-orchestrator:kiss-orchestrator` (plugin:agent-dir:agent-name).
- **Persistence**: all agents use `/kiss-store` (backed by `scripts/store.sh`) instead of direct file access. Resources are scoped to three categories: agent-scoped, project-scoped, and session-scoped.
- **Multi-session**: each session gets its own directory under `.kiss-claw/sessions/`. Set `KISS_CLAW_SESSION` to target a specific session. Use `/kiss-store list sessions` to browse sessions.
- **Protected files**: PLAN.md, STATE.md, MEMORY.md, REVIEWS.md, INSIGHTS.md, CHECKPOINT.md are owned by specific agents (enforced by guard.sh hook).
- **Environment variables**: `KISS_CLAW_DIR` (root), `KISS_CLAW_AGENTS_DIR`, `KISS_CLAW_PROJECT_DIR`, `KISS_CLAW_SESSIONS_DIR` (subdirectories), `KISS_CLAW_SESSION` (active session ID).
- **No external dependencies**: pure shell + Claude agent orchestration. No npm, no pip in production.

## Session sync

```bash
# Sync Claude sessions to project
./scripts/sync-sessions.sh

# Sync + clean source sessions
./scripts/sync-sessions.sh --clean

# Dry-run (show what would be synced/cleaned)
./scripts/sync-sessions.sh --dry-run
```

Sessions are copied to `.kiss-claw/claude-sessions/`. Use CHECKPOINT.yaml `claude_session` fields to cross-reference.

## Running tests

```bash
# Dry-run (validates deps/paths, no LLM cost)
python tests/lib/runner.py --dry-run

# Full run (requires Claude CLI with active OAuth session)
python tests/lib/runner.py

# Docker-isolated run
./tests/docker/build-and-test.sh
```
