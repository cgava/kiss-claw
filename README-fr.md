# kiss-claw

Plugin Claude Code multi-agent avec état persistant, boucle d'amélioration continue,
checkpointing, dry-run, protection des fichiers critiques, et support multi-session.
Zéro dépendance externe.

Keep It Simple, Stupid ! The simplest yet ambitious Claude AI harness for code. Stupidly efficient.

---

## Nouveautés v7

| Feature | Détail |
|---------|--------|
| Persistance multi-session | Chaque session a son propre dossier sous `.kiss-claw/sessions/` |
| Structure 3 dossiers | État réparti en `agents/`, `project/`, et `sessions/` |
| Gestion des sessions | Variable `KISS_CLAW_SESSION`, `list sessions`, support `resume` |
| Chemins configurables | Chaque sous-dossier surchargeable via variable d'environnement dédiée |

<details>
<summary>Nouveautés v6</summary>

| Feature | Détail |
|---------|--------|
| Persistance `/kiss-store` | Tous les agents utilisent `scripts/store.sh` pour les lectures/écritures |
| Backup on write | Chaque écriture crée un backup automatique |
| I/O centralisé | Point d'entrée unique pour toutes les opérations de persistance |

</details>

<details>
<summary>Nouveautés v5</summary>

| Feature | Détail |
|---------|--------|
| `PreToolUse` guard | Bloque toute écriture non autorisée sur les fichiers critiques |
| Checkpointing | `/compact` écrit `CHECKPOINT.md` avant perte de contexte |
| Dry-run mode | `dry-run on/off` — kiss-executor décrit sans écrire |
| Token budget | Limite par step, alerte si dépassement |

</details>

---

## Architecture

```
SessionStart hook
  └─ affiche menu → attend mot clé → tag session (.poc-session-agent)

kiss-orchestrator   planifie, STATE.md, délègue, gère dry-run + budget
kiss-executor       implémente (respects dry-run, s'arrête si budget warn)
kiss-verificator    review outputs kiss-executor → REVIEWS.md
kiss-improver       analyse transcripts → INSIGHTS.md

/kiss-store          couche de persistance centralisée (scripts/store.sh)
PreToolUse hook      bloque écritures sur fichiers protégés
SessionEnd hook      écrit CHECKPOINT.md + update STATE.md log
```

---

## Installation

### Depuis la marketplace

```bash
# Ajouter la marketplace (une fois)
/plugin marketplace add cgava/kiss-claw

# Installer
claude plugin install kiss-claw@kiss-claw
```

### Init d'un projet

```bash
cd mon-projet
~/.claude/plugins/kiss-claw/scripts/init.sh
# Éditer .kiss-claw/MEMORY.md avec les infos du projet
```

### Mode dev

```bash
# Charger le plugin directement depuis votre clone local
claude --plugin-dir /chemin/vers/kiss-claw

# Recharger après modifs sans redémarrer
/reload-plugins
```

### Dossier de sortie personnalisé

Par défaut, les fichiers d'état vivent dans `.kiss-claw/` à la racine du projet.
Surcharger via `.claude/settings.local.json` :

```json
{
  "envVars": {
    "KISS_CLAW_DIR": "mon/chemin/custom",
    "KISS_CLAW_AGENTS_DIR": "mon/chemin/custom/agents",
    "KISS_CLAW_PROJECT_DIR": "mon/chemin/custom/project",
    "KISS_CLAW_SESSIONS_DIR": "mon/chemin/custom/sessions"
  }
}
```

Chaque sous-dossier peut être surchargé indépendamment -- utile pour créer des
symlinks vers un emplacement partagé entre repos.

### Désinstallation

```bash
claude plugin uninstall kiss-claw@kiss-claw
```

---

## Fichiers projet

```
ton-projet/
└── .kiss-claw/                          ← dossier racine (configurable via KISS_CLAW_DIR)
    ├── agents/                          ← mémoires agents (configurable via KISS_CLAW_AGENTS_DIR)
    │   ├── MEMORY_kiss-orchestrator.md  ┐
    │   ├── MEMORY_kiss-executor.md      ├─ mémoire privée par agent
    │   ├── MEMORY_kiss-verificator.md   │
    │   ├── MEMORY_kiss-improver.md      ┘
    │   ├── INSIGHTS.md                  ← proposals d'amélioration (kiss-improver)
    │   └── ANALYZED.md                  ← index sessions (kiss-improver)
    ├── project/                         ← données projet (configurable via KISS_CLAW_PROJECT_DIR)
    │   ├── MEMORY.md                    ← contexte partagé
    │   ├── ISSUES.md                    ← suivi des issues projet
    │   └── SESSIONS.json                ← registre des sessions
    └── sessions/                        ← données session (configurable via KISS_CLAW_SESSIONS_DIR)
        └── 20260413-153022/             ← session individuelle (YYYYMMDD-HHmmss)
            ├── PLAN.md                  ← plan de session (kiss-orchestrator)
            ├── STATE.md                 ← état courant + mode (kiss-orchestrator)
            ├── REVIEWS.md               ← rapports review (kiss-verificator)
            ├── SCRATCH.md               ← notes volatiles
            └── CHECKPOINT.md            ← snapshot pré-compact (hooks auto)
```

### Variables d'environnement

| Variable | Défaut | Description |
|----------|--------|-------------|
| `KISS_CLAW_DIR` | `.kiss-claw` | Dossier racine |
| `KISS_CLAW_AGENTS_DIR` | `$KISS_CLAW_DIR/agents` | Mémoires et insights agents |
| `KISS_CLAW_PROJECT_DIR` | `$KISS_CLAW_DIR/project` | Données partagées du projet |
| `KISS_CLAW_SESSIONS_DIR` | `$KISS_CLAW_DIR/sessions` | Dossiers de sessions |
| `KISS_CLAW_SESSION` | _(auto-créé)_ | ID de session active (YYYYMMDD-HHmmss) |

---

## Fichiers protégés (guard PreToolUse)

Ces fichiers ne peuvent être écrits que par leur agent propriétaire.
Toute tentative d'un autre agent est bloquée avant exécution :

| Fichier | Scope | Propriétaire |
|---------|-------|-------------|
| `sessions/<id>/PLAN.md` | session | kiss-orchestrator |
| `sessions/<id>/STATE.md` | session | kiss-orchestrator |
| `sessions/<id>/REVIEWS.md` | session | kiss-verificator |
| `sessions/<id>/CHECKPOINT.md` | session | hook SessionEnd |
| `project/MEMORY.md` | projet | kiss-improver (via apply) |
| `agents/ANALYZED.md` | agent | kiss-improver |
| `agents/INSIGHTS.md` | agent | kiss-improver |

---

## Commandes

| Commande | Agent | Effet |
|----------|-------|-------|
| `mark done` | kiss-orchestrator | Valide l'étape courante |
| `dry-run on/off` | kiss-orchestrator | Bascule le mode kiss-executor |
| `/compact` | kiss-orchestrator | Écrit CHECKPOINT.md avant compact |
| `/kiss-store` | tous les agents | Opérations de persistance (read/write/list/backup) |
| `/analyze` | kiss-improver | Analyse nouveaux transcripts |
| `/insights` | kiss-improver | Review et apply des proposals |

---

## Support multi-session

Chaque session kiss-claw crée son propre dossier sous `.kiss-claw/sessions/` avec un
identifiant horodaté (YYYYMMDD-HHmmss). L'état spécifique à la session (plan, progression,
reviews) est isolé, tandis que les mémoires agents et les données projet persistent entre sessions.

- **Nouvelle session** : créée automatiquement à l'init, ou via `KISS_CLAW_SESSION` explicite.
- **Lister les sessions** : `/kiss-store list sessions` affiche toutes les sessions disponibles.
- **Reprendre une session** : `KISS_CLAW_SESSION=<id>` pour reprendre une session précédente.



---

## Historique des évolutions

Cette section retrace les motivations des évolutions majeures du projet, reconstituées
à partir des fichiers CHECKPOINT et du git log. Elle vise à préserver le *pourquoi*
derrière chaque chantier — information qui se dilue rapidement dans l'implémentation
et dans les diffs. Treize ères chronologiques jalonnent le parcours depuis le bootstrap
initial jusqu'aux travaux d'isolation Docker en cours.

### Ère 1 — Bootstrap vibe-codé (2026-04-09)

Architecture multi-agent itérative : v3 (premier jet), v5 (solidification avec PreToolUse guard, checkpointing, dry-run, token budget — cf. section v5 ci-dessus), puis v5.1 (simplification du déploiement en plugin Claude natif). Les premiers hooks échouaient silencieusement, ce qui a imposé des protections explicites sur les fichiers critiques. La stratégie : itérer vite, observer ce qui casse, consolider.

### Ère 2 — Renommage kiss-* (2026-04-09)

Tous les agents sont préfixés `kiss-` (kiss-orchestrator, kiss-executor, kiss-verificator, kiss-improver). Le but est un namespace clair permettant de cohabiter avec d'autres plugins et agents Claude Code sans collision.

### Ère 3 — /kiss-store, couche de persistance (v6, 2026-04-10)

Centralisation de toutes les I/O via `scripts/store.sh` (cf. section v6 ci-dessus). Avant cette refonte, les hooks étaient cassés (ISSUE-005) et les agents écrivaient directement sur les fichiers d'état, avec des risques d'incohérence. Un point de vérité unique pour lire, écrire, lister et sauvegarder l'état s'imposait.

### Ère 4 — Framework de tests Python + Docker (2026-04-10/11)

Mise en place d'un test runner en Python stdlib uniquement, de scénarios `test_*.py` découverts récursivement, et d'une infrastructure Docker pour l'isolation. L'objectif est de valider le comportement end-to-end des agents sans dépendances pip, dans un environnement reproductible où le coût LLM et les effets de bord sont contrôlés.

### Ère 5 — my-claude-minion extrait en vendor submodule (2026-04-11)

Le wrapper CLI Claude sort de kiss-claw et devient un submodule réutilisable (`vendor/my-claude-minion/`). Cette séparation clarifie les responsabilités : kiss-claw pilote les agents, my-claude-minion gère l'interaction avec la CLI. Bénéfice secondaire : la réutilisabilité entre projets.

### Ère 6 — Multi-session v7 (2026-04-13)

Refonte de `.kiss-claw/` en trois tiers (`agents/`, `project/`, `sessions/`), avec variables d'environnement dédiées et support des symlinks (cf. section v7 ci-dessus). Motivation verbatim (CHECKPOINT 20260413-220308) : « En mode dev, kiss-claw partage un seul répertoire .kiss-claw/ entre le projet hôte et le plugin. La structure plate crée des conflits et empêche le multi-session. »

### Ère 7 — CHECKPOINT.yaml structuré (2026-04-14)

Le `CHECKPOINT.md` plat devient un `CHECKPOINT.yaml` hiérarchique (phase, steps, claude_session). Motivation verbatim (CHECKPOINT 20260414-082706) : « Dette technique — les hooks sont cassés, le CHECKPOINT.md existant est un format plat sans traçabilité. Impossible de relier les étapes du plan aux sessions Claude réelles. Le journal projet ne conserve aucun résumé de ce qui a été fait. »

### Ère 8 — Documentation Diátaxis + /kiss-help (2026-04-14)

Documentation française complète organisée selon les quatre axes Diátaxis (tutoriels, how-to, référence, explication), accompagnée d'un skill `/kiss-help` pour la parcourir. Motivation verbatim (CHECKPOINT 20260414-143500) : « Dette documentaire — le projet kiss-claw a évolué rapidement (checkpoint, sync-sessions, store.sh enrichi, multi-session) mais la documentation n'a pas suivi. Les process ne sont pas évidents pour les utilisateurs ni pour les agents. »

### Ère 9 — Détection runtime du claude_session ID (2026-04-14)

Les agents détectent leur propre identifiant de session Claude à l'exécution, remplaçant les placeholders statiques. Motivation verbatim (CHECKPOINT 20260414-170500) : « Les CHECKPOINT.yaml actuels sont inutilisables pour la rétroaction : pas de vrais IDs de session Claude, pas de hiérarchie phase/steps, entrées manquantes. Impossible de retrouver quel transcript Claude correspond à quelle étape du plan. »

### Ère 10 — /kiss-enrich-checkpoint (2026-04-14/15)

Un skill qui enrichit automatiquement les fichiers `CHECKPOINT.yaml` depuis les transcripts Claude (extraction des artifacts, décisions, issues et rationale). Motivation verbatim (CHECKPOINT 20260414-213000) : « Les CHECKPOINT.yaml actuels sont trop compactes (task monoligne + result résumé) pour permettre des retex rétrospectifs ou du transfert de contexte inter-agents. On perd toute la richesse des échanges. Objectif : mémoire projet auto-suffisante sans dépendance aux sessions Claude brutes (éphémères). »

### Ère 11 — Élicitation du « pourquoi » dans INIT (2026-04-14)

L'orchestrator questionne la raison profonde avant de générer le plan, et catégorise la demande (bug, feature, refactoring, dette). L'enjeu est de capturer le pourquoi *avant* qu'il ne se dilue dans l'implémentation. La présente session de bilan en est la démonstration directe : sans cette élicitation amont, reconstruire a posteriori impose de fouiller les transcripts et les commits.

### Ère 12 — Test runner interactif (2026-04-15/17)

`scenario_runner.py` introduit le chaînage `--resume` pour les scénarios multi-turn, avec assertions structurelles + regex et debug output par défaut. Motivation verbatim (CHECKPOINT 20260415-113650) : « Bug structurel : les scenarios de test (02-konvert-agents) ne fonctionnent pas en vrai. L'orchestrateur pose 3 questions INIT interactives mais claude -p est non-interactif. Les tests ne valident rien aujourd'hui, ils ne tournent qu'en --dry-run. »

### Ère 13 — Tests isolation Docker (2026-04-17, en cours)

Renforcement de l'infrastructure Docker pour des tests complètement isolés du poste de développement (session 20260417-230316, statut `in_progress`). Le CHECKPOINT n'étant pas encore rédigé, la motivation est inférée : reproductibilité bit-à-bit, isolation des effets de bord, et maîtrise du coût de test pour une future intégration continue.