# poc-harness v3

Plugin Claude Code multi-agent avec état persistant et boucle d'amélioration continue.
Zéro dépendance. Tout vit dans des fichiers markdown dans le repo.

---

## Architecture

```
┌─────────────────────────────────────────────┐
│              SessionStart hook              │
│  Infère l'agent → confirme → tag session    │
└──────────┬──────────────────────────────────┘
           │
    ┌──────▼──────┐
    │ orchestrator │  planifie, tient STATE.md, délègue
    └──────┬──────┘
           │ délègue
    ┌──────▼──────┐     ┌─────────────┐
    │   executor  │────▶│ verificator │  review outputs,
    │ implémente  │     │  plans, INS │  plans, proposals
    └─────────────┘     └──────┬──────┘
                               │ informe
                        ┌──────▼──────┐
                        │   analyzer  │  analyse transcripts
                        │ améliore    │  propose → INSIGHTS.md
                        └─────────────┘
```

---

## Installation

```bash
tar xzf poc-harness-v3.tar.gz -C ~/.claude/plugins/
```

Dans `.claude/settings.json` du projet :
```json
{
  "plugins": [
    { "type": "local", "path": "~/.claude/plugins/poc-harness-v3" }
  ]
}
```

Copier les templates dans le projet :
```bash
cp ~/.claude/plugins/poc-harness-v3/MEMORY.md.template ./MEMORY.md
# Éditer MEMORY.md avec le nom du projet et la stack
# Les MEMORY_<agent>.md sont créés automatiquement au premier besoin
```

---

## Routing au démarrage de session

À chaque session, Claude infère l'agent cible depuis le premier message :

**Inférence claire** → confirmation automatique :
```
→ routing to executor (change? reply with: orchestrator / executor / verificator / analyzer / general)
executor ready — last task: implement /auth endpoint
```

**Inférence ambiguë** → menu de sélection :
```
→ Which agent should handle this?
  [1] orchestrator — planning & state
  [2] executor     — implementation
  [3] verificator  — review
  [4] analyzer     — improvement loop
  [5] general      — no specific agent
```

**Choix `general`** → session non taggée, améliorations limitées à `CLAUDE.md`, `MEMORY.md`, `settings.json`.

---

## Fichiers projet

```
ton-projet/
├── PLAN.md                  ← roadmap (orchestrator)
├── STATE.md                 ← état courant (orchestrator)
├── MEMORY.md                ← contexte partagé (tous les agents)
├── MEMORY_orchestrator.md   ← apprentissages orchestrator
├── MEMORY_executor.md       ← apprentissages executor
├── MEMORY_verificator.md    ← apprentissages verificator
├── MEMORY_analyzer.md       ← apprentissages analyzer
├── INSIGHTS.md              ← propositions d'amélioration (analyzer)
├── ANALYZED.md              ← index sessions analysées (analyzer)
├── REVIEWS.md               ← rapports de review (verificator)
└── SCRATCH.md               ← notes volatiles (tous)
```

---

## Boucle d'amélioration

### 1. Analyser les sessions
```
/analyzer  (ou: "analyze history")
```
L'analyzer scanne les transcripts nouveaux, identifie l'agent de chaque session,
extrait des signaux, et propose des changements **scoped à l'agent concerné**.

### 2. Scope des proposals par type de session

| Session agent | Targets autorisés |
|--------------|-------------------|
| `orchestrator` | `agent:orchestrator`, `MEMORY_orchestrator.md`, `PLAN.md` |
| `executor` | `agent:executor`, `MEMORY_executor.md`, `CLAUDE.md` |
| `verificator` | `agent:verificator`, `MEMORY_verificator.md` |
| `analyzer` | `agent:analyzer`, `MEMORY_analyzer.md` |
| `general` | `CLAUDE.md`, `MEMORY.md`, `settings.json` uniquement |

### 3. Review et apply
```
/verificator  → "review INS-0003"   (optionnel mais recommandé)
/analyzer     → "accept #INS-0003"
              → "apply #INS-0003"
```
L'analyzer montre le diff, demande confirmation, écrit le fichier.

---

## Cycle complet d'une phase

```
orchestrator : init phase → découpe en steps
    ↓
executor     : implémente step par step
    ↓
verificator  : review output de chaque step → REVIEWS.md
    ↓
orchestrator : lit les reviews, marque done / rework
    ↓
(fin de phase)
    ↓
analyzer     : analyse les transcripts de la phase
             → INSIGHTS.md (scoped par agent)
    ↓
verificator  : review les proposals de l'analyzer
    ↓
analyzer     : apply proposals acceptées
    ↓
orchestrator : log dans STATE.md → démarrer phase suivante
```
