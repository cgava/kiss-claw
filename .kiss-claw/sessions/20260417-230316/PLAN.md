# Tests agents en isolation Docker

## Goal
Faire tourner les agents testés (SUT) dans un conteneur Docker vierge (via my-claude-minion) tandis que le test runner reste sur le host, garantissant zéro pollution par l'environnement de dev.

## Non-goals
- Modifier my-claude-minion lui-même (on consomme son Docker tel quel)
- Faire tourner le test runner dans Docker
- Supporter d'autres runtimes que Docker

## Phases

### Phase 1 — Analyse & design
- [ ] Auditer l'image Docker my-claude-minion (Dockerfile, entrypoint, mounts)
- [ ] Auditer scenario_runner.py et cli.py — identifier les points d'injection Docker
- [ ] Produire un design document : architecture host↔Docker, interface invoke(), mount strategy
- [ ] Valider le design avec l'utilisateur

### Phase 2 — Adapter invoke() pour le mode Docker
- [ ] Ajouter un paramètre `docker: bool` (ou `isolation: "docker"`) à invoke()
- [ ] Implémenter l'invocation Docker dans cli.py : docker run + mounts (OAuth ro, repo ro, plugin)
- [ ] S'assurer que --no-session-persistence fonctionne en mode Docker
- [ ] Gérer le session resume cross-invocation en mode Docker

### Phase 3 — Intégrer dans le test runner
- [ ] Modifier scenario_runner.py pour propager le flag Docker aux invocations
- [ ] Ajouter un flag CLI (--docker) au test runner
- [ ] Adapter les scénarios existants (01-hello-world, 02-konvert-agents) pour tourner en mode Docker
- [ ] Valider : même scénario passe en local ET en Docker

### Phase 4 — Validation & hardening
- [ ] Test end-to-end : scénario complet orchestrator→executor en Docker
- [ ] Vérifier qu'aucun plugin/hook/MCP du host ne fuit dans le conteneur
- [ ] Documenter l'usage (README tests)
