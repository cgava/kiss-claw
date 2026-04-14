# Formats de fichiers

Formats exacts de chaque fichier d'etat gere par kiss-claw.

## STATE.md

Format YAML. Gere par kiss-orchestrator.

```yaml
project: "<nom du projet>"
updated: "<YYYY-MM-DD>"

current_phase: "Phase 1"
current_step: ""
status: "ready"          # ready | in_progress | blocked | done
blocker: ""

completed: []            # "Phase X / step title"
skipped: []
accepted_insights: []    # "INS-NNNN applied YYYY-MM-DD"

mode: "live"             # live | dry-run

token_budget:
  per_step: 8000         # soft limit par etape kiss-executor (tokens)
  warn_at: 6000          # seuil d'alerte
  session_total: 0       # mis a jour par kiss-improver apres chaque analyse de session

last_checkpoint: ""      # ISO datetime du dernier checkpoint

log:
  - "YYYY-MM-DD -- session init"
```

### Champs

| Champ              | Type     | Description                                          |
|--------------------|----------|------------------------------------------------------|
| `project`          | string   | Nom du projet                                        |
| `updated`          | string   | Date de derniere mise a jour (YYYY-MM-DD)            |
| `current_phase`    | string   | Phase en cours                                       |
| `current_step`     | string   | Etape en cours                                       |
| `status`           | enum     | `ready`, `in_progress`, `blocked`, `done`            |
| `blocker`          | string   | Description du bloqueur, vide si aucun               |
| `completed`        | list     | Etapes completees ("Phase X / step title")           |
| `skipped`          | list     | Etapes sautees                                       |
| `accepted_insights`| list     | Insights appliques ("INS-NNNN applied YYYY-MM-DD")   |
| `mode`             | enum     | `live` ou `dry-run`                                  |
| `token_budget`     | object   | Configuration du budget tokens                       |
| `last_checkpoint`  | string   | Horodatage ISO du dernier checkpoint                 |
| `log`              | list     | Journal d'evenements de session                      |

## PLAN.md

Format Markdown. Immutable apres creation. Gere par kiss-orchestrator.

```markdown
# <nom du projet>

## Goal
<une phrase>

## Non-goals
- <element>

## Phases

### Phase 1 -- <nom>
- [ ] <etape>
- [ ] <etape>

### Phase 2 -- <nom>
- [ ] <etape>
```

## CHECKPOINT.yaml

Format YAML. Gere par les agents via `store.sh checkpoint`.

```yaml
session: "20260414-153022"
created: "2026-04-14T15:30:22"

need:
  why: |
    Raison profonde : <le vrai pourquoi>
    Categorie : <bug | feature | refactoring | dette_technique | contrainte_externe | autre>
  raw: |
    <besoin verbatim de l'utilisateur>
  elicited: |
    <intentions clarifiees pendant l'echange INIT>
  constraints: |
    <contraintes identifiees>

log:
  - agent: "kiss-orchestrator"
    claude_session: "orchestrator-20260414-153022"
    timestamp: "2026-04-14T15:31:00Z"
    task: "INIT -- Plan genere"
    result: "Plan en 3 phases"
    children:
      - agent: "kiss-executor"
        claude_session: "executor-20260414-153022"
        timestamp: "2026-04-14T15:45:00Z"
        task: "Implementer le parser CLI"
        result: "src/cli.py cree"
        children: []
```

### Champs `need`

| Champ        | Description                                            |
|-------------|--------------------------------------------------------|
| `why`        | Raison profonde et categorie, elicitee par l'orchestrateur |
| `raw`        | Besoin tel que formule par l'utilisateur               |
| `elicited`   | Intentions clarifiees pendant l'echange INIT           |
| `constraints`| Contraintes identifiees                                |

### Champs `log` (par entree)

| Champ            | Description                                        |
|------------------|----------------------------------------------------|
| `agent`          | Nom de l'agent                                     |
| `claude_session` | Identifiant de session Claude (placeholder)        |
| `timestamp`      | Horodatage UTC ISO 8601                            |
| `task`           | Description de la tache                            |
| `action`         | Alternative a `task`                               |
| `result`         | Resultat de la tache                               |
| `children`       | Liste des entrees enfants (delegations)            |

## SESSIONS.json

Format JSON. Gere par kiss-orchestrator.

```json
{
  "sessions": [
    {
      "id": "20260414-153022",
      "created": "2026-04-14T15:30:22",
      "status": "in_progress",
      "title": "Titre du plan"
    },
    {
      "id": "20260413-091500",
      "created": "2026-04-13T09:15:00",
      "status": "done",
      "title": "Refonte persistence",
      "closed": "2026-04-13T11:30:00",
      "summary": {
        "need": "Resume du besoin en 2-3 phrases",
        "outcome": "Ce qui a ete concretement realise",
        "files_changed": ["scripts/store.sh", "agents/kiss-orchestrator/agent.md"],
        "decisions": ["Format YAML plutot que JSON", "Placeholder session ID"],
        "next": ["Script sync-sessions.sh", "Tests en conditions reelles"]
      }
    }
  ]
}
```

### Champs par session

| Champ     | Presence      | Description                                  |
|-----------|---------------|----------------------------------------------|
| `id`      | toujours      | Identifiant au format YYYYMMDD-HHmmss        |
| `created` | toujours      | Date ISO de creation                         |
| `status`  | toujours      | `in_progress` ou `done`                      |
| `title`   | toujours      | Titre du plan (vide avant INIT)              |
| `closed`  | si done       | Date ISO de fermeture                        |
| `summary` | si done       | Objet resume (optionnel, retrocompatible)    |

### Champs `summary`

| Champ           | Description                                      |
|-----------------|--------------------------------------------------|
| `need`          | Besoin original resume (2-3 phrases)             |
| `outcome`       | Livrables concrets                               |
| `files_changed` | Liste des fichiers modifies                      |
| `decisions`     | Decisions majeures prises                        |
| `next`          | Suites a donner                                  |

## REVIEWS.md

Format Markdown. Gere par kiss-verificator via `store.sh append reviews`.

```markdown
### REV-<NNNN>

- **date**     : <YYYY-MM-DD>
- **subject**  : kiss-executor task -- <description>
- **verdict**  : approved | approved-with-notes | needs-rework

**Summary**
<2-3 phrases. Ce qui a ete revu, verdict global.>

**Issues**
- [blocking] <probleme> -- <ce qui doit changer>
- [minor] <probleme> -- <suggestion>

**For kiss-orchestrator**
<une ligne : proceed to next step / rework this step / split this step>
```

### Verdicts

| Verdict              | Condition                  |
|----------------------|----------------------------|
| `approved`           | Zero issues                |
| `approved-with-notes`| Issues mineures uniquement |
| `needs-rework`       | Au moins une issue `[blocking]` |

## MEMORY.md

Format Markdown. Memoire partagee du projet. Geree par kiss-improver.

Contenu libre, typiquement :
- Nom du projet et description
- Stack technique
- Conventions
- Contraintes globales

## INSIGHTS.md

Format Markdown. Propositions d'amelioration generees par kiss-improver.

```markdown
### INS-<NNNN>

- **session**       : <session-id>
- **session-agent** : kiss-orchestrator | kiss-executor | kiss-verificator | kiss-improver | general
- **date**          : <YYYY-MM-DD>
- **target**        : <agent:name | CLAUDE.md | memory | memory:<agent> | settings.json>
- **type**          : fact | proposal
- **confidence**    : high | medium | low
- **status**        : proposed | accepted | rejected | deferred | applied

**Fact**
<comportement observe, 1-2 phrases>

**Proposal**
<modification concrete minimale a apporter>

**Rejection reason**
<vide ou raison du rejet>
```

### Statuts

| Statut     | Description                              |
|------------|------------------------------------------|
| `proposed` | Nouvelle proposition, en attente de revue |
| `accepted` | Acceptee, prete a etre appliquee         |
| `rejected` | Rejetee (avec raison)                    |
| `deferred` | Reportee, masquee des futures listes     |
| `applied`  | Appliquee au fichier cible               |

## ANALYZED.md

Format Markdown (table). Index des sessions analysees par kiss-improver.

```markdown
| session-id | agent | date | lines | digest | input_tok | output_tok | turns | tpt | budget |
|------------|-------|------|-------|--------|-----------|------------|-------|-----|--------|
| abc123 | kiss-executor | 2025-04-09 | 342 | 4f2a1b3c | 12400 | 3200 | 8 | 400 | ok |
```

### Colonnes

| Colonne      | Description                                    |
|-------------|------------------------------------------------|
| `session-id` | Identifiant de la session Claude               |
| `agent`      | Agent identifie dans la session                |
| `date`       | Date de l'analyse                              |
| `lines`      | Nombre de lignes du transcript                 |
| `digest`     | Hash court (8 caracteres) du debut du fichier  |
| `input_tok`  | Tokens d'entree consommes                      |
| `output_tok` | Tokens de sortie generes                       |
| `turns`      | Nombre de messages humains                     |
| `tpt`        | Tokens par tour (output_tokens / turns)        |
| `budget`     | Statut budget : `ok`, `warn`, `over`           |
