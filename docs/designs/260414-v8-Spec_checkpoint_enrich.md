# SPEC — /kiss-checkpoint-enrich

> Skill d'extraction automatique du contenu verbatim des sessions Claude vers CHECKPOINT.yaml.
> Issu de la session 20260414-213000.

## Contexte

Les CHECKPOINT.yaml actuels sont trop compactes (task/result monolignes) pour servir de memoire
projet exploitable. Les transcripts Claude (.jsonl) contiennent le contenu riche (tableaux,
verdicts, rapports, decisions argumentees) mais ne sont pas perennes.

Ce skill extrait automatiquement le contenu substantiel des transcripts et enrichit les
CHECKPOINT.yaml pour les rendre auto-suffisants.

## Interface

```
/kiss-checkpoint-enrich <session-id> [--step <claude_session_id>] [--dry-run]
```

| Mode | Comportement |
|------|-------------|
| `<session-id>` seul | Enrichit TOUT le CHECKPOINT de la session (batch, post-session) |
| `--step <claude_session_id>` | Enrichit UN SEUL step (celui correspondant au `claude_session` donne). Mode temps reel utilise par les agents. |
| `--dry-run` | Affiche ce qui serait extrait sans modifier le CHECKPOINT |

## Format enrichi des steps

Chaque step dans le log du CHECKPOINT passe du format actuel :

```yaml
- agent: "kiss-executor"
  claude_session: "agent-xxx"
  task: "Modifier store.sh"
  result: "store.sh modifie."
```

Au format enrichi :

```yaml
- agent: "kiss-executor"
  claude_session: "agent-xxx"
  parent_session: "6dd4a886-..."
  timestamp: "2026-04-13T22:03:26Z"
  task: |
    <Description detaillee — quasi-verbatim de la delegation ou de la
    comprehension de la tache par l'agent>
  rationale: |
    <Pourquoi cette approche. Alternatives considerees.>
  result: |
    <Resultat detaille — fichiers modifies, lignes changees, tests, commits>
  artifacts: |
    <Contenu verbatim produit par l'agent : tableaux, rapports, verdicts,
    code snippets. Markdown formatting preservee (tables, fenced blocks, listes).
    C'est le champ CLE — capture ce qui serait autrement perdu.>
  decisions: |
    <Decisions majeures prises pendant ce step, avec justification>
  issues: |
    <Problemes rencontres, caveats, limitations. "none" si clean>
  children: []
```

## Algorithme d'extraction (`--step`)

1. **Resoudre le chemin du transcript :**
   - Si `claude_session` commence par `agent-` :
     chercher dans `.kiss-claw/sessions/.claude-sessions/<parent>/subagents/<claude_session>.jsonl`
     (le `parent_session` est lu depuis le CHECKPOINT)
   - Sinon : chercher dans `.kiss-claw/sessions/.claude-sessions/<claude_session>.jsonl`

2. **Parser le .jsonl :** extraire tous les blocs `message.content[].text`
   ou `message.role == "assistant"` et `len(text) > 100`

3. **Classifier les blocs extraits :**

   | Signal | Champ cible |
   |--------|-------------|
   | Contient `=== TASK REPORT ===` | `artifacts` |
   | Contient `Verdict :` ou `REV-` | `artifacts` |
   | Contient des tableaux markdown (`\|---\|`) | `artifacts` |
   | Contient des decisions ("j'ai choisi", "plutot que", "alternatives") | `decisions` |
   | Contient des problemes ("caveat", "issue", "limitation", "broken") | `issues` |
   | Premier bloc substantiel | Enrichit `task` si champ actuel < 200 chars |
   | Dernier bloc substantiel | Enrichit `result` si champ actuel < 200 chars |

   Un bloc peut alimenter plusieurs champs. Le champ `rationale` est synthetise a partir
   des blocs de decisions et du contexte de delegation.

4. **Mettre a jour le CHECKPOINT :** trouver l'entree par `claude_session`,
   injecter/remplacer les champs enrichis. Les champs existants non-vides ne sont
   PAS ecrases (sauf si le contenu extrait est significativement plus riche).

## Algorithme batch (sans `--step`)

Iterer sur tous les steps du CHECKPOINT, appliquer l'algorithme `--step` pour chacun.
Sauter les steps dont le transcript .jsonl est introuvable (warning sur stderr).

## Implementation

### Fichier : `scripts/checkpoint-enrich.py`

- **Langage** : Python 3
- **Dependances** : `json` (stdlib) + `pyyaml` (via `.venv` du projet)
- **Pas de fallback** si pyyaml absent — c'est `init.sh` qui se charge du `.venv`
  lors du deploiement du plugin. Si le `.venv` est mal configure, le script echoue
  avec un message clair (`ImportError: No module named 'yaml'`).
- Le script est executable (`chmod +x`) avec shebang pointant vers le `.venv` :
  ```
  #!/usr/bin/env python3
  ```
- Activation du `.venv` geree par l'appelant (store.sh, skill, ou agent) ou par
  le PATH si le `.venv/bin` est dans le PATH.

### Fichier : `commands/kiss-checkpoint-enrich.md`

Skill slash command, meme pattern que `/kiss-store` :

```markdown
---
name: kiss-checkpoint-enrich
description: Enrich CHECKPOINT.yaml from Claude session transcripts
---

# /kiss-checkpoint-enrich

Extracts verbatim content from Claude session transcripts and enriches
the CHECKPOINT.yaml of the specified kiss-claw session.

## Usage

/kiss-checkpoint-enrich <session-id> [--step <claude_session_id>] [--dry-run]

## Execution

cd "$CLAUDE_PLUGIN_ROOT" && python3 scripts/checkpoint-enrich.py $ARGUMENTS
```

## Adaptation des agents

### Changement principal

Au lieu d'ecrire manuellement un `task` et `result` compresses via
`store.sh checkpoint upsert`, chaque agent :

1. Fait son travail normalement
2. Ecrit l'entree minimale via `store.sh checkpoint upsert` (cree l'entree avec agent, timestamp)
3. Appelle `/kiss-checkpoint-enrich <session> --step <son_claude_session>` pour l'enrichissement

### Template de fin de tache (pour chaque agent)

```bash
# 1. Upsert minimal (cree l'entree)
echo 'agent: <agent_name>
task: "<1 ligne descriptive>"
result: "<1 ligne descriptive>"' | \
KISS_CLAW_SESSION=$SESSION bash scripts/store.sh checkpoint upsert "$MY_CLAUDE_SESSION"

# 2. Enrichissement automatique depuis le transcript
KISS_CLAW_SESSION=$SESSION python3 scripts/checkpoint-enrich.py "$SESSION" --step "$MY_CLAUDE_SESSION"
```

### Agents impactes

| Agent | Section a modifier | Changement |
|-------|-------------------|------------|
| `kiss-orchestrator` | "CHECKPOINT tracking continu" | Ajouter appel enrich apres upsert |
| `kiss-orchestrator` | Message de delegation | Inclure instruction enrich pour subagents |
| `kiss-executor` | Step 6 (CHECKPOINT logging) | Ajouter appel enrich apres upsert |
| `kiss-verificator` | Section CHECKPOINT apres verdict | Ajouter appel enrich apres upsert |
| `kiss-improver` | Step 7.5 | Ajouter appel enrich apres upsert |

### Delegation orchestrator (nouveau template)

```
CHECKPOINT: En fin de tache :
1. store.sh checkpoint upsert "$MY_CLAUDE_SESSION" (entree minimale)
2. python3 scripts/checkpoint-enrich.py $SESSION --step "$MY_CLAUDE_SESSION" (enrichissement)
```

## Workflow complet

```
Agent fait son travail
        |
        v
store.sh checkpoint upsert  <-- cree l'entree (agent, timestamp, task/result minimaux)
        |
        v
checkpoint-enrich.py --step  <-- lit le transcript JSONL de l'agent
        |                       extrait les blocs substantiels
        v                       injecte artifacts, decisions, issues, rationale
CHECKPOINT.yaml enrichi         enrichit task/result si trop courts
```

## Fichiers a livrer

| Fichier | Action |
|---------|--------|
| `scripts/checkpoint-enrich.py` | Creer |
| `commands/kiss-checkpoint-enrich.md` | Creer |
| `agents/kiss-orchestrator/agent.md` | Modifier |
| `agents/kiss-executor/agent.md` | Modifier |
| `agents/kiss-verificator/agent.md` | Modifier |
| `agents/kiss-improver/agent.md` | Modifier |

## References

- Session 20260414-213000 : recherche etat de l'art + prototype
- Prototype valide sur session 20260413-223433 (205 -> 1121 lignes)
- Patterns : Reflexion (NeurIPS 2023), Retroformer (ICLR 2024)
- Format : YAML + blocs Markdown `|` (meilleur compromis structure/lisibilite LLM)
