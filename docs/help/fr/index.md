# Documentation kiss-claw

kiss-claw est un plugin d'orchestration multi-agents pour Claude Code. Quatre agents specialises (orchestrator, executor, verificator, improver) coordonnent via des fichiers d'etat persistants pour planifier, implementer, reviewer et ameliorer du code.

## Tutorials

Lecons guidees pas a pas pour debutants.

- [Premiere session](tutorials/premiere-session.md) -- Decouvrir kiss-claw de A a Z avec une session complete

## Guides pratiques (How-to)

Recettes pour accomplir un objectif precis.

- [Gerer les sessions](how-to/gerer-sessions.md) -- Creer, lister, reprendre, fermer une session
- [Synchroniser les sessions Claude](how-to/synchroniser-sessions-claude.md) -- Syncer les transcripts Claude vers `.kiss-claw/`
- [Utiliser les checkpoints](how-to/utiliser-checkpoints.md) -- Comprendre et exploiter CHECKPOINT.yaml
- [Utiliser le store](how-to/utiliser-store.md) -- Operations `/kiss-store` (read, write, append, update, exists, list)
- [Mode dry-run](how-to/mode-dry-run.md) -- Activer et desactiver le mode dry-run
- [Initialiser un projet](how-to/initialiser-projet.md) -- `init.sh` et configuration des repertoires
- [Boucle d'amelioration](how-to/boucle-amelioration.md) -- kiss-improver : analyser, insights, appliquer

## Reference

Descriptions techniques factuelles. A consulter, pas a lire de bout en bout.

- [store.sh](reference/store-sh.md) -- Reference complete du script de persistence
- [Variables d'environnement](reference/variables-environnement.md) -- Toutes les variables `KISS_CLAW_*`
- [Formats de fichiers](reference/formats-fichiers.md) -- Formats YAML/JSON/Markdown de tous les fichiers d'etat
- [Agents](reference/agents.md) -- Les 4 agents : roles, ressources, contraintes
- [Hooks](reference/hooks.md) -- hooks.json, guard.sh, session-end.sh, agent-suggest.sh
- [Commandes slash](reference/skills-commandes.md) -- Commandes slash disponibles

## Explanation

Contexte, rationale et decisions de design. Repond au "pourquoi".

- [Architecture](explanation/architecture.md) -- Pourquoi 4 agents ? Pourquoi cette separation ?
- [Cycle de vie d'une session](explanation/cycle-vie-session.md) -- De la creation a la fermeture
- [Persistence et store](explanation/persistence-store.md) -- Pourquoi store.sh ? Design de la couche de persistence
- [Protection des fichiers](explanation/protection-fichiers.md) -- Le systeme guard et pourquoi les fichiers sont proteges
- [Design des checkpoints](explanation/checkpoint-design.md) -- Pourquoi CHECKPOINT.yaml, tracabilite, hierarchie agents
