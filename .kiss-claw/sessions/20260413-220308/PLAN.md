# kiss-claw — Refonte persistence multi-session

## Goal
Restructurer .kiss-claw/ en 3 sous-dossiers (agents, project, sessions) avec chemins configurables via variables d'environnement, symlinks possibles, et support multi-session.

## Non-goals
- Dépendances externes (jq, npm, pip)
- Token stats (désactivé — voir ISSUES)
- UI graphique
- Suffixe de nom de session à la création

## Phases

### Phase 1 — Core : store.sh refonte
- [ ] 1.1 — Refactorer resolve() : 3 catégories (agents/, project/, sessions/) avec variables d'env
- [ ] 1.2 — Ajouter résolution KISS_CLAW_SESSION pour ressources session (plan, state, reviews, scratch, checkpoint)
- [ ] 1.3 — Retirer token-stats du resolve/reverse_map, créer ISSUE
- [ ] 1.4 — Adapter reverse_map() et action list à la nouvelle arborescence
- [ ] 1.5 — Ajouter ressource sessions mappée sur project/SESSIONS.json

### Phase 2 — Init : init.sh interactif
- [ ] 2.1 — Dialogue interactif pour chaque sous-dossier (agents, project, sessions) : défaut / autre chemin / symlink
- [ ] 2.2 — Créer la structure (mkdir/symlink) selon les choix
- [ ] 2.3 — Copier templates dans les bons emplacements (agents/ et project/)
- [ ] 2.4 — Initialiser project/SESSIONS.json vide
- [ ] 2.5 — Mettre à jour .gitignore

### Phase 3 — Session management dans kiss-orchestrator
- [ ] 3.1 — Commande list : lire sessions/, afficher nom + statut depuis SESSIONS.json
- [ ] 3.2 — Commande resume <nom> : setter KISS_CLAW_SESSION, charger state + plan, afficher session brief
- [ ] 3.3 — Commande vide (nouvelle session) : créer dossier YYYYMMDD-HHmmss, setter KISS_CLAW_SESSION, protocole INIT
- [ ] 3.4 — Propager KISS_CLAW_SESSION aux agents délégués
- [ ] 3.5 — Mettre à jour project/SESSIONS.json à chaque création/clôture

### Phase 4 — Adaptation agents + hooks
- [ ] 4.1 — guard.sh : adapter chemins protégés aux sous-dossiers
- [ ] 4.2 — session-end.sh : adapter chemins checkpoint vers session active
- [ ] 4.3 — Agents (×4) : documenter nouvelle convention dans agent.md
- [ ] 4.4 — hooks.json : adapter mkdir du SessionStart

### Phase 5 — Tests + documentation
- [ ] 5.1 — Adapter test-store.sh (3 sous-dossiers + session active)
- [ ] 5.2 — Adapter test-e2e.sh (multi-session, symlinks)
- [ ] 5.3 — Mettre à jour CLAUDE.md, README.md, README-fr.md
- [ ] 5.4 — Mettre à jour commands/kiss-store.md
