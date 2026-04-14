# Design des checkpoints

Pourquoi CHECKPOINT.yaml existe, comment il capture l'intention et la tracabilite, et les compromis temporaires.

## Le besoin

Une session kiss-claw implique plusieurs agents qui travaillent sequentiellement. A la fin, il faut pouvoir repondre a :

- Qu'est-ce qui a ete demande ? (le besoin original)
- Pourquoi ? (la raison profonde)
- Qu'est-ce qui a ete fait ? (les actions de chaque agent)
- Dans quel ordre ? (la chronologie)
- Par qui ? (l'attribution)
- Qu'est-ce qui reste ? (les suites)

Sans un fichier de tracabilite structure, ces informations sont dispersees dans les transcripts Claude (volumineux, non structures) ou dans STATE.md (qui ne capture que l'etat courant, pas l'historique).

## CHECKPOINT.yaml vs ancien CHECKPOINT.md

### CHECKPOINT.md (hook session-end)

L'ancien format etait genere automatiquement par le hook `session-end.sh` a la fin de chaque session Claude. Il contenait :

- Un snapshot de STATE.md
- La liste des fichiers modifies
- Une instruction de reprise

C'est un fichier de **resume technique** pour la reprise de contexte. Il repond a "ou en etais-je ?" mais pas a "pourquoi je faisais ca" ni "qui a fait quoi".

### CHECKPOINT.yaml (store.sh)

Le nouveau format est gere activement par les agents pendant la session. Il contient :

- Le besoin structure (section `need`)
- Le log hierarchique des actions (section `log`)

C'est un fichier de **tracabilite complete** qui repond a toutes les questions listees ci-dessus.

## La structure `need`

La section `need` capture l'intention a plusieurs niveaux :

```yaml
need:
  why: |
    Raison profonde : les exports manuels prennent 2h par semaine
    Categorie : feature
  raw: |
    Ajouter une commande CLI pour exporter en CSV
  elicited: |
    Export CSV avec filtres par date. Format standard RFC 4180.
  constraints: |
    Pas de streaming. Pas d'Excel. Fichiers < 100MB uniquement.
```

### Pourquoi `why` ?

Le champ `why` est elicite par kiss-orchestrator apres la premiere question du INIT. L'objectif est de capturer la **raison profonde** derriere la demande, pas seulement la demande elle-meme.

Exemples de raisons profondes :
- "Les exports manuels prennent 2h par semaine" (productivite)
- "Le client a besoin de ces donnees pour son audit" (contrainte externe)
- "Le code actuel est impossible a maintenir" (dette technique)

Cette information est precieuse pour :
- Prendre les bonnes decisions d'implementation (optimiser pour le bon objectif)
- Synthetiser la session a la fermeture
- Donner du contexte a kiss-improver pour ses analyses

Si l'utilisateur ne souhaite pas detailler, le champ contient `"Non elicite -- l'utilisateur n'a pas souhaite detailler"`.

### Pourquoi `raw` vs `elicited` ?

- `raw` : le besoin tel que formule par l'utilisateur, verbatim. Pas d'interpretation.
- `elicited` : les intentions clarifiees pendant l'echange INIT. C'est la comprehension partagee entre l'utilisateur et l'orchestrateur.

Garder les deux permet de verifier a posteriori si la comprehension etait correcte.

## Le log hierarchique

Le log utilise une structure parent-enfants pour tracer les delegations :

```yaml
log:
  - agent: "kiss-orchestrator"
    claude_session: "orchestrator-20260414-153022"
    task: "INIT -- Plan genere"
    children:
      - agent: "kiss-executor"
        claude_session: "executor-20260414-153022"
        task: "Implementer le parser CLI"
        children: []
      - agent: "kiss-verificator"
        claude_session: "verificator-20260414-153022"
        task: "Review -- Parser CLI"
        children: []
```

Cette hierarchie montre explicitement :
- L'orchestrateur a delegue au executor (parent -> enfant)
- L'orchestrateur a delegue au verificator (parent -> enfant)
- L'ordre chronologique (timestamps)

C'est plus riche qu'une liste plate : on voit la **causalite**, pas seulement la sequence.

## Placeholder session IDs

Les champs `claude_session` contiennent actuellement des placeholders descriptifs :

- `"orchestrator-20260414-153022"`
- `"executor-20260414-153022"`
- `"verificator-20260414-153022"`

Ces placeholders ne sont pas les vrais IDs de session Claude Code. Dans le contexte actuel, les agents ne peuvent pas determiner automatiquement leur ID de session Claude.

C'est un **compromis temporaire**. Le script `sync-sessions.sh` copie les transcripts Claude dans `.kiss-claw/claude-sessions/`, mais la correlation entre un placeholder et un transcript reel necessite une resolution manuelle ou un futur mecanisme de sync automatique.

Le format CHECKPOINT.yaml est concu pour supporter les vrais IDs sans changement de structure : il suffit de remplacer les placeholders par les IDs reels.

## Upsert : insertion ou mise a jour

La commande `checkpoint upsert` est idempotente :

- Si `claude_session` n'existe pas dans le fichier : **insere** une nouvelle entree
- Si `claude_session` existe deja : **met a jour** les champs existants

Cela permet a un agent d'ecrire un premier resultat ("en cours") puis de le mettre a jour ("termine") sans creer de doublons.

## Utilisation a la fermeture

Quand l'utilisateur dit "close session", l'orchestrateur lit CHECKPOINT.yaml et en extrait :

- Le besoin (de `need`) pour le champ `summary.need` de SESSIONS.json
- Les livrables (des `result` du log) pour le champ `summary.outcome`
- Les fichiers (des `result` ou de git) pour `summary.files_changed`
- Les decisions (interpretation par l'orchestrateur) pour `summary.decisions`
- Les suites (ce qui n'a pas ete fait) pour `summary.next`

Le CHECKPOINT est donc la **matiere premiere** de la synthese de session.
