# obsidian-wiki dual-sensitivity (s0/s2)

## Goal
Permettre à obsidian-wiki de fonctionner en dual-zone (s0 public, s2 privé) avec isolation déterministe par configuration, cross-linking asymétrique (s2→s0 uniquement), en vue de 2 chaînes LLM distinctes.

## Non-goals
- Pas d'a priori technique (tout est évaluable)
- Pas de logique conditionnelle dans les skills eux-mêmes

## Phases

### Phase 1 — Évaluation des solutions
- [ ] Inventorier les mécanismes possibles (multi-.env, wrapper script, profils, symlinks, namespace dans config, etc.)
- [ ] Analyser comment chaque skill résout ses chemins (OBSIDIAN_VAULT_PATH, OBSIDIAN_RAW_DIR, etc.)
- [ ] Produire une matrice de comparaison (difficulté, avantages, inconvénients, impact sur skills upstream)
- [ ] Recommander une solution avec justification

### Phase 2 — Implémentation du mécanisme de contexte
- [ ] Implémenter la solution retenue
- [ ] Adapter la config pour s0 et s2
- [ ] Valider que chaque skill, appelé en contexte s0 ou s2, travaille dans le bon périmètre

### Phase 3 — Ingest isolé
- [ ] Tester _raw/s0 → vault/s0 (ingest en contexte s0)
- [ ] Tester _raw/s2 → vault/s2 (ingest en contexte s2)
- [ ] Vérifier qu'aucune donnée ne fuite entre zones

### Phase 4 — Maintenance isolée
- [ ] wiki-status, wiki-lint, cross-linker, tag-taxonomy en contexte s0
- [ ] Mêmes skills en contexte s2
- [ ] Vérifier l'isolation des résultats

### Phase 5 — Cross-linking asymétrique
- [ ] Implémenter le mécanisme s2→s0 (vault/s2 peut référencer vault/s0)
- [ ] Bloquer s0→s2 (vault/s0 ne peut jamais référencer vault/s2)
- [ ] Tester et valider la directionnalité

### Phase 6 — Validation POC
- [ ] Démontrer les 2 chaînes indépendantes
- [ ] Documenter le mécanisme final
