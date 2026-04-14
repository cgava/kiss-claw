# Gerer les sessions

Comment creer, lister, reprendre et fermer des sessions kiss-claw.

## Creer une session

Une session est creee automatiquement quand vous invoquez kiss-orchestrator sans argument :

```
/kiss-orchestrator
```

L'orchestrateur :
1. Genere un identifiant au format `YYYYMMDD-HHmmss` (ex: `20260414-153022`)
2. Cree le repertoire de session sous `.kiss-claw/sessions/<id>/`
3. Enregistre la session dans `SESSIONS.json`
4. Lance le protocole INIT (3 questions)

Apres le INIT, la session contient :
- `PLAN.md` -- le plan immutable
- `STATE.md` -- l'etat de progression
- `CHECKPOINT.yaml` -- la tracabilite

## Lister les sessions

```
/kiss-orchestrator list
```

Affiche un tableau de toutes les sessions enregistrees :

```
=== SESSIONS ===
ID                | Created              | Status      | Title
------------------|----------------------|-------------|---------------------------
20260414-153022   | 2026-04-14T15:30:22  | in_progress | Export CSV CLI
20260413-091500   | 2026-04-13T09:15:00  | done        | Initial setup
================
```

S'il n'y a aucune session :

```
Aucune session. Creez-en une avec kiss-orchestrator.
```

## Reprendre une session

```
/kiss-orchestrator resume 20260414-153022
```

L'orchestrateur :
1. Verifie que le repertoire de session existe
2. Charge STATE.md et PLAN.md
3. Compte les insights en attente
4. Affiche le resume de session :

```
=== SESSION RESUME ===
Agent    : kiss-orchestrator
Session  : 20260414-153022
Phase    : Phase 1
Last done: Parser les arguments CLI
Blocked  : none
Next     : Lire les donnees depuis la base
Insights : 2 pending
=====================
```

Si la session n'existe pas :

```
Session "20260414-999999" not found. Use "list" to see available sessions.
```

## Fermer une session

Dites a l'orchestrateur :

```
close session
```

L'orchestrateur :
1. Lit le CHECKPOINT.yaml
2. Construit un objet `summary` avec : `need`, `outcome`, `files_changed`, `decisions`, `next`
3. Met a jour SESSIONS.json : `status` passe a `"done"`, ajout de `closed` et `summary`
4. Met a jour STATE.md : `status` passe a `"done"`
5. Affiche la banniere de fermeture

Le resume est synthetise a partir du CHECKPOINT -- il capture l'intention d'origine, les livrables concrets, les decisions majeures et les suites eventuelles.

## Format SESSIONS.json

Chaque session est enregistree dans SESSIONS.json. Les sessions fermees incluent un objet `summary` synthetise a partir du CHECKPOINT.

Pour le format complet avec tous les champs et exemples, voir [Formats de fichiers -- SESSIONS.json](../reference/formats-fichiers.md#sessionsjson).
