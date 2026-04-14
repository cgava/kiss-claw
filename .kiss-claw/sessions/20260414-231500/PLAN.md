# Implémentation /kiss-checkpoint-enrich

## Goal
Implémenter le skill d'extraction automatique du contenu verbatim des sessions Claude vers CHECKPOINT.yaml, pour une mémoire projet auto-suffisante.

## Non-goals
- Fallback si pyyaml absent
- Écraser les champs existants non-vides (sauf si contenu extrait significativement plus riche)
- Support d'autres formats que YAML + Markdown blocks
- UI graphique ou dashboard

## Phases

### Phase 1 — Tests unitaires (TDD red)
- [ ] Créer fixtures (JSONL transcript sample + CHECKPOINT.yaml minimal) dans tests/
- [ ] Écrire tests parsing JSONL (extraction blocs substantiels assistant)
- [ ] Écrire tests classification blocs (artifacts, decisions, issues, rationale)
- [ ] Écrire tests enrichissement YAML (injection champs, non-écrasement existants)
- [ ] Écrire tests modes CLI (--step, batch, --dry-run)
- [ ] Vérifier que tous les tests échouent (red)

### Phase 2 — Script Python checkpoint-enrich.py (TDD green)
- [ ] Implémenter parsing JSONL et extraction blocs substantiels
- [ ] Implémenter classification des blocs extraits
- [ ] Implémenter enrichissement YAML (lecture/écriture CHECKPOINT)
- [ ] Implémenter mode --step (un seul step par claude_session)
- [ ] Implémenter mode batch (tout le CHECKPOINT)
- [ ] Implémenter --dry-run
- [ ] Tous les tests passent (green)

### Phase 3 — Skill slash command + adaptation agents
- [ ] Créer commands/kiss-checkpoint-enrich.md
- [ ] Modifier kiss-orchestrator/agent.md (CHECKPOINT tracking + délégation template)
- [ ] Modifier kiss-executor/agent.md (appel enrich après upsert)
- [ ] Modifier kiss-verificator/agent.md (appel enrich après upsert)
- [ ] Modifier kiss-improver/agent.md (appel enrich après upsert)

### Phase 4 — Validation sur données réelles
- [ ] Enrichir CHECKPOINT session 082706
- [ ] Enrichir CHECKPOINT session 143500
- [ ] Enrichir CHECKPOINT session 170500
- [ ] Enrichir CHECKPOINT session 180629

### Phase 5 — Test d'intégration (extension 02-konvert-agents)
- [ ] Étendre 02-konvert-agents pour vérifier qu'un CHECKPOINT enrichi est produit après le workflow agents
