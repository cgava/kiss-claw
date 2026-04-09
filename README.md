# poc-harness v4

Plugin Claude Code multi-agent avec état persistant et boucle d'amélioration continue.
Zéro dépendance. Tout vit dans des fichiers markdown dans le repo.

---

## Architecture

```
┌─────────────────────────────────────────┐
│           SessionStart hook             │
│  Affiche le menu → attend un mot clé   │
│  Tag la session avec l'agent choisi     │
└──────────┬──────────────────────────────┘
           │
    ┌──────▼──────┐
    │ orchestrator │  planifie, tient STATE.md, délègue
    └──────┬──────┘
           │ délègue les tâches
    ┌──────▼──────┐     ┌─────────────┐
    │   executor  │────▶│ verificator │  review outputs
    │ implémente  │     │ executor    │  uniquement
    └─────────────┘     └─────────────┘
                               │ informe orchestrator
                        ┌──────▼──────┐
                        │   analyzer  │  analyse transcripts
                        │             │  → INSIGHTS.md
                        └─────────────┘
                               │
                          humain décide
                         accept/reject/apply
```

---

## Installation

```bash
tar xzf poc-harness-v4.tar.gz -C ~/.claude/plugins/
```

Dans `.claude/settings.json` du projet :
```json
{
  "plugins": [
    { "type": "local", "path": "~/.claude/plugins/poc-harness-v4" }
  ]
}
```

Copier et remplir le template mémoire :
```bash
cp ~/.claude/plugins/poc-harness-v4/MEMORY.md.template ./MEMORY.md
# Remplir : nom du projet, stack, non-goals
```

---

## Routing au démarrage de chaque session

Claude affiche toujours le menu et attend un mot clé — pas d'inférence automatique :

```
→ Which agent for this session?
  orchestrator — planning, state, phase tracking
  executor     — implementation, code, files, commands
  verificator  — review executor outputs
  analyzer     — improvement loop, analyze history
  general      — no specific agent
```

Taper le mot clé (ou un préfixe non-ambigu : `orch`, `exec`, `verif`, `ana`, `gen`).

```
→ executor activated
executor ready — last task: implement /auth endpoint
```

Si **general** → session non taggée → l'analyzer ne pourra proposer des changements que
sur `CLAUDE.md`, `MEMORY.md`, `settings.json` — jamais sur les agents.

---

## Fichiers projet

```
ton-projet/
├── PLAN.md                  ← roadmap immuable (orchestrator)
├── STATE.md                 ← état courant (orchestrator)
├── MEMORY.md                ← contexte partagé (tous les agents)
├── MEMORY_orchestrator.md   ← apprentissages orchestrator
├── MEMORY_executor.md       ← apprentissages executor (stack, conventions, erreurs)
├── MEMORY_verificator.md    ← apprentissages verificator (patterns récurrents)
├── MEMORY_analyzer.md       ← apprentissages analyzer (signaux fiables vs faux positifs)
├── INSIGHTS.md              ← propositions d'amélioration (analyzer)
├── ANALYZED.md              ← index sessions analysées — évite les doublons
├── REVIEWS.md               ← rapports de review executor (verificator)
└── SCRATCH.md               ← notes volatiles de session
```

---

## Périmètre de chaque agent

| Agent | Fait | Ne fait pas | Écrit dans |
|-------|------|-------------|------------|
| orchestrator | planifie, délègue, tient l'état | implémente, review | STATE.md, PLAN.md |
| executor | implémente les tâches | planifie, review | fichiers du projet |
| verificator | review outputs executor | planifie, implémente, review proposals | REVIEWS.md |
| analyzer | analyse transcripts, propose améliorations | implémente, review code | INSIGHTS.md, ANALYZED.md |

---

## Cycle complet d'une phase

```
orchestrator : découpe la phase en steps
    ↓
executor     : implémente step par step → task report
    ↓
verificator  : review l'output executor → REVIEWS.md
    ↓
orchestrator : lit REVIEWS.md, marque done / rework
    ↓
(fin de phase)
    ↓
analyzer     : analyse les transcripts de la phase
             → INSIGHTS.md (scoped par agent de session)
    ↓
humain       : /insights → accept / reject / defer
             → apply #N → diff → confirme
    ↓
orchestrator : log dans STATE.md → démarre phase suivante
```

---

## Boucle d'amélioration — scope des proposals

L'analyzer tague chaque transcript avec l'agent de la session (via `.poc-session-agent`).
Les proposals sont strictement scopées :

| Session agent | Targets autorisés |
|--------------|-------------------|
| `orchestrator` | `agent:orchestrator`, `MEMORY_orchestrator.md`, `PLAN.md` |
| `executor` | `agent:executor`, `MEMORY_executor.md`, `CLAUDE.md` |
| `verificator` | `agent:verificator`, `MEMORY_verificator.md` |
| `analyzer` | `agent:analyzer`, `MEMORY_analyzer.md` |
| `general` | `CLAUDE.md`, `MEMORY.md`, `settings.json` uniquement |

Proposer de modifier un agent depuis une session `general` = violation de scope,
flaggée automatiquement avec confidence `low`.

---

## Mémoire des agents

Chaque agent charge automatiquement :
- `MEMORY.md` — contexte partagé (stack, goal, décisions clés)
- `MEMORY_<agent>.md` — apprentissages privés de l'agent

Les fichiers `MEMORY_<agent>.md` sont créés au premier besoin par l'agent ou l'analyzer.
Templates disponibles dans `MEMORY_agents.md.template`.
