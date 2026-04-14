# Cycle de vie d'une session

De la creation a la fermeture : le parcours complet d'une session kiss-claw.

## Vue d'ensemble

```
Creation -> INIT -> Plan -> Execution -> Review -> Close
```

Une session est l'unite de travail fondamentale de kiss-claw. Elle encapsule un besoin, un plan, une execution et un resultat.

## Phase 1 : Creation

Quand kiss-orchestrator est invoque sans argument, il cree une nouvelle session :

1. Genere un ID au format `YYYYMMDD-HHmmss` a partir de l'heure courante
2. Exporte `KISS_CLAW_SESSION=<id>`
3. Ecrit un STATE.md initial via `store.sh write state` (cree le repertoire)
4. Enregistre la session dans SESSIONS.json avec `status: "in_progress"` et `title: ""`

A ce stade, le repertoire de session existe mais ne contient qu'un STATE.md minimal.

## Phase 2 : INIT (protocole de 3 questions)

L'orchestrateur pose 3 questions sequentielles :

1. "What are you building?" -- avec elicitation du pourquoi profond
2. "Main phases or milestones?"
3. "Constraints or non-goals?"

Meme si l'utilisateur a deja fourni toutes les informations dans son message initial, les questions sont posees. Elles servent de points de validation, pas seulement de collecte.

Apres le INIT :
- PLAN.md est ecrit (immutable pour le reste de la session)
- STATE.md est mis a jour avec les phases et l'etape courante
- CHECKPOINT.yaml est initialise avec la section `need` et une premiere entree de log
- SESSIONS.json est mis a jour avec le titre du plan

## Phase 3 : Execution

L'orchestrateur delegue les etapes une par une a kiss-executor :

1. L'orchestrateur identifie la prochaine etape dans le plan
2. Il propose la delegation : "That's kiss-executor territory. Delegate?"
3. Il inscrit la delegation dans CHECKPOINT.yaml
4. kiss-executor recoit la tache avec le contexte de session
5. kiss-executor implemente et produit un task report
6. kiss-executor inscrit son resultat dans CHECKPOINT.yaml

L'etape courante dans STATE.md est mise a jour au fur et a mesure.

## Phase 4 : Review

Apres chaque tache de kiss-executor :

1. kiss-executor propose : "Send to kiss-verificator for review?"
2. kiss-verificator examine les sorties et ecrit un verdict dans REVIEWS.md
3. kiss-verificator inscrit son resultat dans CHECKPOINT.yaml
4. L'orchestrateur est notifie du verdict : `proceed`, `rework`, ou `split`

## Phase 5 : Fermeture

Quand le plan est termine ou que l'utilisateur dit "close session" :

1. L'orchestrateur lit CHECKPOINT.yaml
2. Il synthetise un objet `summary` : need, outcome, files_changed, decisions, next
3. Il met a jour SESSIONS.json : status "done", closed, summary
4. Il met a jour STATE.md : status "done"
5. Il affiche la banniere de fermeture

## Le role de SESSIONS.json

SESSIONS.json est le journal de toutes les sessions. Il sert de :

- **Index** : retrouver rapidement une session passee (`/kiss-orchestrator list`)
- **Memoire structuree** : le summary capture l'essentiel de chaque session sans avoir a relire les transcripts
- **Continuite** : les champs `next` d'une session terminee alimentent le contexte de la suivante

## Pourquoi chaque session a son propre repertoire

L'isolation par repertoire (`sessions/<id>/`) garantit que :

- Les fichiers d'une session n'interfere pas avec ceux d'une autre
- On peut reprendre une ancienne session sans polluer la session courante
- Les donnees de session peuvent etre archivees ou supprimees independamment
- Plusieurs sessions peuvent coexister (bien qu'une seule soit active a la fois)

## La propagation de KISS_CLAW_SESSION

La variable `KISS_CLAW_SESSION` est le lien vital entre les agents et les donnees de session. Sans elle, les ressources session-scoped sont inaccessibles.

L'orchestrateur est responsable de :
1. Definir `KISS_CLAW_SESSION` au demarrage
2. Inclure la variable dans chaque message de delegation
3. S'assurer que chaque agent delegue connait l'ID de session

Si un agent tente d'acceder a `plan`, `state`, `reviews`, `scratch` ou `checkpoint` sans cette variable, `store.sh` retourne une erreur explicite.
