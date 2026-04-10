# MEMORY.md — shared project context

> Auto-loaded by all agents. Keep under 200 lines.
> Edit manually or via kiss-improver apply protocol.

## Project

- **Name**: kiss-claw
- **Goal**: Plugin Claude Code multi-agent avec état persistant, boucle d'amélioration continue, checkpointing, dry-run, protection des fichiers critiques, et suivi de consommation tokens. Zéro dépendance externe.
- **Tagline**: Keep It Simple, Stupid! The simplest yet ambitious Claude AI harness for code. Stupidly efficient.
- **Version**: 6.0.0
- **Repo**: https://github.com/ccgava/kiss-claw
- **License**: MIT
- **Status**: v6.0 stable — persistence skills layer via /kiss-store

## Tech stack

- Language: Bash (scripts, hooks) + Markdown (agents, templates, état)
- YAML frontmatter dans les fichiers agent (`agents/*/agent.md`)
- Plugin system: Claude Code native (`.claude-plugin/plugin.json`)
- Aucune dépendance externe — pure shell + Claude agent orchestration

## Architecture

```
.claude-plugin/plugin.json     ← metadata plugin (name, version)
agents/                        ← définitions agents (4 agents)
  kiss-orchestrator/agent.md   ← planificateur & coordinateur
  kiss-executor/agent.md       ← implémentation
  kiss-verificator/agent.md    ← review code
  kiss-improver/agent.md       ← boucle d'amélioration + tokens
commands/                      ← commandes slash (activation agents)
hooks/                         ← hooks lifecycle
  hooks.json                   ← config hooks
  guard.sh                     ← PreToolUse (protection fichiers)
  session-end.sh               ← SessionEnd (checkpoint + state)
  agent-suggest.sh             ← Stop (menu routing agents)
scripts/init.sh                ← initialisation projet
scripts/store.sh               ← persistence layer (read/write/list/backup)
commands/kiss-store.md         ← /kiss-store slash command
templates/                     ← templates MEMORY pour init
tests/                         ← test suite (test-store.sh)
```

## Fichiers protégés (guard PreToolUse)

| Fichier | Propriétaire |
|---------|-------------|
| `PLAN.md` | kiss-orchestrator |
| `STATE.md` | kiss-orchestrator |
| `MEMORY.md` | kiss-improver (via apply) |
| `ANALYZED.md` | kiss-improver |
| `INSIGHTS.md` | kiss-improver |
| `TOKEN_STATS.md` | kiss-improver |
| `CHECKPOINT.md` | hook SessionEnd |

## Non-goals

- Dépendances externes (npm, pip, etc.)
- Support d'autres LLM que Claude
- UI graphique

## Agents in use

- kiss-orchestrator — planning, state, délégation, dry-run, budget
- kiss-executor — implémentation (respecte dry-run, s'arrête si budget warn, utilise /kiss-store)
- kiss-verificator — review outputs kiss-executor → REVIEWS.md (utilise /kiss-store)
- kiss-improver — analyse transcripts → INSIGHTS.md + TOKEN_STATS.md (utilise /kiss-store)

## Known broken

- **Hooks** (guard.sh, session-end.sh, agent-suggest.sh) — ne fonctionnent pas du tout. Marques broken, seront repares ulterieurement (voir ISSUE-005).

## Ordre de priorite issues

1. ISSUE-002 (tests Docker) — tres haute, prerequis pour valider le reste
2. ISSUE-001 (gestion issues via kiss-store)
3. Reste a prioriser

## Key decisions

- 2026-04-09 — Bootstrap : kiss-claw s'utilise lui-même pour évoluer
- v6.0 — Persistence skills layer : tous les agents utilisent /kiss-store (scripts/store.sh) au lieu d'accès fichiers directs
- v5.1 — Commandes slash natives remplacent les hooks d'activation agents
- v5 — PreToolUse guard, checkpointing, dry-run, token budget/tracking
- v3 — Architecture multi-agent fondation
