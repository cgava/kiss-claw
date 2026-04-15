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
- [x] Choisir le format de description des scénarios (JSON séquentiel, extensible YAML v2)
- [x] Choisir l'approche technique d'interaction (--resume chaining)
- [x] Analyser les dépendances candidates (stdlib only v1, PyYAML v2)
- [x] Définir le contrat du runner interactif (scenario_runner.py, StepResult, ScenarioResult)
- [x] Écrire la spec technique (docs/designs/260415-v9-design_interactive_test_runner.md)

### Phase 3 — Implémentation
- [ ] Debug output par défaut dans les scénarios de test (option claude --debug-file)
- [ ] Format de scénario : parser et validateur (scenario_runner.py load_scenario)
- [ ] Runner interactif : exécution pas-à-pas avec --resume (scenario_runner.py run_scenario)
- [ ] Adaptateur pour le runner.py existant (intégration dans run(ctx))
- [ ] Scénario 02-konvert-agents : réécrire scenario.json + refactorer test_konvert_agents.py

### Phase 4 — Validation
- [ ] Exécuter 02-konvert-agents en mode --dry-run (valider le runner)
- [ ] Exécuter 02-konvert-agents en mode interactif réel (pas --dry-run)
- [ ] Vérifier que les scénarios 01 et 03 continuent de fonctionner
- [ ] Documenter le format de scénario et le workflow de création
