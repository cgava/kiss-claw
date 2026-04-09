# kiss-claw

Keep It Simple, Stupid ! The simplest yet ambitious Claude AI harness for code. Stupidly efficient.

Multi-agent Claude Code plugin with persistent state, continuous improvement loop,
checkpointing, dry-run, critical file protection, and token consumption tracking.
Zero external dependencies.

---

## What's New in v5

| Feature | Details |
|---------|---------|
| `PreToolUse` guard | Blocks any unauthorized write to critical files |
| Checkpointing | `/compact` writes `CHECKPOINT.md` before context loss |
| Dry-run mode | `dry-run on/off` — executor describes without writing |
| Token budget | Limit per step, alert on overage |
| Token tracking | Analyzer measures consumption per session → `TOKEN_STATS.md` |

---

## Architecture

```
SessionStart hook
  └─ display menu → wait for keyword → tag session (.poc-session-agent)

orchestrator   plans, STATE.md, delegates, manages dry-run + budget
executor       implements (respects dry-run, stops on budget warn)
verificator    reviews executor outputs → REVIEWS.md
analyzer       analyzes transcripts → INSIGHTS.md + TOKEN_STATS.md

PreToolUse hook  blocks writes to protected files
SessionEnd hook  writes CHECKPOINT.md + updates STATE.md log
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
{ "envVars": { "KISS_CLAW_DIR": "my/custom/path" } }
```

### Uninstall

```bash
claude plugin uninstall kiss-claw@kiss-claw
```

---

## Project Files

```
your-project/
└── .kiss-claw/                  ← all state files (configurable via KISS_CLAW_DIR)
    ├── PLAN.md                  ← roadmap (orchestrator)
    ├── STATE.md                 ← current state + mode + token_budget (orchestrator)
    ├── CHECKPOINT.md            ← pre-compact snapshot (auto hooks)
    ├── MEMORY.md                ← shared context
    ├── MEMORY_orchestrator.md   ┐
    ├── MEMORY_executor.md       ├─ private memory per agent
    ├── MEMORY_verificator.md    │
    ├── MEMORY_analyzer.md       ┘
    ├── INSIGHTS.md              ← improvement proposals (analyzer)
    ├── ANALYZED.md              ← session index + token stats (analyzer)
    ├── TOKEN_STATS.md           ← token consumption ledger (analyzer)
    ├── REVIEWS.md               ← executor review reports (verificator)
    └── SCRATCH.md               ← volatile notes
```

---

## Protected Files (PreToolUse Guard)

These files can only be written by their owning agent.
Any attempt by another agent is blocked before execution:

| File | Owner |
|------|-------|
| `.kiss-claw/PLAN.md` | orchestrator |
| `.kiss-claw/STATE.md` | orchestrator |
| `.kiss-claw/MEMORY.md` | analyzer (via apply) |
| `.kiss-claw/ANALYZED.md` | analyzer |
| `.kiss-claw/INSIGHTS.md` | analyzer |
| `.kiss-claw/TOKEN_STATS.md` | analyzer |
| `.kiss-claw/CHECKPOINT.md` | SessionEnd hook |

---

## Commands

| Command | Agent | Effect |
|---------|-------|--------|
| `mark done` | orchestrator | Validate current step |
| `dry-run on/off` | orchestrator | Toggle executor mode |
| `/compact` | orchestrator | Write CHECKPOINT.md before compact |
| `/analyze` | analyzer | Analyze new transcripts + token consumption |
| `/tokens` | analyzer | Token consumption report without re-analyzing |
| `/insights` | analyzer | Review and apply proposals |

---

## Token Consumption Tracking

After each `/analyze`, `TOKEN_STATS.md` is updated:

```
=== TOKEN CONSUMPTION ===
Sessions tracked : 12
Total tokens     : 187 400  (input: 142 000 / output: 45 400)
Avg / session    : 15 617
Avg tpt          : 312  (tokens per turn)

By agent:
  executor     : avg 22 400 tok/session, avg 480 tpt  [7 sessions]
  orchestrator : avg 8 100 tok/session,  avg 180 tpt  [3 sessions]
  verificator  : avg 6 200 tok/session,  avg 140 tpt  [2 sessions]

Budget violations: 1 over / 2 warn
Most expensive: 2025-04-08 executor — 34 200 tokens (many corrections)
=========================
```

`tokens_per_turn` is the key efficiency indicator: a rising value across multiple
executor sessions signals either context bloat or many corrections — which can itself
generate an improvement proposal in INSIGHTS.md.
