# ISSUES

## ISSUE-006 — Token stats réactivation

**Status**: open
**Priority**: low
**Created**: 2026-04-13

Token consumption tracking (TOKEN_STATS.md) a été désactivé lors de la refonte persistence multi-session v7.
À réactiver quand l'architecture multi-session sera stabilisée.

Décision à prendre :
- Token stats par session ? Par projet ? Cumulatif agents ?
- Format : Markdown ou JSON ?

# LOG 

## 2026-04-13 - .kiss-claw folder multi dir
OBSERVATION: Quand j'utilisais kiss-claw dans un autre projet, l'init recréait des fichiers MEMORY_xxx vierges, et donc pas de possibilité de capitaliser
SOLUTION: Lors de l'init, permettre de séparer kiss-claw en sous dossiers (persistance du projet, des agents à travers de multiples projets, des sessions, avec plusieurs sessions actives possibles)

## 2026-04-14 - Il va falloir robustifier
L'instanciation du framework avec un autre LLM (sonnet), n'a pas du tout respecté le plan (le fichier PLAN n'est pas dans le dossier .kiss-claw, mais dans .omc)
- tests de non regressions (rajouter des tests de non regression plus fins : faire des init différents, lancer un plan, et vérifier si le plan et les fichiers utilisés sont au bon endroit)
- Mettre de la traçabilité et rajouter des commandes permettant à l'agent de lister ses règles kiss-claw, dans l'ordre 
- rajouter une intention  (un besoin) dans les règles, exemple:
Afin d'être robuste à un crash ou une divergence, l'agent (kiss-orchestrator), doit MUST update each PLAN.md checkbox immediately after the corresponding item is completed (not wait for end of phase)
en fait cette directive n'est jamais appliquée..

## 2026-04-14 - Commande de nettoyage MEMORY vs Projet et historique
Les MEMORY du projet ne sont régulièrement plus alignées avec les contraintes, il faut analyser et auditer pour nettoyer et réaligner
C'est dans l'idée de supprimer aussi, comme dans le protocole elon

## 2026-04-14 - Transformer le sessions en skill
Pour optimiser l'implémentation file de kiss-store, surtout pour les sessions et checkpoint de chaque sessions (qui sont une connaissance précieuse du projet), il 
