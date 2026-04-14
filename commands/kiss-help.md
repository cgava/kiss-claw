---
name: kiss-help
description: Browse and search kiss-claw documentation (Diataxis structure in docs/help/fr/)
---

# /kiss-help — Documentation Skill

Naviguer et rechercher dans la documentation kiss-claw organisee en structure Diataxis (tutorials, how-to, reference, explanation).

## Usage

```
/kiss-help                    Affiche l'index principal
/kiss-help tutorials          Index des tutoriels
/kiss-help how-to             Index des guides pratiques
/kiss-help reference          Index des references
/kiss-help explanation        Index des explications
/kiss-help <nom-page>         Affiche une page par nom (ex: store-sh, architecture)
/kiss-help search <termes>    Recherche dans toute la documentation
/kiss-help list               Liste toutes les pages disponibles
```

## Sections

| Section       | Contenu                                          |
|---------------|--------------------------------------------------|
| `tutorials`   | Lecons guidees pas a pas pour debutants          |
| `how-to`      | Recettes pour accomplir un objectif precis       |
| `reference`   | Descriptions techniques factuelles               |
| `explanation` | Contexte, rationale et decisions de design        |

## Examples

```bash
# Voir l'index principal
scripts/help.sh

# Consulter la reference de store.sh
scripts/help.sh store-sh

# Chercher tout ce qui parle de sessions
scripts/help.sh search session

# Lister toutes les pages disponibles
scripts/help.sh list
```

## Execution

Parse the arguments from `$ARGUMENTS` and delegate to `scripts/help.sh`.

- If `$ARGUMENTS` is empty, show the main documentation index.
- Run the command via Bash and return its stdout.
- If the command exits non-zero, return the stderr output so the caller can see what went wrong.

```bash
cd "$CLAUDE_PLUGIN_ROOT" && bash scripts/help.sh $ARGUMENTS
```

$ARGUMENTS
