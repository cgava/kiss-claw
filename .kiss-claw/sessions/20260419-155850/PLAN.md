# Bilan évolutions kiss-claw

## Goal
Reconstituer le "pourquoi" des évolutions majeures de kiss-claw à partir des sessions Claude et des CHECKPOINT.yaml existants, puis le consolider en sections courtes (FR) dans le README.md.

## Non-goals
- Pas de refactoring du code
- Pas de modification des CHECKPOINT.yaml déjà complets
- Pas de création de nouveau format/outil (réutilisation de `kiss-enrich-checkpoint`)
- Pas de contrainte budget tokens
- Pas de création de PR/release — juste la mise à jour README

## Phases

### Phase 1 — Inventaire
- [ ] Sync claude-sessions (`bash scripts/sync-sessions.sh`)
- [ ] Lister les `.jsonl` disponibles dans `.kiss-claw/claude-sessions/`
- [ ] Lister les sessions kiss-claw dans SESSIONS.json
- [ ] Mapper claude_session ↔ kiss-claw session via CHECKPOINT.yaml existants
- [ ] Identifier les sessions Claude orphelines (sans session kiss-claw associée)
- [ ] Identifier les sessions kiss-claw avec CHECKPOINT incomplet ou manquant

### Phase 2 — Reconstitution
- [ ] Pour chaque session kiss-claw sans CHECKPOINT enrichi : invoquer `/kiss-claw:kiss-enrich-checkpoint`
- [ ] Pour sessions Claude orphelines ayant apporté une évolution majeure : créer l'entrée kiss-claw correspondante

### Phase 3 — Synthèse du pourquoi
- [ ] Regrouper les sessions par évolution majeure (v5.x, v6, v7, CHECKPOINT, kiss-store, Docker, tests, etc.)
- [ ] Pour chaque évolution : extraire déclencheur, contexte, décision, résultat
- [ ] Rédiger une section courte (FR) par évolution

### Phase 4 — README
- [ ] Intégrer la synthèse dans README.md (section FR `## Historique des évolutions` ou équivalent)
- [ ] Commit final avec référence à cette session
