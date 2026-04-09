# kiss-claw

Plugin Claude Code multi-agent avec état persistant, boucle d'amélioration continue,
checkpointing, dry-run, protection des fichiers critiques, et suivi de consommation tokens.
Zéro dépendance externe.

Keep It Simple, Stupid ! The simplest yet ambitious Claude AI harness for code. Stupidly efficient.

---

## Nouveautés v5

| Feature | Détail |
|---------|--------|
| `PreToolUse` guard | Bloque toute écriture non autorisée sur les fichiers critiques |
| Checkpointing | `/compact` écrit `CHECKPOINT.md` avant perte de contexte |
| Dry-run mode | `dry-run on/off` — kiss-executor décrit sans écrire |
| Token budget | Limite par step, alerte si dépassement |
| Token tracking | Le kiss-improver mesure la conso de chaque session → `TOKEN_STATS.md` |

---

## Architecture

```
SessionStart hook
  └─ affiche menu → attend mot clé → tag session (.poc-session-agent)

kiss-orchestrator   planifie, STATE.md, délègue, gère dry-run + budget
kiss-executor       implémente (respects dry-run, s'arrête si budget warn)
kiss-verificator    review outputs kiss-executor → REVIEWS.md
kiss-improver       analyse transcripts → INSIGHTS.md + TOKEN_STATS.md

PreToolUse hook  bloque écritures sur fichiers protégés
SessionEnd hook  écrit CHECKPOINT.md + update STATE.md log
```

---

## Installation

### Depuis la marketplace

```bash
# Ajouter la marketplace (une fois)
/plugin marketplace add cgava/kiss-claw

# Installer
claude plugin install kiss-claw@kiss-claw
```

### Init d'un projet

```bash
cd mon-projet
~/.claude/plugins/kiss-claw/scripts/init.sh
# Éditer .kiss-claw/MEMORY.md avec les infos du projet
```

### Mode dev

```bash
# Charger le plugin directement depuis votre clone local
claude --plugin-dir /chemin/vers/kiss-claw

# Recharger après modifs sans redémarrer
/reload-plugins
```

### Dossier de sortie personnalisé

Par défaut, les fichiers d'état vivent dans `.kiss-claw/` à la racine du projet.
Surcharger via `.claude/settings.local.json` :

```json
{ "envVars": { "KISS_CLAW_DIR": "mon/chemin/custom" } }
```

### Désinstallation

```bash
claude plugin uninstall kiss-claw@kiss-claw
```

---

## Fichiers projet

```
ton-projet/
└── .kiss-claw/                          ← tous les fichiers d'état (configurable via KISS_CLAW_DIR)
    ├── PLAN.md                          ← roadmap (kiss-orchestrator)
    ├── STATE.md                         ← état courant + mode + token_budget (kiss-orchestrator)
    ├── CHECKPOINT.md                    ← snapshot pré-compact (hooks auto)
    ├── MEMORY.md                        ← contexte partagé
    ├── MEMORY_kiss-orchestrator.md      ┐
    ├── MEMORY_kiss-executor.md          ├─ mémoire privée par agent
    ├── MEMORY_kiss-verificator.md       │
    ├── MEMORY_kiss-improver.md          ┘
    ├── INSIGHTS.md                      ← proposals d'amélioration (kiss-improver)
    ├── ANALYZED.md                      ← index sessions + token stats (kiss-improver)
    ├── TOKEN_STATS.md                   ← ledger conso tokens (kiss-improver)
    ├── REVIEWS.md                       ← rapports review kiss-executor (kiss-verificator)
    └── SCRATCH.md                       ← notes volatiles
```

---

## Fichiers protégés (guard PreToolUse)

Ces fichiers ne peuvent être écrits que par leur agent propriétaire.
Toute tentative d'un autre agent est bloquée avant exécution :

| Fichier | Propriétaire |
|---------|-------------|
| `.kiss-claw/PLAN.md` | kiss-orchestrator |
| `.kiss-claw/STATE.md` | kiss-orchestrator |
| `.kiss-claw/MEMORY.md` | kiss-improver (via apply) |
| `.kiss-claw/ANALYZED.md` | kiss-improver |
| `.kiss-claw/INSIGHTS.md` | kiss-improver |
| `.kiss-claw/TOKEN_STATS.md` | kiss-improver |
| `.kiss-claw/CHECKPOINT.md` | hook SessionEnd |

---

## Commandes

| Commande | Agent | Effet |
|----------|-------|-------|
| `mark done` | kiss-orchestrator | Valide l'étape courante |
| `dry-run on/off` | kiss-orchestrator | Bascule le mode kiss-executor |
| `/compact` | kiss-orchestrator | Écrit CHECKPOINT.md avant compact |
| `/analyze` | kiss-improver | Analyse nouveaux transcripts + conso tokens |
| `/tokens` | kiss-improver | Rapport conso tokens sans re-analyser |
| `/insights` | kiss-improver | Review et apply des proposals |

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
  kiss-executor     : avg 22 400 tok/session, avg 480 tpt  [7 sessions]
  kiss-orchestrator : avg 8 100 tok/session,  avg 180 tpt  [3 sessions]
  kiss-verificator  : avg 6 200 tok/session,  avg 140 tpt  [2 sessions]

Budget violations: 1 over / 2 warn
Most expensive: 2025-04-08 kiss-executor — 34 200 tokens (many corrections)
=========================
```

`tokens_per_turn` est l'indicateur d'efficacité clé : une valeur qui monte sur plusieurs
sessions kiss-executor signale soit du context bloat, soit beaucoup de corrections — ce qui
peut lui-même générer une proposal d'amélioration dans INSIGHTS.md.
