# kiss-claw

Plugin Claude Code multi-agent avec état persistant, boucle d'amélioration continue,
checkpointing, dry-run, protection des fichiers critiques, et support multi-session.
Zéro dépendance externe.

Keep It Simple, Stupid ! The simplest yet ambitious Claude AI harness for code. Stupidly efficient.

---

## Nouveautés v7

| Feature | Détail |
|---------|--------|
| Persistance multi-session | Chaque session a son propre dossier sous `.kiss-claw/sessions/` |
| Structure 3 dossiers | État réparti en `agents/`, `project/`, et `sessions/` |
| Gestion des sessions | Variable `KISS_CLAW_SESSION`, `list sessions`, support `resume` |
| Chemins configurables | Chaque sous-dossier surchargeable via variable d'environnement dédiée |

<details>
<summary>Nouveautés v6</summary>

| Feature | Détail |
|---------|--------|
| Persistance `/kiss-store` | Tous les agents utilisent `scripts/store.sh` pour les lectures/écritures |
| Backup on write | Chaque écriture crée un backup automatique |
| I/O centralisé | Point d'entrée unique pour toutes les opérations de persistance |

</details>

<details>
<summary>Nouveautés v5</summary>

| Feature | Détail |
|---------|--------|
| `PreToolUse` guard | Bloque toute écriture non autorisée sur les fichiers critiques |
| Checkpointing | `/compact` écrit `CHECKPOINT.md` avant perte de contexte |
| Dry-run mode | `dry-run on/off` — kiss-executor décrit sans écrire |
| Token budget | Limite par step, alerte si dépassement |

</details>

---

## Architecture

```
SessionStart hook
  └─ affiche menu → attend mot clé → tag session (.poc-session-agent)

kiss-orchestrator   planifie, STATE.md, délègue, gère dry-run + budget
kiss-executor       implémente (respects dry-run, s'arrête si budget warn)
kiss-verificator    review outputs kiss-executor → REVIEWS.md
kiss-improver       analyse transcripts → INSIGHTS.md

/kiss-store          couche de persistance centralisée (scripts/store.sh)
PreToolUse hook      bloque écritures sur fichiers protégés
SessionEnd hook      écrit CHECKPOINT.md + update STATE.md log
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
{
  "envVars": {
    "KISS_CLAW_DIR": "mon/chemin/custom",
    "KISS_CLAW_AGENTS_DIR": "mon/chemin/custom/agents",
    "KISS_CLAW_PROJECT_DIR": "mon/chemin/custom/project",
    "KISS_CLAW_SESSIONS_DIR": "mon/chemin/custom/sessions"
  }
}
```

Chaque sous-dossier peut être surchargé indépendamment -- utile pour créer des
symlinks vers un emplacement partagé entre repos.

### Désinstallation

```bash
claude plugin uninstall kiss-claw@kiss-claw
```

---

## Fichiers projet

```
ton-projet/
└── .kiss-claw/                          ← dossier racine (configurable via KISS_CLAW_DIR)
    ├── agents/                          ← mémoires agents (configurable via KISS_CLAW_AGENTS_DIR)
    │   ├── MEMORY_kiss-orchestrator.md  ┐
    │   ├── MEMORY_kiss-executor.md      ├─ mémoire privée par agent
    │   ├── MEMORY_kiss-verificator.md   │
    │   ├── MEMORY_kiss-improver.md      ┘
    │   ├── INSIGHTS.md                  ← proposals d'amélioration (kiss-improver)
    │   └── ANALYZED.md                  ← index sessions (kiss-improver)
    ├── project/                         ← données projet (configurable via KISS_CLAW_PROJECT_DIR)
    │   ├── MEMORY.md                    ← contexte partagé
    │   ├── ISSUES.md                    ← suivi des issues projet
    │   └── SESSIONS.json                ← registre des sessions
    └── sessions/                        ← données session (configurable via KISS_CLAW_SESSIONS_DIR)
        └── 20260413-153022/             ← session individuelle (YYYYMMDD-HHmmss)
            ├── PLAN.md                  ← plan de session (kiss-orchestrator)
            ├── STATE.md                 ← état courant + mode (kiss-orchestrator)
            ├── REVIEWS.md               ← rapports review (kiss-verificator)
            ├── SCRATCH.md               ← notes volatiles
            └── CHECKPOINT.md            ← snapshot pré-compact (hooks auto)
```

### Variables d'environnement

| Variable | Défaut | Description |
|----------|--------|-------------|
| `KISS_CLAW_DIR` | `.kiss-claw` | Dossier racine |
| `KISS_CLAW_AGENTS_DIR` | `$KISS_CLAW_DIR/agents` | Mémoires et insights agents |
| `KISS_CLAW_PROJECT_DIR` | `$KISS_CLAW_DIR/project` | Données partagées du projet |
| `KISS_CLAW_SESSIONS_DIR` | `$KISS_CLAW_DIR/sessions` | Dossiers de sessions |
| `KISS_CLAW_SESSION` | _(auto-créé)_ | ID de session active (YYYYMMDD-HHmmss) |

---

## Fichiers protégés (guard PreToolUse)

Ces fichiers ne peuvent être écrits que par leur agent propriétaire.
Toute tentative d'un autre agent est bloquée avant exécution :

| Fichier | Scope | Propriétaire |
|---------|-------|-------------|
| `sessions/<id>/PLAN.md` | session | kiss-orchestrator |
| `sessions/<id>/STATE.md` | session | kiss-orchestrator |
| `sessions/<id>/REVIEWS.md` | session | kiss-verificator |
| `sessions/<id>/CHECKPOINT.md` | session | hook SessionEnd |
| `project/MEMORY.md` | projet | kiss-improver (via apply) |
| `agents/ANALYZED.md` | agent | kiss-improver |
| `agents/INSIGHTS.md` | agent | kiss-improver |

---

## Commandes

| Commande | Agent | Effet |
|----------|-------|-------|
| `mark done` | kiss-orchestrator | Valide l'étape courante |
| `dry-run on/off` | kiss-orchestrator | Bascule le mode kiss-executor |
| `/compact` | kiss-orchestrator | Écrit CHECKPOINT.md avant compact |
| `/kiss-store` | tous les agents | Opérations de persistance (read/write/list/backup) |
| `/analyze` | kiss-improver | Analyse nouveaux transcripts |
| `/insights` | kiss-improver | Review et apply des proposals |

---

## Support multi-session

Chaque session kiss-claw crée son propre dossier sous `.kiss-claw/sessions/` avec un
identifiant horodaté (YYYYMMDD-HHmmss). L'état spécifique à la session (plan, progression,
reviews) est isolé, tandis que les mémoires agents et les données projet persistent entre sessions.

- **Nouvelle session** : créée automatiquement à l'init, ou via `KISS_CLAW_SESSION` explicite.
- **Lister les sessions** : `/kiss-store list sessions` affiche toutes les sessions disponibles.
- **Reprendre une session** : `KISS_CLAW_SESSION=<id>` pour reprendre une session précédente.
