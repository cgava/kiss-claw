# Proposition : Persistence Skills Layer

> Version : draft-1 | Date : 2026-04-09

## Contexte

Aujourd'hui, chaque agent lit/ecrit directement des fichiers dans `${KISS_CLAW_DIR}` :

```
# dans agent.md de kiss-orchestrator :
Read `.kiss-claw/STATE.md`
Write `.kiss-claw/PLAN.md`
```

Le pattern d'agent est **couple** a son mecanisme de stockage (fichiers markdown).
Changer le backend (base de donnees, MCP, API) implique de reecrire les 4 agents + les hooks.

## Objectif

Decoupler les agents de leur persistance via un **skill unique** `/kiss-store`,
remplacable par une implementation custom.

```
┌──────────────────────────────────────────────────┐
│                    AGENTS                         │
│  orchestrator / executor / verificator / improver │
│                                                   │
│     Skill("/kiss-store", "read state")            │
│     Skill("/kiss-store", "write plan ...")         │
└────────────────────┬─────────────────────────────┘
                     │  Skill tool
                     ▼
┌──────────────────────────────────────────────────┐
│              /kiss-store (skill)                   │
│                                                   │
│  Implementation par defaut : fichiers markdown    │
│  Livree avec kiss-claw dans commands/kiss-store.md│
│                                                   │
│  OU implementation custom fournie par :           │
│  - un autre plugin qui declare /kiss-store        │
│  - un override dans le projet utilisateur         │
└──────────────────────────────────────────────────┘
```

## Principe cle

L'indirection se fait **au niveau du skill**, pas dans un provider interne.

- kiss-claw livre une implementation par defaut de `/kiss-store` (fichiers dans `KISS_CLAW_DIR`)
- A l'installation, on peut choisir de **ne pas inclure** l'implementation par defaut
- En fournissant un autre `/kiss-store` (via un plugin custom, ou un fichier `commands/kiss-store.md` dans le projet), on remplace entierement le backend
- Les agents n'ont rien a changer : ils appellent toujours `/kiss-store`

## Le skill `/kiss-store`

### Interface (contrat)

Un seul skill, plusieurs commandes passees en `$ARGUMENTS` :

```
/kiss-store read <resource>
/kiss-store write <resource> <content>
/kiss-store append <resource> <content>
/kiss-store update <resource> <field> <value>
/kiss-store exists <resource>
/kiss-store list
```

### Resources

| Resource | Description | Exemple d'usage |
|----------|-------------|-----------------|
| `plan` | Roadmap du projet | orchestrator : read, write (init), exists |
| `state` | Progression en cours | orchestrator : read, write |
| `scratch` | Notes volatiles | orchestrator : read, write |
| `memory` | Contexte partage | all : read / improver : write |
| `memory:kiss-orchestrator` | Learnings orchestrator | orchestrator : read, write |
| `memory:kiss-executor` | Learnings executor | executor : read, write |
| `memory:kiss-verificator` | Learnings verificator | verificator : read, write |
| `memory:kiss-improver` | Learnings improver | improver : read, write |
| `reviews` | Rapports de review | verificator : read, append |
| `insights` | Propositions d'amelioration | improver : read, append, update |
| `analyzed` | Index des sessions analysees | improver : read, append |
| `token-stats` | Consommation tokens | improver : read, write |
| `checkpoint` | Snapshot de session | hook : write / all : read |

### Commandes detaillees

#### `read <resource>`
Retourne le contenu complet de la resource.
Si la resource n'existe pas, retourne une chaine vide.

#### `write <resource> <content>`
Ecrit/remplace le contenu de la resource.
Le `<content>` est tout ce qui suit le nom de la resource dans `$ARGUMENTS`.

#### `append <resource> <content>`
Ajoute du contenu a la fin de la resource existante.
Cree la resource si elle n'existe pas.

#### `update <resource> <field> <value>`
Met a jour un champ specifique dans une resource structuree (ex: YAML).
Utile pour STATE : `/kiss-store update state current_step "Implement auth"`.

#### `exists <resource>`
Retourne `true` ou `false`.

#### `list`
Retourne la liste des resources existantes.

## Implementation par defaut (fichiers)

### `commands/kiss-store.md`

```markdown
---
name: kiss-store
description: >
  Persistence layer for kiss-claw. Default implementation: markdown files
  in KISS_CLAW_DIR. Replace this skill to use a different backend.
---

You are the persistence layer for kiss-claw agents.
Parse $ARGUMENTS to extract action and resource.

## Arguments format
$ARGUMENTS = "<action> <resource> [content...]"

## Resource → file mapping

All files are relative to `${KISS_CLAW_DIR:-.kiss-claw}/` :

| Resource | File |
|----------|------|
| plan | PLAN.md |
| state | STATE.md |
| scratch | SCRATCH.md |
| memory | MEMORY.md |
| memory:kiss-orchestrator | MEMORY_kiss-orchestrator.md |
| memory:kiss-executor | MEMORY_kiss-executor.md |
| memory:kiss-verificator | MEMORY_kiss-verificator.md |
| memory:kiss-improver | MEMORY_kiss-improver.md |
| reviews | REVIEWS.md |
| insights | INSIGHTS.md |
| analyzed | ANALYZED.md |
| token-stats | TOKEN_STATS.md |
| checkpoint | CHECKPOINT.md |

## Actions

### read <resource>
Use the Read tool to read the mapped file. If the file doesn't exist, output nothing.

### write <resource> <content>
Use the Write tool to write <content> to the mapped file.

### append <resource> <content>
Use the Read tool to get existing content, then Write tool to write
existing + new content.

### update <resource> <field> <value>
Use the Read tool to get the file, find the line starting with `<field>:`,
replace its value with `<value>`, then Write the result back.

### exists <resource>
Use Glob to check if the mapped file exists. Output `true` or `false`.

### list
Use Glob on `${KISS_CLAW_DIR:-.kiss-claw}/*.md` and output the list
of resources that exist (using the reverse file→resource mapping).

## Output
Always output the result directly — no preamble, no commentary.
For `read`: output file contents.
For `write`/`append`/`update`: output `ok`.
For `exists`: output `true` or `false`.
For `list`: output one resource name per line.
```

## Impact sur les agents

### Changement dans les instructions

Chaque agent est modifie pour utiliser `/kiss-store` au lieu d'acces fichier directs.

#### kiss-orchestrator — avant

```markdown
## Startup protocol
1. Read `.kiss-claw/MEMORY.md` and `.kiss-claw/MEMORY_kiss-orchestrator.md`
2. Read `.kiss-claw/STATE.md` (or create from template if absent)
3. Count `proposed` entries in `.kiss-claw/INSIGHTS.md` if it exists
```

#### kiss-orchestrator — apres

```markdown
## Startup protocol
1. Use `/kiss-store read memory` and `/kiss-store read memory:kiss-orchestrator`
2. Use `/kiss-store read state` (or create from template if not exists)
   Check existence: `/kiss-store exists state`
3. Use `/kiss-store read insights` and count `proposed` entries
```

#### kiss-executor — avant

```markdown
## Constraints
- Never modify `.kiss-claw/PLAN.md`, `.kiss-claw/STATE.md`, ...
## Dry-run mode
At session start, read `mode` from `.kiss-claw/STATE.md`.
```

#### kiss-executor — apres

```markdown
## Constraints
- Never use `/kiss-store write` on: plan, state, insights, analyzed, memory
## Dry-run mode
At session start, use `/kiss-store read state` and check `mode` field.
```

#### kiss-verificator — avant

```markdown
Append to `.kiss-claw/REVIEWS.md`.
```

#### kiss-verificator — apres

```markdown
Use `/kiss-store append reviews` with the review entry.
```

#### kiss-improver — avant

```markdown
Append new entries to `.kiss-claw/INSIGHTS.md`.
Update `.kiss-claw/ANALYZED.md` with session record.
Append to `.kiss-claw/TOKEN_STATS.md`.
```

#### kiss-improver — apres

```markdown
Use `/kiss-store append insights` with the new entry.
Use `/kiss-store append analyzed` with the session record.
Use `/kiss-store read token-stats`, update summary, `/kiss-store write token-stats`.
```

## Impact sur les hooks

### guard.sh

Le guard n'intercepte plus les Write/Edit sur des fichiers specifiques.
Il intercepte les appels Skill a `/kiss-store` et verifie l'ownership par resource.

**Nouvelle logique** :

```bash
# Detect /kiss-store calls
if [[ "$CLAUDE_TOOL_NAME" == "Skill" ]]; then
  SKILL=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.skill // empty')
  ARGS=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.args // empty')

  if [[ "$SKILL" == "kiss-store" ]]; then
    ACTION=$(echo "$ARGS" | awk '{print $1}')
    RESOURCE=$(echo "$ARGS" | awk '{print $2}')

    # Read is always allowed
    [[ "$ACTION" == "read" || "$ACTION" == "exists" || "$ACTION" == "list" ]] && exit 0

    # Write ownership check
    AGENT=$(cat .poc-session-agent 2>/dev/null || echo "unknown")
    case "$RESOURCE" in
      plan|state|scratch)
        [[ "$AGENT" != "kiss-orchestrator" ]] && block "$RESOURCE" "kiss-orchestrator" ;;
      memory)
        [[ "$AGENT" != "kiss-improver" ]] && block "$RESOURCE" "kiss-improver" ;;
      memory:*)
        OWNER="${RESOURCE#memory:}"
        [[ "$AGENT" != "$OWNER" ]] && block "$RESOURCE" "$OWNER" ;;
      reviews)
        [[ "$AGENT" != "kiss-verificator" ]] && block "$RESOURCE" "kiss-verificator" ;;
      insights|analyzed|token-stats)
        [[ "$AGENT" != "kiss-improver" ]] && block "$RESOURCE" "kiss-improver" ;;
      checkpoint)
        block "$RESOURCE" "SessionEnd hook" ;;  # agents never write checkpoint
    esac
  fi
fi
```

**Note** : le guard doit aussi continuer a bloquer les Write/Edit directs sur les fichiers
du `KISS_CLAW_DIR`, pour empecher les agents de contourner `/kiss-store`.

### session-end.sh

Le hook `session-end.sh` utilise aussi `/kiss-store` ? Non — les hooks sont des scripts bash,
pas des agents Claude. Deux options :

1. **Option A** : le hook continue a ecrire les fichiers directement (il connait le backend fichier)
2. **Option B** : le hook appelle `store.sh` — un script bash miroir du skill

**Recommandation** : Option B — creer un `scripts/store.sh` qui est le pendant bash de `/kiss-store`.
L'implementation par defaut du skill ET le hook utilisent le meme script :

```
commands/kiss-store.md  →  instruits Claude d'appeler scripts/store.sh via Bash
hooks/session-end.sh    →  appelle scripts/store.sh directement
```

Cela centralise la logique et garantit la coherence.

### scripts/store.sh (backend bash)

```bash
#!/bin/bash
set -euo pipefail

ACTION="${1:?usage: store.sh <action> <resource> [content]}"
RESOURCE="${2:-}"
CONTENT="${3:-}"
KC_DIR="${KISS_CLAW_DIR:-.kiss-claw}"

resolve() {
  case "$1" in
    plan)                    echo "$KC_DIR/PLAN.md" ;;
    state)                   echo "$KC_DIR/STATE.md" ;;
    scratch)                 echo "$KC_DIR/SCRATCH.md" ;;
    memory)                  echo "$KC_DIR/MEMORY.md" ;;
    memory:*)                echo "$KC_DIR/MEMORY_${1#memory:}.md" ;;
    reviews)                 echo "$KC_DIR/REVIEWS.md" ;;
    insights)                echo "$KC_DIR/INSIGHTS.md" ;;
    analyzed)                echo "$KC_DIR/ANALYZED.md" ;;
    token-stats)             echo "$KC_DIR/TOKEN_STATS.md" ;;
    checkpoint)              echo "$KC_DIR/CHECKPOINT.md" ;;
    *)                       echo "unknown resource: $1" >&2; exit 1 ;;
  esac
}

case "$ACTION" in
  read)
    FILE=$(resolve "$RESOURCE")
    [[ -f "$FILE" ]] && cat "$FILE" || true
    ;;
  write)
    FILE=$(resolve "$RESOURCE")
    if [[ -n "$CONTENT" ]]; then
      echo "$CONTENT" > "$FILE"
    else
      cat > "$FILE"  # read from stdin for large content
    fi
    echo "ok"
    ;;
  append)
    FILE=$(resolve "$RESOURCE")
    if [[ -n "$CONTENT" ]]; then
      echo "$CONTENT" >> "$FILE"
    else
      cat >> "$FILE"
    fi
    echo "ok"
    ;;
  update)
    FILE=$(resolve "$RESOURCE")
    FIELD="$CONTENT"
    VALUE="${4:?usage: store.sh update <resource> <field> <value>}"
    if [[ -f "$FILE" ]]; then
      sed -i "s|^${FIELD}:.*|${FIELD}: \"${VALUE}\"|" "$FILE"
      echo "ok"
    else
      echo "resource not found" >&2; exit 1
    fi
    ;;
  exists)
    FILE=$(resolve "$RESOURCE")
    [[ -f "$FILE" ]] && echo "true" || echo "false"
    ;;
  list)
    for f in "$KC_DIR"/*.md; do
      [[ -f "$f" ]] || continue
      base=$(basename "$f" .md)
      case "$base" in
        PLAN)          echo "plan" ;;
        STATE)         echo "state" ;;
        SCRATCH)       echo "scratch" ;;
        MEMORY)        echo "memory" ;;
        MEMORY_*)      echo "memory:${base#MEMORY_}" ;;
        REVIEWS)       echo "reviews" ;;
        INSIGHTS)      echo "insights" ;;
        ANALYZED)      echo "analyzed" ;;
        TOKEN_STATS)   echo "token-stats" ;;
        CHECKPOINT)    echo "checkpoint" ;;
      esac
    done
    ;;
  *)
    echo "unknown action: $ACTION" >&2
    echo "usage: store.sh <read|write|append|update|exists|list> <resource> [content]" >&2
    exit 1
    ;;
esac
```

## Variante du skill `/kiss-store` (avec script bash)

Plutot que de faire executer la logique fichier par Claude (via Read/Write tools),
le skill peut deleguer a `scripts/store.sh` :

```markdown
---
name: kiss-store
description: >
  Persistence layer for kiss-claw. Default: files in KISS_CLAW_DIR.
  Replace this skill to use a different backend.
---

Execute the following bash command with the arguments provided :

bash ${CLAUDE_PLUGIN_ROOT}/scripts/store.sh $ARGUMENTS

Output the result directly, without commentary.
```

**Avantage** : plus rapide (un seul appel Bash vs plusieurs Read/Write),
comportement deterministe (pas d'interpretation par le LLM).

**C'est cette variante qui est recommandee.**

## Installation et remplacement

### Installation standard (avec /kiss-store par defaut)

```bash
# Le plugin livre commands/kiss-store.md + scripts/store.sh
# Tout fonctionne out of the box
claude plugins install kiss-claw
```

### Installation sans /kiss-store (backend custom)

```bash
# Installer kiss-claw sans l'implementation par defaut
claude plugins install kiss-claw --exclude commands/kiss-store.md

# Puis fournir sa propre implementation :
# Option 1 : un autre plugin qui declare /kiss-store
claude plugins install my-kiss-store-sqlite

# Option 2 : un fichier commands/kiss-store.md dans le projet
# qui implemente le meme contrat avec un backend different
```

### Exemples d'implementations custom

#### SQLite

```markdown
---
name: kiss-store
description: kiss-store implementation backed by SQLite
---
Execute: bash ${PROJECT_ROOT}/.kiss-claw/store-sqlite.sh $ARGUMENTS
```

Avec un `store-sqlite.sh` qui mappe les resources vers une table SQLite.

#### MCP

```markdown
---
name: kiss-store
description: kiss-store implementation via MCP server
---
Use the MCP tool `kiss_persistence` with:
- action: <first word of $ARGUMENTS>
- resource: <second word>
- content: <rest>
```

#### API distante

```markdown
---
name: kiss-store
description: kiss-store backed by a remote API
---
Execute: curl -s -X POST https://my-api.com/kiss-store \
  -H "Authorization: Bearer $KISS_API_TOKEN" \
  -d '{"args": "$ARGUMENTS"}'
```

## Plan de migration

### Phase 1 — Creer le skill et le script (sans toucher aux agents)

- [ ] Creer `scripts/store.sh`
- [ ] Creer `commands/kiss-store.md`
- [ ] Tester manuellement : `/kiss-store read state`, `/kiss-store write scratch "test"`, etc.

### Phase 2 — Migrer les agents un par un

- [ ] `kiss-orchestrator/agent.md` : remplacer les references fichier par `/kiss-store`
- [ ] `kiss-executor/agent.md` : idem
- [ ] `kiss-verificator/agent.md` : idem
- [ ] `kiss-improver/agent.md` : idem

### Phase 3 — Adapter les hooks

- [ ] `guard.sh` : ajouter interception des appels Skill + bloquer Write/Edit directs
- [ ] `session-end.sh` : utiliser `scripts/store.sh` au lieu d'ecriture directe
- [ ] `init.sh` : utiliser `scripts/store.sh` pour creer les resources initiales

### Phase 4 — Validation

- [ ] Tester un cycle complet : init → plan → execute → review → improve
- [ ] Tester le remplacement du skill par un mock
- [ ] Documenter le contrat dans le README

## Resume

| Avant | Apres |
|-------|-------|
| Agents lisent/ecrivent des fichiers | Agents appellent `/kiss-store` |
| Backend = fichiers (en dur) | Backend = skill remplacable |
| guard.sh verifie des chemins | guard.sh verifie des resources |
| Hooks ecrivent directement | Hooks utilisent `scripts/store.sh` |
| Changer le backend = reecrire tout | Changer le backend = remplacer 1 skill |
