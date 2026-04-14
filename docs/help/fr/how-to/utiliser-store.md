# Utiliser le store

Comment lire, ecrire et gerer les ressources de persistence kiss-claw.

## Les 3 categories de ressources

### Session-scoped (necessitent `KISS_CLAW_SESSION`)

| Ressource    | Fichier                                      | Proprietaire       |
|-------------|----------------------------------------------|-------------------|
| `plan`       | `.kiss-claw/sessions/<id>/PLAN.md`           | kiss-orchestrator  |
| `state`      | `.kiss-claw/sessions/<id>/STATE.md`          | kiss-orchestrator  |
| `reviews`    | `.kiss-claw/sessions/<id>/REVIEWS.md`        | kiss-verificator   |
| `scratch`    | `.kiss-claw/sessions/<id>/SCRATCH.md`        | kiss-orchestrator  |
| `checkpoint` | `.kiss-claw/sessions/<id>/CHECKPOINT.yaml`   | kiss-orchestrator  |

### Agent-scoped (persistent entre sessions)

| Ressource              | Fichier                                      | Proprietaire       |
|------------------------|----------------------------------------------|-------------------|
| `memory:kiss-<agent>`  | `.kiss-claw/agents/MEMORY_kiss-<agent>.md`   | l'agent lui-meme   |
| `insights`             | `.kiss-claw/agents/INSIGHTS.md`              | kiss-improver      |
| `analyzed`             | `.kiss-claw/agents/ANALYZED.md`              | kiss-improver      |

### Project-scoped (persistent entre sessions)

| Ressource   | Fichier                            | Proprietaire       |
|------------|------------------------------------|--------------------|
| `memory`    | `.kiss-claw/project/MEMORY.md`    | kiss-improver      |
| `sessions`  | `.kiss-claw/project/SESSIONS.json`| kiss-orchestrator  |

## Commandes

### `read` -- Lire une ressource

```bash
bash scripts/store.sh read plan
bash scripts/store.sh read memory:kiss-executor
bash scripts/store.sh read memory
```

Retourne le contenu du fichier. Si le fichier n'existe pas, ne retourne rien (pas d'erreur).

### `write` -- Ecrire une ressource

Contenu en argument :

```bash
bash scripts/store.sh write scratch "## Notes de travail"
```

Contenu via stdin :

```bash
echo "## Plan initial" | bash scripts/store.sh write plan
```

Cree le repertoire parent si necessaire. Ecrase le contenu existant.

### `append` -- Ajouter du contenu

```bash
bash scripts/store.sh append reviews "### REV-0001"
```

Ou via stdin :

```bash
echo "- Step 1.2 verified OK" | bash scripts/store.sh append reviews
```

### `update` -- Mettre a jour un champ YAML

```bash
bash scripts/store.sh update state current_step "1.3 Tests"
bash scripts/store.sh update state status "in_progress"
bash scripts/store.sh update state mode "dry-run"
```

Cherche la ligne `champ: ...` et remplace la valeur. Le fichier doit exister.

### `exists` -- Verifier l'existence

```bash
bash scripts/store.sh exists plan
# Retourne "true" ou "false"
```

### `list` -- Lister les ressources

```bash
bash scripts/store.sh list
```

Affiche toutes les ressources disponibles avec leur session le cas echeant :

```
memory:kiss-orchestrator
memory:kiss-executor
insights
memory
sessions
plan (20260414-153022)
state (20260414-153022)
```

### `inspect` -- Voir la configuration

```bash
bash scripts/store.sh inspect
```

Affiche les chemins resolus et toutes les ressources disponibles :

```
kiss_claw_dir: .kiss-claw
agents_dir: .kiss-claw/agents
project_dir: .kiss-claw/project
sessions_dir: .kiss-claw/sessions
session: 20260414-153022
session_path: .kiss-claw/sessions/20260414-153022
---
Resources:
  plan: .kiss-claw/sessions/20260414-153022/PLAN.md
  state: .kiss-claw/sessions/20260414-153022/STATE.md
  ...
```

## `/kiss-store` vs `bash scripts/store.sh`

Les deux sont equivalents. `/kiss-store` est la commande slash utilisee par les agents dans le contexte Claude Code. Elle delegue a `scripts/store.sh` :

```bash
# Ces deux commandes sont identiques :
/kiss-store read plan
bash scripts/store.sh read plan
```

Utilisez `/kiss-store` quand vous interagissez avec les agents dans Claude Code. Utilisez `bash scripts/store.sh` quand vous travaillez directement en terminal.

## Variable d'environnement requise

Les ressources session-scoped necessitent `KISS_CLAW_SESSION` :

```bash
export KISS_CLAW_SESSION=20260414-153022
bash scripts/store.sh read plan
```

Sans cette variable, `store.sh` retourne une erreur :

```
error: KISS_CLAW_SESSION is required for resource 'plan' (session-scoped)
```
