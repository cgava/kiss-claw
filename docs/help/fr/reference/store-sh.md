# store.sh -- Reference

Script de persistence central de kiss-claw. Toutes les lectures et ecritures de fichiers d'etat passent par ce script.

## Synopsis

```bash
bash scripts/store.sh <action> <resource> [arguments...]
```

## Actions

### `read <resource>`

Lit et affiche le contenu d'une ressource. Si le fichier n'existe pas, ne retourne rien (code de sortie 0).

```bash
bash scripts/store.sh read plan
bash scripts/store.sh read memory:kiss-executor
```

### `write <resource> [contenu...]`

Ecrit du contenu dans une ressource. Ecrase le contenu existant. Cree le repertoire parent si necessaire.

Contenu en argument :

```bash
bash scripts/store.sh write scratch "## Notes"
```

Contenu via stdin :

```bash
cat plan.md | bash scripts/store.sh write plan
```

### `append <resource> [contenu...]`

Ajoute du contenu a la fin d'une ressource.

```bash
bash scripts/store.sh append reviews "### REV-0001"
```

Via stdin :

```bash
echo "nouvelle ligne" | bash scripts/store.sh append reviews
```

### `update <resource> <champ> <valeur...>`

Met a jour un champ YAML dans une ressource existante. Cherche la ligne `champ: ...` et remplace la valeur.

```bash
bash scripts/store.sh update state current_step "1.3 Tests"
bash scripts/store.sh update state status "in_progress"
```

Le fichier doit exister, sinon erreur.

### `exists <resource>`

Verifie si le fichier d'une ressource existe. Retourne `true` ou `false`.

```bash
bash scripts/store.sh exists plan
```

### `inspect`

Affiche la configuration resolue et les chemins de toutes les ressources.

```bash
bash scripts/store.sh inspect
```

Sortie :

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
  reviews: .kiss-claw/sessions/20260414-153022/REVIEWS.md
  scratch: .kiss-claw/sessions/20260414-153022/SCRATCH.md
  checkpoint: .kiss-claw/sessions/20260414-153022/CHECKPOINT.yaml
  memory: .kiss-claw/project/MEMORY.md
  insights: .kiss-claw/agents/INSIGHTS.md
  analyzed: .kiss-claw/agents/ANALYZED.md
  sessions: .kiss-claw/project/SESSIONS.json
```

### `list`

Liste toutes les ressources existantes (fichiers presents sur disque).

```bash
bash scripts/store.sh list
```

### `checkpoint <sous-commande> [options...]`

Gestion des fichiers CHECKPOINT.yaml.

#### `checkpoint init-need [--session <id>] [--force]`

Initialise la section `need` du checkpoint. Le contenu YAML est lu depuis stdin.

```bash
echo 'why: |
  Raison profonde
raw: |
  Besoin brut
elicited: |
  Intentions clarifiees
constraints: |
  Contraintes' | \
KISS_CLAW_SESSION=20260414-153022 bash scripts/store.sh checkpoint init-need
```

Options :
- `--session <id>` : definit `KISS_CLAW_SESSION` pour cette commande
- `--force` : ecrase une section `need` existante

Erreur si `need` existe deja (sans `--force`).

#### `checkpoint upsert <claude_session> [--parent <parent_claude_session>] [--session <id>]`

Insere ou met a jour une entree dans le log du checkpoint. Les champs sont lus depuis stdin en format YAML.

Insertion au niveau racine du log :

```bash
echo 'agent: kiss-orchestrator
task: "INIT -- Plan genere"
result: "Plan en 3 phases"' | \
KISS_CLAW_SESSION=20260414-153022 bash scripts/store.sh checkpoint upsert "orchestrator-20260414-153022"
```

Insertion comme enfant d'une entree parente :

```bash
echo 'agent: kiss-executor
task: "Parser les arguments CLI"
result: "src/cli.py cree"' | \
KISS_CLAW_SESSION=20260414-153022 bash scripts/store.sh checkpoint upsert "executor-20260414-153022" \
  --parent "orchestrator-20260414-153022"
```

Champs stdin reconnus :
- `agent` : nom de l'agent
- `task` : description de la tache
- `action` : alternative a `task`
- `result` : resultat de la tache
- `timestamp` : horodatage (defaut : maintenant en UTC)

Options :
- `--parent <id>` : insere l'entree dans les `children` de l'entree parente identifiee par son `claude_session`
- `--session <id>` : definit `KISS_CLAW_SESSION` pour cette commande

Comportement :
- Si `claude_session` existe deja dans le fichier : mise a jour des champs existants
- Si `claude_session` n'existe pas : insertion d'une nouvelle entree

Retourne `ok: inserted` ou `ok: updated`.

## Ressources par categorie

### Session-scoped

Necessitent `KISS_CLAW_SESSION`. Stockees dans `.kiss-claw/sessions/<id>/`.

| Ressource    | Fichier           | Format   |
|-------------|-------------------|----------|
| `plan`       | `PLAN.md`         | Markdown |
| `state`      | `STATE.md`        | YAML     |
| `reviews`    | `REVIEWS.md`      | Markdown |
| `scratch`    | `SCRATCH.md`      | Markdown |
| `checkpoint` | `CHECKPOINT.yaml` | YAML     |

### Agent-scoped

Stockees dans `.kiss-claw/agents/`. Persistent entre sessions.

| Ressource              | Fichier                      | Format   |
|------------------------|------------------------------|----------|
| `memory:kiss-<agent>`  | `MEMORY_kiss-<agent>.md`     | Markdown |
| `insights`             | `INSIGHTS.md`                | Markdown |
| `analyzed`             | `ANALYZED.md`                | Markdown |

### Project-scoped

Stockees dans `.kiss-claw/project/`. Persistent entre sessions.

| Ressource   | Fichier           | Format   |
|------------|-------------------|----------|
| `memory`    | `MEMORY.md`       | Markdown |
| `sessions`  | `SESSIONS.json`   | JSON     |

## Codes de sortie

| Code | Signification                                            |
|------|----------------------------------------------------------|
| 0    | Succes                                                   |
| 1    | Erreur : ressource inconnue, session manquante, fichier absent, option inconnue, section `need` deja existante |

## Variables d'environnement

| Variable               | Defaut                    | Role                              |
|------------------------|---------------------------|-----------------------------------|
| `KISS_CLAW_DIR`        | `.kiss-claw`              | Repertoire racine                 |
| `KISS_CLAW_AGENTS_DIR` | `$KISS_CLAW_DIR/agents`   | Repertoire des fichiers agents    |
| `KISS_CLAW_PROJECT_DIR`| `$KISS_CLAW_DIR/project`  | Repertoire des fichiers projet    |
| `KISS_CLAW_SESSIONS_DIR`| `$KISS_CLAW_DIR/sessions`| Repertoire des sessions           |
| `KISS_CLAW_SESSION`    | (aucun)                   | ID de la session active (requis pour les ressources session-scoped) |
