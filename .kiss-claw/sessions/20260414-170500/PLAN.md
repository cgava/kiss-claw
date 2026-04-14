# Restructuration CHECKPOINT.yaml — référentiel correct

## Goal
Reconstruire les CHECKPOINT.yaml des 2 sessions passées avec les vrais claude_session IDs, puis vérifier que les agents peuvent récupérer leur propre ID de session Claude au runtime.

## Non-goals
- Refonte de store.sh au-delà du format log
- Automatisation complète du mapping (le backfill manuel est OK)
- Modification des hooks

## Phases

### Phase 1 — Backfill : reconstruire les 2 CHECKPOINT.yaml
- [ ] Écrire le CHECKPOINT.yaml corrigé pour session 20260414-082706 (mapping complet depuis l'analyse)
- [ ] Écrire le CHECKPOINT.yaml corrigé pour session 20260414-143500
- [ ] Valider la cohérence timestamps / claude_session IDs

### Phase 2 — Runtime : les agents peuvent-ils récupérer leur claude_session ID ?
- [ ] Investiguer comment un subagent Claude Code peut connaître son propre ID de session
- [ ] Tester un mécanisme de récupération (variable d'env, fichier meta, API interne)
- [ ] Si possible, proposer le patch minimal pour que les agents écrivent le bon ID dans checkpoint upsert
