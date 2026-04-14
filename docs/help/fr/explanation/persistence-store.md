# Persistence et store

Pourquoi kiss-claw utilise un script shell centralise pour gerer la persistence, et comment cette couche est concue.

## Le probleme

Dans un systeme multi-agents, chaque agent peut lire et ecrire des fichiers. Sans controle :

- Un agent peut ecraser le travail d'un autre par erreur
- Les chemins de fichiers sont dupliques dans chaque agent (fragilite)
- Il n'y a aucune garantie de coherence entre les fichiers
- Le changement d'un format ou d'un emplacement oblige a modifier tous les agents

## La solution : store.sh

`store.sh` est le **point d'acces unique** pour toute operation de persistence. Les agents ne manipulent jamais les fichiers d'etat directement -- ils passent par `store.sh` (ou son equivalent `/kiss-store`).

Cela centralise :

- **La resolution des chemins** : un seul endroit connait la correspondance entre noms de ressources et chemins de fichiers
- **La creation des repertoires** : `store.sh write` cree automatiquement les repertoires parents
- **La gestion des sessions** : la variable `KISS_CLAW_SESSION` determine quel repertoire de session est cible
- **La validation** : les ressources session-scoped echouent proprement si la session n'est pas definie

## Les 3 scopes de ressources

Les ressources sont organisees en 3 niveaux de portee :

### Session-scoped

Liees a une session de travail specifique. Stockees dans `sessions/<id>/`. Necessitent `KISS_CLAW_SESSION`.

Exemples : `plan`, `state`, `reviews`, `scratch`, `checkpoint`.

Cycle de vie : creees au debut de la session, figees a la fermeture. Chaque nouvelle session a ses propres fichiers.

### Agent-scoped

Liees a un agent specifique. Stockees dans `agents/`. Persistent entre les sessions.

Exemples : `memory:kiss-executor`, `insights`, `analyzed`.

Cycle de vie : accumulent des donnees au fil des sessions. Chaque agent possede sa propre memoire.

### Project-scoped

Partagees par tous les agents. Stockees dans `project/`. Persistent entre les sessions.

Exemples : `memory`, `sessions`.

Cycle de vie : contiennent le contexte global du projet. Mis a jour par des agents specifiques (kiss-improver pour `memory`, kiss-orchestrator pour `sessions`).

## Le guard comme enforcement

La centralisation de `store.sh` est renforcee par le hook `guard.sh` qui bloque les acces directs aux fichiers proteges. Meme si un agent tente d'utiliser `Write` ou `Edit` sur un fichier d'etat, le guard intercepte l'operation.

L'exception : les commandes bash contenant `scripts/store.sh` sont autorisees. C'est le seul chemin valide pour modifier les fichiers proteges.

Ce mecanisme a deux couches :
1. **Convention** : les agents sont instruits d'utiliser `/kiss-store` et `store.sh`
2. **Enforcement** : le guard bloque les violations, meme accidentelles

## Pourquoi `inspect` est le premier appel

Le protocole impose que chaque session d'orchestrateur commence par `store.sh inspect`. Cela sert a :

- Verifier que les variables d'environnement sont correctement resolues
- S'assurer que les chemins pointent vers les bons repertoires (surtout avec des symlinks)
- Diagnostiquer rapidement un probleme de configuration
- Documenter dans le transcript les chemins effectifs (utile pour le debug)

C'est un garde-fou contre les erreurs silencieuses : un repertoire mal configure serait detecte immediatement au lieu de causer des problemes subtils plus tard.

## Design sans dependances

`store.sh` est du bash pur. Pas de jq pour le JSON, pas de yq pour le YAML. Ce choix impose des limites (manipulation de JSON par l'agent lui-meme) mais garantit :

- Zero dependance externe
- Execution sur n'importe quel systeme avec bash
- Pas de gestion de version de dependances
- Portabilite totale

Le compromis est que les operations complexes (comme la gestion hierarchique du CHECKPOINT.yaml) necessitent du code awk/sed sophistique dans `store.sh`, plutot que des appels a des outils dediees.
