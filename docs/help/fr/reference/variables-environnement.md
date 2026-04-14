# Variables d'environnement

Toutes les variables d'environnement utilisees par kiss-claw.

## Variables de configuration

| Variable                 | Defaut                     | Description                                                |
|--------------------------|----------------------------|------------------------------------------------------------|
| `KISS_CLAW_DIR`          | `.kiss-claw`               | Repertoire racine de kiss-claw                             |
| `KISS_CLAW_AGENTS_DIR`   | `$KISS_CLAW_DIR/agents`    | Repertoire des fichiers agents (memoires, insights, analyzed) |
| `KISS_CLAW_PROJECT_DIR`  | `$KISS_CLAW_DIR/project`   | Repertoire des fichiers projet (memory, sessions.json)     |
| `KISS_CLAW_SESSIONS_DIR` | `$KISS_CLAW_DIR/sessions`  | Repertoire des sessions de travail                         |
| `KISS_CLAW_SESSION`      | (aucun)                    | ID de la session active, format `YYYYMMDD-HHmmss`          |

## Variables Claude Code (fournies par le runtime)

| Variable               | Description                                              |
|------------------------|----------------------------------------------------------|
| `CLAUDE_PLUGIN_ROOT`   | Chemin absolu vers le repertoire du plugin kiss-claw      |
| `CLAUDE_TOOL_NAME`     | Nom de l'outil en cours d'utilisation (pour les hooks)    |
| `CLAUDE_TOOL_INPUT_PATH` | Chemin du fichier cible (pour les hooks PreToolUse)     |
| `CLAUDE_TOOL_INPUT_COMMAND` | Commande bash en cours (pour les hooks PreToolUse)   |

## Usage

### KISS_CLAW_DIR

Change le repertoire racine. Les sous-repertoires (`agents`, `project`, `sessions`) sont resolus relativement a ce chemin sauf si surcharges individuellement.

```bash
export KISS_CLAW_DIR=/home/user/shared-state
./scripts/init.sh
```

### KISS_CLAW_SESSION

Obligatoire pour acceder aux ressources session-scoped (`plan`, `state`, `reviews`, `scratch`, `checkpoint`). Defini automatiquement par kiss-orchestrator au demarrage d'une session.

```bash
export KISS_CLAW_SESSION=20260414-153022
bash scripts/store.sh read plan
```

Sans cette variable, les acces aux ressources session-scoped echouent :

```
error: KISS_CLAW_SESSION is required for resource 'plan' (session-scoped)
```

### KISS_CLAW_AGENTS_DIR, KISS_CLAW_PROJECT_DIR, KISS_CLAW_SESSIONS_DIR

Permettent de rediriger individuellement chaque sous-repertoire. Utile pour partager les memoires agents entre projets ou stocker les sessions sur un volume different.

```bash
export KISS_CLAW_AGENTS_DIR=/home/user/shared/kiss-claw-agents
export KISS_CLAW_PROJECT_DIR=.kiss-claw/project
export KISS_CLAW_SESSIONS_DIR=/data/sessions
```

## Resolution des chemins

Ordre de priorite (du plus prioritaire au moins prioritaire) :

1. Variable d'environnement specifique (`KISS_CLAW_AGENTS_DIR`, etc.)
2. Sous-repertoire de `KISS_CLAW_DIR` (`$KISS_CLAW_DIR/agents`, etc.)
3. Sous-repertoire du defaut (`.kiss-claw/agents`, etc.)

Utilisez `bash scripts/store.sh inspect` pour voir les chemins resolus.
