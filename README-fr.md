# kiss-claw v5

Plugin Claude Code multi-agent avec état persistant, boucle d'amélioration continue,
checkpointing, dry-run, protection des fichiers critiques, et suivi de consommation tokens.
Zéro dépendance externe.

---

## Nouveautés v5

| Feature | Détail |
|---------|--------|
| `PreToolUse` guard | Bloque toute écriture non autorisée sur les fichiers critiques |
| Checkpointing | `/compact` écrit `CHECKPOINT.md` avant perte de contexte |
| Dry-run mode | `dry-run on/off` — executor décrit sans écrire |
| Token budget | Limite par step, alerte si dépassement |
| Token tracking | L'analyzer mesure la conso de chaque session → `TOKEN_STATS.md` |

---

## Architecture

```
SessionStart hook
  └─ affiche menu → attend mot clé → tag session (.poc-session-agent)

orchestrator   planifie, STATE.md, délègue, gère dry-run + budget
executor       implémente (respects dry-run, s'arrête si budget warn)
verificator    review outputs executor → REVIEWS.md
analyzer       analyse transcripts → INSIGHTS.md + TOKEN_STATS.md

PreToolUse hook  bloque écritures sur fichiers protégés
SessionEnd hook  écrit CHECKPOINT.md + update STATE.md log
```

---

## Installation

```bash
git clone <url-du-repo> ~/.claude/plugins/kiss-claw
cp ~/.claude/plugins/kiss-claw/MEMORY.md.template ./MEMORY.md
# Remplir MEMORY.md : nom projet, stack, non-goals
```

Dans `.claude/settings.json` :
```json
{
  "plugins": [{ "type": "local", "path": "~/.claude/plugins/kiss-claw" }]
}
```

---

## Fichiers projet

```
ton-projet/
├── PLAN.md                  ← roadmap (orchestrator)
├── STATE.md                 ← état courant + mode + token_budget (orchestrator)
├── CHECKPOINT.md            ← snapshot pré-compact (hooks auto)
├── MEMORY.md                ← contexte partagé
├── MEMORY_orchestrator.md   ┐
├── MEMORY_executor.md       ├─ mémoire privée par agent
├── MEMORY_verificator.md    │
├── MEMORY_analyzer.md       ┘
├── INSIGHTS.md              ← proposals d'amélioration (analyzer)
├── ANALYZED.md              ← index sessions + token stats (analyzer)
├── TOKEN_STATS.md           ← ledger conso tokens (analyzer)
├── REVIEWS.md               ← rapports review executor (verificator)
└── SCRATCH.md               ← notes volatiles
```

---

## Fichiers protégés (guard PreToolUse)

Ces fichiers ne peuvent être écrits que par leur agent propriétaire.
Toute tentative d'un autre agent est bloquée avant exécution :

| Fichier | Propriétaire |
|---------|-------------|
| `PLAN.md` | orchestrator |
| `STATE.md` | orchestrator |
| `MEMORY.md` | analyzer (via apply) |
| `ANALYZED.md` | analyzer |
| `INSIGHTS.md` | analyzer |
| `TOKEN_STATS.md` | analyzer |
| `CHECKPOINT.md` | hook SessionEnd |

---

## Commandes

| Commande | Agent | Effet |
|----------|-------|-------|
| `mark done` | orchestrator | Valide l'étape courante |
| `dry-run on/off` | orchestrator | Bascule le mode executor |
| `/compact` | orchestrator | Écrit CHECKPOINT.md avant compact |
| `/analyze` | analyzer | Analyse nouveaux transcripts + conso tokens |
| `/tokens` | analyzer | Rapport conso tokens sans re-analyser |
| `/insights` | analyzer | Review et apply des proposals |

---

## Suivi de consommation tokens

Après chaque `/analyze`, `TOKEN_STATS.md` est mis à jour :

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

`tokens_per_turn` est l'indicateur d'efficacité clé : une valeur qui monte sur plusieurs
sessions executor signale soit du context bloat, soit beaucoup de corrections — ce qui
peut lui-même générer une proposal d'amélioration dans INSIGHTS.md.
