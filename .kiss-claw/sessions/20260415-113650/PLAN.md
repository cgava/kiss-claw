# Test interactif d'agents conversationnels

## Goal
Rendre les scénarios de test fonctionnels en mode interactif (pas seulement --dry-run) en résolvant le problème structurel orchestrateur INIT vs claude -p non-interactif, avec un framework de scénarios structurés.

## Non-goals
- UI graphique pour créer les scénarios
- Couverture exhaustive de tous les edge cases dès la v1
- Remplacement du mode --dry-run existant (il reste utile)

## Phases

### Phase 1 — Recherche état de l'art
- [x] Vocabulaire et taxonomie des tests d'agents conversationnels
- [x] Formats de description de scénarios existants (séquentiel, DAG, FSM, BDD/Gherkin, decision tree)
- [x] Outils et frameworks existants (Claude CLI --resume/stream-json, Inspect AI, promptfoo, deepeval)
- [x] Approches de création de scénarios (manuel, record-replay, human-in-the-loop, hybride)
- [x] Synthèse : tableau comparatif des approches avec pertinence pour kiss-claw

### Phase 2 — Design
- [ ] Choisir le format de description des scénarios (JSON/YAML, structure, extensibilité)
- [ ] Choisir l'approche technique d'interaction (--resume vs stream-json)
- [ ] Analyser les dépendances candidates (avantages/inconvénients vs stdlib)
- [ ] Définir le contrat du runner interactif (API interne, intégration avec runner.py existant)
- [ ] Écrire la spec technique (doc ou dans le scénario lui-même)

### Phase 3 — Implémentation
- [ ] Debug output par défaut dans les scénarios de test (option claude --debug-file)
- [ ] Format de scénario : parser et validateur
- [ ] Runner interactif : exécution pas-à-pas avec --resume ou approche choisie
- [ ] Adaptateur pour le runner.py existant (intégration transparente)
- [ ] Scénario 02-konvert-agents : réécrire en format structuré

### Phase 4 — Validation
- [ ] Exécuter 02-konvert-agents en mode interactif réel (pas --dry-run)
- [ ] Vérifier que --dry-run continue de fonctionner
- [ ] Documenter le format de scénario et le workflow de création
