# Hooks

Hooks Claude Code configures dans `hooks/hooks.json`. Ils s'executent automatiquement a differents moments du cycle de vie d'une session.

## Configuration (hooks.json)

```json
{
  "hooks": {
    "SessionStart": [...],
    "PreToolUse": [...],
    "Stop": [...],
    "SessionEnd": [...]
  }
}
```

---

## SessionStart

**Trigger** : au demarrage de chaque session Claude Code.

**Matcher** : `*` (toutes les sessions).

**Commande** :

```bash
KC_DIR="${KISS_CLAW_DIR:-.kiss-claw}"
mkdir -p "${KISS_CLAW_AGENTS_DIR:-$KC_DIR/agents}" \
         "${KISS_CLAW_PROJECT_DIR:-$KC_DIR/project}" \
         "${KISS_CLAW_SESSIONS_DIR:-$KC_DIR/sessions}"
```

**Comportement** : cree les repertoires kiss-claw s'ils n'existent pas encore. Garantit que la structure minimale est presente avant toute operation.

---

## PreToolUse -- guard.sh

**Trigger** : avant chaque utilisation d'un outil d'ecriture.

**Matcher** : `Write|Edit|str_replace_based_edit_tool|Bash`.

**Script** : `hooks/guard.sh`

**Comportement** : verifie si le fichier cible est un fichier protege. Si oui, bloque l'operation avec un message expliquant quel agent est proprietaire.

### Fichiers proteges

| Fichier                    | Emplacement   | Proprietaire       |
|---------------------------|---------------|-------------------|
| `MEMORY_kiss-*.md`         | agents/       | L'agent lui-meme   |
| `INSIGHTS.md`              | agents/       | kiss-improver      |
| `ANALYZED.md`              | agents/       | kiss-improver      |
| `MEMORY.md`                | project/      | kiss-improver      |
| `PLAN.md`                  | sessions/*/   | kiss-orchestrator  |
| `STATE.md`                 | sessions/*/   | kiss-orchestrator  |
| `CHECKPOINT.md`            | sessions/*/   | kiss-orchestrator  |
| `REVIEWS.md`               | sessions/*/   | kiss-verificator   |

### Exceptions

- Les commandes passant par `scripts/store.sh` sont toujours autorisees. Le guard detecte `scripts/store.sh` dans la commande bash et laisse passer.
- Les outils Write/Edit sur des fichiers non proteges passent sans blocage.

### Message de blocage

```
BLOCK: .kiss-claw/sessions/20260414-153022/PLAN.md is a protected session file.
Only kiss-orchestrator may write to it via /kiss-store.
  Owners: PLAN.md/STATE.md/CHECKPOINT.md -> kiss-orchestrator, REVIEWS.md -> kiss-verificator
```

### Protection des commandes bash

Le guard verifie aussi les redirections dans les commandes bash (`>` et `>>` vers des fichiers proteges).

---

## Stop -- agent-suggest.sh

**Trigger** : quand Claude Code s'apprete a s'arreter (fin de reponse).

**Matcher** : `*` (toutes les sessions).

**Script** : `hooks/agent-suggest.sh`

**Comportement** :

1. Verifie si un agent est deja actif (fichier `.poc-session-agent`). Si oui, ne fait rien.
2. Decouvre les agents disponibles dans `agents/*/agent.md`.
3. Extrait la description de chaque agent depuis le frontmatter YAML.
4. Injecte un message demandant a Claude de proposer le routage :

```
[AGENT ROUTING] No agent was activated for this session.

Available agents:
- kiss-orchestrator: Central planner...
- kiss-executor: Implementation agent...
- kiss-verificator: Review-only agent...
- kiss-improver: Improvement loop agent...

Ask the user: "Would you like me to route your request to a specific agent?"
```

5. Si l'utilisateur choisit un agent, le nom est ecrit dans `.poc-session-agent`.

---

## SessionEnd -- session-end.sh

**Trigger** : a la fin de chaque session Claude Code.

**Matcher** : `*` (toutes les sessions).

**Script** : `hooks/session-end.sh`

**Comportement** :

1. Verifie que `KISS_CLAW_SESSION` est defini. Si non, nettoie le fichier agent et sort.
2. Ecrit un CHECKPOINT.md via `store.sh write checkpoint` avec :
   - Snapshot de STATE.md (phase, etape, statut, bloqueur)
   - Liste des etapes completees (10 dernieres)
   - Fichiers modifies (via `git diff --name-only HEAD` ou `find`)
   - Instruction de reprise
3. Si l'agent actif etait kiss-orchestrator : met a jour la date dans STATE.md et ajoute une entree au log.
4. Supprime le fichier `.poc-session-agent`.
5. Sort silencieusement (pas de sortie stdout).
