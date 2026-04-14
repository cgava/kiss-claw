# Utiliser les checkpoints

Comment lire, comprendre et exploiter les fichiers CHECKPOINT.yaml.

## Quand les checkpoints sont crees

Les checkpoints sont geres automatiquement par les agents via `store.sh` :

1. **A la fin du INIT** : kiss-orchestrator initialise la section `need` (le besoin) et inscrit sa premiere entree dans le log
2. **A chaque delegation** : kiss-orchestrator ajoute une entree de delegation dans le log
3. **A chaque fin de tache** : kiss-executor, kiss-verificator et kiss-improver ajoutent leurs resultats dans le log, en tant qu'enfants de l'entree orchestrator

## Lire un checkpoint

```bash
KISS_CLAW_SESSION=20260414-153022 bash scripts/store.sh read checkpoint
```

Ou via la commande slash :

```
/kiss-store read checkpoint
```

(Necessite que `KISS_CLAW_SESSION` soit defini dans le contexte de l'agent.)

## Structure CHECKPOINT.yaml

### Section `need` -- le besoin

Capture l'intention originale de la session :

```yaml
session: "20260414-153022"
created: "2026-04-14T15:30:22"

need:
  why: |
    Raison profonde : les utilisateurs ont besoin d'exporter les donnees pour analyse externe
    Categorie : feature
  raw: |
    Ajouter une commande CLI pour exporter les donnees en CSV
  elicited: |
    Export CSV avec filtres par date et par type. Format standard, pas Excel.
  constraints: |
    Pas de streaming pour les gros fichiers dans cette version.
```

- `why` : la raison profonde, elicitee par l'orchestrateur apres la question 1 du INIT
- `raw` : le besoin tel que formule par l'utilisateur
- `elicited` : les intentions clarifiees pendant l'echange
- `constraints` : les contraintes identifiees

### Section `log` -- le journal

Trace hierarchique des actions de chaque agent :

```yaml
log:
  - agent: "kiss-orchestrator"
    claude_session: "orchestrator-20260414-153022"
    timestamp: "2026-04-14T15:31:00Z"
    task: "INIT -- Plan genere, CHECKPOINT initialise"
    result: "Plan en 3 phases. Phase 1 : parser CLI, lire donnees, formater CSV."
    children:
      - agent: "kiss-executor"
        claude_session: "executor-20260414-153022"
        timestamp: "2026-04-14T15:45:00Z"
        task: "Parser les arguments CLI"
        result: "src/cli.py cree (42 lignes). Tests unitaires ajoutes."
        children: []
      - agent: "kiss-verificator"
        claude_session: "verificator-20260414-153022"
        timestamp: "2026-04-14T15:50:00Z"
        task: "Review -- Parser les arguments CLI"
        result: "Verdict: approved. No issues found."
        children: []
```

## Utilisation a la fermeture de session

Quand vous dites `close session`, l'orchestrateur lit le CHECKPOINT.yaml pour construire le resume de session dans SESSIONS.json. Le checkpoint est la source de verite pour :
- Ce qui a ete demande (`need`)
- Ce qui a ete fait (`log`)
- Par qui (`agent`)
- Dans quel ordre (`timestamp`)

## Difference entre CHECKPOINT.md et CHECKPOINT.yaml

- **CHECKPOINT.md** : genere par le hook `session-end.sh` a la fin de chaque session Claude. Contient un snapshot de STATE.md, les fichiers modifies et une instruction de reprise. Ecrit via `store.sh write checkpoint`.
- **CHECKPOINT.yaml** : gere par les agents via `store.sh checkpoint init-need` et `store.sh checkpoint upsert`. Contient le besoin structure et le log hierarchique des actions.

Le hook `session-end.sh` ecrit dans la meme resource `checkpoint`, ce qui peut ecraser le CHECKPOINT.yaml si les deux mecanismes coexistent. En pratique, le CHECKPOINT.yaml est le format principal utilise par les agents pour la tracabilite.
