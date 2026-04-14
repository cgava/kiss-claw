# Commandes slash

Commandes slash disponibles dans kiss-claw, utilisables dans une session Claude Code.

## /kiss-store

**Usage** :

```
/kiss-store <action> <resource> [arguments...]
```

**Description** : Wrapper autour de `scripts/store.sh`. Toutes les operations de persistence passent par cette commande.

**Actions** :

| Action    | Description                              |
|-----------|------------------------------------------|
| `read`    | Lire le contenu d'une ressource          |
| `write`   | Ecrire (ecraser) une ressource           |
| `append`  | Ajouter du contenu a une ressource       |
| `update`  | Mettre a jour un champ YAML              |
| `exists`  | Verifier si une ressource existe         |
| `list`    | Lister les ressources disponibles        |
| `inspect` | Afficher la configuration resolue        |

**Exemples** :

```
/kiss-store read plan
/kiss-store exists scratch
/kiss-store update state current_step "1.3 Tests"
/kiss-store read memory:kiss-executor
```

Reference complete : [store.sh](store-sh.md)

---

## /kiss-orchestrator

**Usage** :

```
/kiss-orchestrator [list | resume <id>]
```

**Description** : Invoque l'agent orchestrateur. Sans argument, cree une nouvelle session et lance le protocole INIT.

**Arguments** :

| Argument       | Description                            |
|----------------|----------------------------------------|
| (aucun)        | Nouvelle session + protocole INIT      |
| `list`         | Lister toutes les sessions             |
| `resume <id>`  | Reprendre la session `<id>`            |

---

## /kiss-executor

**Usage** :

```
/kiss-executor
```

**Description** : Invoque l'agent d'implementation. Attend une tache deleguee par kiss-orchestrator ou une demande directe.

**Arguments** : aucun. La tache est fournie dans le message.

---

## /kiss-verificator

**Usage** :

```
/kiss-verificator
```

**Description** : Invoque l'agent de review. Attend un task report de kiss-executor ou une demande de review.

**Arguments** : aucun. Le sujet de review est fourni dans le message.

---

## /kiss-improver

**Usage** :

```
/kiss-improver [/insights | /tokens]
```

**Description** : Invoque l'agent d'amelioration. Sans argument, lance l'analyse automatique des nouveaux transcripts.

**Arguments** :

| Argument    | Description                              |
|-------------|------------------------------------------|
| (aucun)     | Analyser les nouveaux transcripts        |
| `/insights` | Lister les propositions en attente       |
| `/tokens`   | Afficher le rapport de consommation      |

**Sous-commandes interactives** (dans le contexte d'une session `/insights`) :

| Commande       | Description                              |
|----------------|------------------------------------------|
| `accept #N`    | Accepter la proposition N                |
| `reject #N`    | Rejeter la proposition N                 |
| `defer #N`     | Reporter la proposition N                |
| `apply #N`     | Appliquer la proposition N (acceptee)    |
