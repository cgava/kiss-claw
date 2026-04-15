# Enrichissement CHECKPOINT.yaml — mémoire projet auto-suffisante

## Goal
Rendre les CHECKPOINT.yaml exploitables pour retex et transfert de contexte inter-agents, en extrayant le contenu verbatim des sessions Claude, et spécifier un skill d'extraction automatique.

## Non-goals
- Modifier store.sh dans cette session (implémentation du skill = session suivante)
- Supprimer les sessions Claude brutes (le CHECKPOINT enrichi les remplace à terme, mais pas maintenant)
- Refondre l'architecture des agents

## Phases

### Phase 1 — Recherche : état de l'art extraction de prompts pour boucle de rétroaction
- [ ] Recherche web : meilleures pratiques d'extraction de prompts/réponses pour améliorer des agents (retex, feedback loop, context transfer)
- [ ] Synthèse : quelles données extraire (messages clés, décisions, erreurs, tableaux, métriques) et quel format (YAML, markdown, mixte)
- [ ] Recommandation format : YAML pur vs markdown embarqué vs mix, avec justification

### Phase 2 — Prototype : enrichissement CHECKPOINT session 20260413-223433
- [ ] Extraire le contenu verbatim de la session Claude référencée (orchestrator + subagents)
- [ ] Produire un CHECKPOINT enrichi au nouveau format proposé
- [ ] Présenter à l'utilisateur pour validation / ajustements

### Phase 3 — Spécification : skill d'extraction + adaptation agents
- [ ] Spécifier le skill /kiss-extract (ou nom retenu) : inputs, outputs, invocation par les agents
- [ ] Spécifier les adaptations nécessaires dans les 4 agent.md pour invoquer ce skill
- [ ] Documenter le workflow complet (agent fait une étape → invoque le skill → CHECKPOINT enrichi automatiquement)
