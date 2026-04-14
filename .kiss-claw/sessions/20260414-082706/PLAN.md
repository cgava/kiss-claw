# CHECKPOINT.yaml + Journal évolutions projet

## Goal
Implémenter CHECKPOINT.yaml session-scoped avec traçabilité complète (besoin → agents → sessions Claude) et enrichir SESSIONS.json comme journal grosse maille du projet.

## Non-goals
- Réparer les hooks (cassés, hors scope — ISSUE-005)
- Dépendances externes
- UI graphique
- Modifier le format des autres resources (state, plan, etc.)

## Constraints
- Les descriptions (task, steps, result) dans CHECKPOINT.yaml doivent être quasi-identiques aux messages affichés par les agents en fin de tâche (verbatim, pas résumé)
- store.sh gère toutes les écritures CHECKPOINT : upsert par claude_session ID. Les agents ne lisent jamais le CHECKPOINT complet — ils passent leur session ID + données, store.sh fait le reste
- Format YAML (pas JSON) pour lisibilité multi-ligne
- Shell pur, zéro dépendance
- Phase de transition : tant que le mécanisme checkpoint n existe pas, un script temporaire rétro-alimente le CHECKPOINT.yaml de la session courante (20260414-082706) pour que les agents modifiés trouvent leurs données

## Phases

### Phase 0 — Bootstrap CHECKPOINT de cette session
- [ ] Écrire manuellement le CHECKPOINT.yaml de la session 20260414-082706 avec le besoin détaillé
- [ ] Préparer un script temporaire (scripts/backfill-checkpoint.sh) qui rétro-alimente le CHECKPOINT.yaml de cette session au fur et à mesure des phases (appelé entre chaque phase pour logger ce qui s est passé)

### Phase 1 — store.sh : support CHECKPOINT.yaml
- [ ] Définir le schéma YAML de CHECKPOINT (need + log hiérarchique)
- [ ] Ajouter resource `checkpoint` dans store.sh : read, write (full), upsert (par claude_session)
- [ ] Commande `store.sh checkpoint upsert <claude_session>` qui accepte les champs en stdin ou args
- [ ] Commande `store.sh checkpoint init-need` pour écrire la section need (orchestrator only)
- [ ] Tests manuels store.sh checkpoint (read, init-need, upsert, upsert avec children)

### Phase 2 — Agents : instrumentation CHECKPOINT
- [ ] kiss-orchestrator : init CHECKPOINT.yaml au INIT (section need complète) + log son entrée
- [ ] kiss-orchestrator : à chaque délégation, passe les instructions checkpoint à l agent délégué
- [ ] kiss-executor : en fin de tâche, appelle store.sh checkpoint upsert avec task + result détaillés
- [ ] kiss-verificator : en fin de review, appelle store.sh checkpoint upsert avec review + verdict
- [ ] kiss-improver : en fin d analyse, appelle store.sh checkpoint upsert avec insights trouvés

### Phase 3 — SESSIONS.json : journal évolutions + sync
- [ ] Enrichir SESSIONS.json : ajouter champ summary (need, outcome, files_changed, decisions, next)
- [ ] Commande orchestrator `close session` : synthétise CHECKPOINT.yaml → summary dans SESSIONS.json
- [ ] Script scripts/sync-sessions.sh : rsync sessions .claude/projects → .kiss-claw/sessions/<id>/claude/
- [ ] sync-sessions.sh --clean : propose nettoyage des sessions sources après sync
- [ ] Documenter le workflow complet dans CLAUDE.md
