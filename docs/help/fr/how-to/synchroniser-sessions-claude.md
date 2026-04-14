# Synchroniser les sessions Claude

Comment copier les transcripts de session Claude Code vers le repertoire kiss-claw du projet.

## Quand synchroniser

Synchronisez apres une session de travail pour :
- Permettre a kiss-improver d'analyser les transcripts
- Conserver un historique des echanges lie au projet
- Croiser les transcripts avec les CHECKPOINT.yaml via les champs `claude_session`

## Synchroniser

```bash
./scripts/sync-sessions.sh
```

Le script :
1. Detecte le slug du projet a partir du chemin absolu
2. Localise les sessions Claude dans `~/.claude/projects/<slug>/`
3. Copie les fichiers `.jsonl` vers `.kiss-claw/claude-sessions/` avec `rsync` (incremental)
4. Affiche un rapport :

```
=== SYNC REPORT ===
Source     : /home/user/.claude/projects/-home-user-mon-projet/
Dest       : .kiss-claw/claude-sessions/
Sessions   : 12 total (3 new)
Sub-agents : 2 directories
Size       : 45 MB
===================
```

## Voir ce qui serait synchronise (dry-run)

```bash
./scripts/sync-sessions.sh --dry-run
```

Affiche les fichiers qui seraient copies sans rien modifier.

## Synchroniser et nettoyer les sources

```bash
./scripts/sync-sessions.sh --clean
```

Apres la synchronisation, le script propose de supprimer les fichiers source :

```
Delete 12 sessions (and 2 sub-agent dirs) from source?
  Source: /home/user/.claude/projects/-home-user-mon-projet/
  Confirm (y/N):
```

Repondez `y` pour confirmer la suppression, ou `N` pour annuler.

En mode dry-run avec `--clean`, le script liste les fichiers qui seraient supprimes sans rien toucher :

```bash
./scripts/sync-sessions.sh --dry-run --clean
```

## Ou vont les fichiers

Les transcripts sont copies dans `.kiss-claw/claude-sessions/`. Chaque session est un fichier `.jsonl` (JSON Lines) contenant tous les messages de la conversation.

## Lien avec CHECKPOINT.yaml

Les entrees du log CHECKPOINT.yaml contiennent un champ `claude_session` qui permet de croiser un point de checkpoint avec le transcript complet de la session Claude correspondante.

Actuellement, les agents utilisent un placeholder descriptif (`"executor-20260414-153022"`) car la resolution automatique des IDs de session Claude n'est pas encore implementee.
