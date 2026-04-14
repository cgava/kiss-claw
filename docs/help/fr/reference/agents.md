# Agents

kiss-claw utilise 4 agents specialises. Chacun a un role distinct, des ressources propres et des contraintes strictes.

## kiss-orchestrator

**Role** : Planificateur et coordinateur. Gere le plan, l'etat et delegue le travail aux autres agents.

### Ressources possedees (lecture/ecriture)

| Ressource   | Acces      |
|------------|------------|
| `plan`      | ecriture   |
| `state`     | ecriture   |
| `scratch`   | ecriture   |
| `sessions`  | ecriture   |
| `memory`    | lecture/ecriture |
| `memory:kiss-orchestrator` | ecriture |
| `checkpoint` | ecriture (via `init-need` et `upsert`) |

### Ressources interdites en ecriture

`reviews`, `insights`, `analyzed`, memoires des autres agents.

### Protocole de demarrage

1. `bash scripts/store.sh inspect`
2. Generer ou recevoir un ID de session
3. `export KISS_CLAW_SESSION=<id>`
4. `bash scripts/store.sh write state` (cree le repertoire)
5. Lire `memory` et `memory:kiss-orchestrator`
6. Determiner le mode : `list`, `resume <id>`, ou nouveau INIT

### Commandes reconnues

| Commande          | Action                                                |
|-------------------|-------------------------------------------------------|
| `list`            | Lister toutes les sessions depuis SESSIONS.json       |
| `resume <id>`     | Reprendre une session existante                       |
| `close session`   | Fermer et synthetiser la session active               |
| `mark done`       | Completer l'etape courante, passer a la suivante      |
| `skip this`       | Sauter l'etape courante                               |
| `I'm blocked on X`| Enregistrer un bloqueur                               |
| `add step: X`     | Ajouter une etape a la phase courante                 |
| `reset phase`     | Effacer les etapes completees de la phase courante    |
| `dry-run on/off`  | Activer/desactiver le mode dry-run                    |

---

## kiss-executor

**Role** : Agent d'implementation. Ecrit le code, cree les fichiers, execute les commandes.

### Ressources possedees (lecture/ecriture)

| Ressource   | Acces      |
|------------|------------|
| `memory:kiss-executor` | ecriture |
| `checkpoint` | ecriture (via `upsert` uniquement) |

### Lecture autorisee

`plan`, `state`, `memory`, `reviews` (en lecture seule).

### Ressources interdites en ecriture

`plan`, `state`, `memory`, `insights`, `analyzed`, `reviews`, memoires des autres agents.

### Protocole de demarrage

1. Lire `memory` et `memory:kiss-executor`
2. Lire `mode` depuis `state`
3. Afficher : `kiss-executor ready -- last task: <last_step ou "none">`
4. Attendre la tache

### Commandes reconnues

Aucune commande propre. Recoit des taches de kiss-orchestrator et produit un task report.

### Comportement dry-run

Si `mode: dry-run` dans STATE.md : decrit les actions avec le prefixe `[dry-run]` sans rien ecrire.

---

## kiss-verificator

**Role** : Agent de review. Examine exclusivement les sorties de kiss-executor.

### Ressources possedees (lecture/ecriture)

| Ressource   | Acces      |
|------------|------------|
| `reviews`   | ecriture   |
| `memory:kiss-verificator` | ecriture |
| `checkpoint` | ecriture (via `upsert` uniquement) |

### Lecture autorisee

`plan`, `state`, `memory`, `memory:kiss-executor`, tous les fichiers du projet.

### Ressources interdites en ecriture

`plan`, `state`, `memory`, `insights`, `analyzed`, memoires des autres agents. Ne modifie jamais les fichiers revus.

### Protocole de demarrage

1. Lire `memory` et `memory:kiss-verificator`
2. Afficher : `kiss-verificator ready -- send me a kiss-executor task report or name the files to review.`
3. Attendre un task report ou une demande de review

### Commandes reconnues

Aucune commande propre. Recoit des demandes de review et produit des verdicts dans REVIEWS.md.

### Ce qui n'est PAS revu

- PLAN.md (domaine de kiss-orchestrator)
- INSIGHTS.md (decision humaine)
- Ses propres reviews passees

---

## kiss-improver

**Role** : Agent d'amelioration continue. Analyse les transcripts de session et propose des ameliorations.

### Ressources possedees (lecture/ecriture)

| Ressource   | Acces      |
|------------|------------|
| `insights`  | ecriture   |
| `analyzed`  | ecriture   |
| `memory:kiss-improver` | ecriture |
| `checkpoint` | ecriture (via `upsert` uniquement) |

### Lecture autorisee

Toutes les ressources en lecture : `plan`, `state`, `reviews`, `memory`, memoires de tous les agents, definitions des agents.

### Ressources interdites en ecriture

`plan`, `state`, `reviews`, `scratch`, `sessions`, `memory`, memoires des autres agents.

### Protocole de demarrage

1. Lire `memory` et `memory:kiss-improver`
2. Detecter les nouveaux transcripts
3. Lancer l'analyse automatique

### Commandes reconnues

| Commande    | Action                                           |
|-------------|--------------------------------------------------|
| `/insights` | Lister les propositions en attente               |
| `/tokens`   | Afficher le rapport de consommation tokens       |
| `accept #N` | Accepter la proposition N                        |
| `reject #N` | Rejeter la proposition N (avec raison optionnelle)|
| `defer #N`  | Reporter la proposition N                        |
| `apply #N`  | Appliquer la proposition N (acceptee)            |
