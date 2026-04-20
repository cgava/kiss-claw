# kiss-claw

Keep It Simple, Stupid ! The simplest yet ambitious Claude AI harness for code. Stupidly efficient.

Multi-agent Claude Code plugin with persistent state, continuous improvement loop,
checkpointing, dry-run, critical file protection, and multi-session support.
Zero external dependencies.

---

## What's New in v7

| Feature | Details |
|---------|---------|
| Multi-session persistence | Each session gets its own directory under `.kiss-claw/sessions/` |
| 3-folder structure | State split into `agents/`, `project/`, and `sessions/` subdirectories |
| Session management | `KISS_CLAW_SESSION` env var, `list sessions`, `resume` support |
| Configurable paths | Each subdirectory overridable via dedicated env vars |

<details>
<summary>v6 features</summary>

| Feature | Details |
|---------|---------|
| `/kiss-store` persistence | All agents use `scripts/store.sh` for reads/writes — no more direct file access |
| Backup on write | Every state file write creates an automatic backup |
| Centralized I/O | Single entry point for all persistence operations (read, write, list, backup) |

</details>

<details>
<summary>v5 features</summary>

| Feature | Details |
|---------|---------|
| `PreToolUse` guard | Blocks any unauthorized write to critical files |
| Checkpointing | `/compact` writes `CHECKPOINT.md` before context loss |
| Dry-run mode | `dry-run on/off` — kiss-executor describes without writing |
| Token budget | Limit per step, alert on overage |

</details>

---

## Architecture

```
SessionStart hook
  └─ display menu → wait for keyword → tag session (.poc-session-agent)

kiss-orchestrator   plans, STATE.md, delegates, manages dry-run + budget
kiss-executor       implements (respects dry-run, stops on budget warn)
kiss-verificator    reviews kiss-executor outputs → REVIEWS.md
kiss-improver       analyzes transcripts → INSIGHTS.md

/kiss-store          centralized persistence layer (scripts/store.sh)
PreToolUse hook      blocks writes to protected files
SessionEnd hook      writes CHECKPOINT.md + updates STATE.md log
```

---

## Installation

### From marketplace

```bash
# Add the marketplace (once)
/plugin marketplace add cedricmusic/kiss-claw

# Install
claude plugin install kiss-claw@kiss-claw
```

### Init a project

```bash
cd your-project
~/.claude/plugins/kiss-claw/scripts/init.sh
# Edit .kiss-claw/MEMORY.md with your project info
```

### Dev mode

```bash
# Load the plugin directly from your local clone
claude --plugin-dir /path/to/kiss-claw

# Reload after changes without restarting
/reload-plugins
```

### Custom output directory

By default, state files live in `.kiss-claw/` at project root.
Override via `.claude/settings.local.json`:

```json
{
  "envVars": {
    "KISS_CLAW_DIR": "my/custom/path",
    "KISS_CLAW_AGENTS_DIR": "my/custom/path/agents",
    "KISS_CLAW_PROJECT_DIR": "my/custom/path/project",
    "KISS_CLAW_SESSIONS_DIR": "my/custom/path/sessions"
  }
}
```

Each subdirectory can be overridden independently — useful for symlinking
agent memories or project data to a shared location across repos.

### Uninstall

```bash
claude plugin uninstall kiss-claw@kiss-claw
```

---

## Project Files

```
your-project/
└── .kiss-claw/                          ← root state directory (configurable via KISS_CLAW_DIR)
    ├── agents/                          ← agent memories (configurable via KISS_CLAW_AGENTS_DIR)
    │   ├── MEMORY_kiss-orchestrator.md  ┐
    │   ├── MEMORY_kiss-executor.md      ├─ private memory per agent
    │   ├── MEMORY_kiss-verificator.md   │
    │   ├── MEMORY_kiss-improver.md      ┘
    │   ├── INSIGHTS.md                  ← improvement proposals (kiss-improver)
    │   └── ANALYZED.md                  ← session index (kiss-improver)
    ├── project/                         ← project data (configurable via KISS_CLAW_PROJECT_DIR)
    │   ├── MEMORY.md                    ← shared context
    │   ├── ISSUES.md                    ← project issues tracking
    │   └── SESSIONS.json                ← session registry
    └── sessions/                        ← session data (configurable via KISS_CLAW_SESSIONS_DIR)
        └── 20260413-153022/             ← individual session (YYYYMMDD-HHmmss)
            ├── PLAN.md                  ← session plan (kiss-orchestrator)
            ├── STATE.md                 ← execution state + mode (kiss-orchestrator)
            ├── REVIEWS.md               ← review reports (kiss-verificator)
            ├── SCRATCH.md               ← volatile notes
            └── CHECKPOINT.md            ← pre-compact snapshot (auto hooks)
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `KISS_CLAW_DIR` | `.kiss-claw` | Root state directory |
| `KISS_CLAW_AGENTS_DIR` | `$KISS_CLAW_DIR/agents` | Agent memories and insights |
| `KISS_CLAW_PROJECT_DIR` | `$KISS_CLAW_DIR/project` | Project-level shared data |
| `KISS_CLAW_SESSIONS_DIR` | `$KISS_CLAW_DIR/sessions` | Session directories |
| `KISS_CLAW_SESSION` | _(auto-created)_ | Active session ID (YYYYMMDD-HHmmss) |

---

## Protected Files (PreToolUse Guard)

These files can only be written by their owning agent.
Any attempt by another agent is blocked before execution:

| File | Scope | Owner |
|------|-------|-------|
| `sessions/<id>/PLAN.md` | session | kiss-orchestrator |
| `sessions/<id>/STATE.md` | session | kiss-orchestrator |
| `sessions/<id>/REVIEWS.md` | session | kiss-verificator |
| `sessions/<id>/CHECKPOINT.md` | session | SessionEnd hook |
| `project/MEMORY.md` | project | kiss-improver (via apply) |
| `agents/ANALYZED.md` | agent | kiss-improver |
| `agents/INSIGHTS.md` | agent | kiss-improver |

---

## Commands

| Command | Agent | Effect |
|---------|-------|--------|
| `mark done` | kiss-orchestrator | Validate current step |
| `dry-run on/off` | kiss-orchestrator | Toggle kiss-executor mode |
| `/compact` | kiss-orchestrator | Write CHECKPOINT.md before compact |
| `/kiss-store` | all agents | Persistence operations (read/write/list/backup) |
| `/analyze` | kiss-improver | Analyze new transcripts |
| `/insights` | kiss-improver | Review and apply proposals |

---

## Multi-Session Support

Each kiss-claw session creates its own directory under `.kiss-claw/sessions/` with a
timestamp-based ID (YYYYMMDD-HHmmss). This keeps session-specific state (plan, progress,
reviews) isolated while agent memories and project data persist across sessions.

- **New session**: automatically created on init, or set `KISS_CLAW_SESSION` explicitly.
- **List sessions**: `/kiss-store list sessions` shows all available sessions.
- **Resume session**: set `KISS_CLAW_SESSION=<id>` to resume a previous session.

