# Documentation Diátaxis kiss-claw

## Goal
Générer une documentation complète structurée selon le framework Diátaxis (tutorials, how-to, reference, explanation) dans `docs/help/fr/`, parcourable par les agents via un skill `kiss-help`.

## Non-goals
- Refactoring du code existant
- Site web externe ou générateur de doc
- Traduction anglaise (sera dans `docs/help/en/` plus tard)
- Modification des agents existants (sauf ajout du skill kiss-help)

## Phases

### Phase 1 — Structure et contenu Diátaxis
- [ ] Créer l'arborescence `docs/help/fr/` avec index et 4 sections
- [ ] Tutorials : guide de démarrage (première session kiss-claw de A à Z)
- [ ] How-to : guides pratiques (sync sessions, checkpoints, close session, dry-run, store.sh, etc.)
- [ ] Reference : commandes store.sh, variables d'env, formats fichiers, protocoles agents
- [ ] Explanation : architecture multi-agent, cycle de vie session, design checkpoint, guard system

### Phase 2 — Skill kiss-help
- [ ] Créer le skill `kiss-help` (command + script) pour rechercher/afficher la doc
- [ ] Intégrer dans les commandes slash existantes (commands/)
- [ ] Tester que les agents peuvent consulter la doc via le skill

### Phase 3 — Intégration workflow
- [ ] Ajouter des suggestions de doc dans agent-suggest.sh (hook Stop)
- [ ] Documenter le skill kiss-help dans la doc elle-même (meta-doc)
- [ ] Valider le parcours complet : nouvel utilisateur → doc → première session
