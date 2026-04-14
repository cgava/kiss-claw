# Initialiser un projet

Comment configurer kiss-claw dans un nouveau projet.

## Initialisation standard

Depuis la racine de votre projet :

```bash
./scripts/init.sh
```

En mode interactif (terminal), le script propose des choix pour chaque sous-repertoire :

### Repertoire agents

```
Chemin du dossier de persistance des agents (prompts additionnels) :
  1 - Symlink vers .kiss-claw/agents (defaut)
  2 - .kiss-claw/agents (local)
  3 - Autre chemin
  4 - Symlink vers un dossier existant
Choix [1] :
```

Le choix 1 (symlink) permet de partager les memoires agents entre plusieurs projets.

### Repertoire project

```
Chemin de persistance des donnees projects :
  1 - .kiss-claw/project (defaut)
  2 - Autre chemin
  3 - Symlink vers un dossier existant
Choix [1] :
```

### Repertoire sessions

```
Chemin de persistance des donnees de sessions :
  1 - .kiss-claw/sessions (defaut)
  2 - Autre chemin
  3 - Symlink vers un dossier existant
Choix [1] :
```

## Initialisation non-interactive

Quand stdin n'est pas un terminal (CI, scripts), tous les chemins par defaut sont utilises automatiquement :

```bash
echo "" | ./scripts/init.sh
```

## Verifier l'etat

```bash
./scripts/init.sh --status
```

Affiche :

```
kiss-claw project status
========================
Root dir : .kiss-claw

Sub-directories:
  agents: .kiss-claw/agents
  project: .kiss-claw/project
  sessions: .kiss-claw/sessions

Project resources:
  ok MEMORY.md
  ok SESSIONS.json

Agent resources:
  ok MEMORY_kiss-orchestrator.md
  ok MEMORY_kiss-executor.md
  ok MEMORY_kiss-verificator.md
  ok MEMORY_kiss-improver.md

Session resources:
  Session: 20260414-153022
    . PLAN.md
    . STATE.md
```

## Migration v7 vers v8

Si vous avez un ancien layout (fichiers plats dans `.kiss-claw/`) :

```bash
./scripts/init.sh --migrate
```

La migration :
1. Cree les sous-repertoires `agents/`, `project/`, `sessions/`
2. Deplace les fichiers agents (`MEMORY_kiss-*.md`, `INSIGHTS.md`, `ANALYZED.md`) vers `agents/`
3. Deplace les fichiers projet (`MEMORY.md`, `ISSUES.md`) vers `project/`
4. Cree un repertoire de session a partir des fichiers session (`PLAN.md`, `STATE.md`, etc.)
5. Initialise `SESSIONS.json` si absent
6. Supprime `TOKEN_STATS.md` (desactive)
7. Ecrit `VERSION = 8`

## Structure creee

```
.kiss-claw/
  VERSION                       -- Version du layout (8)
  agents/                       -- Memoires agents
    MEMORY_kiss-orchestrator.md
    MEMORY_kiss-executor.md
    MEMORY_kiss-verificator.md
    MEMORY_kiss-improver.md
  project/                      -- Donnees projet
    MEMORY.md
    SESSIONS.json
  sessions/                     -- Sessions de travail
    20260414-153022/
      PLAN.md
      STATE.md
      REVIEWS.md
      SCRATCH.md
      CHECKPOINT.yaml
```

## Symlinks pour repertoires partages

Utilisez des symlinks pour partager les memoires agents entre projets :

```bash
# Lors de l'initialisation, choisir l'option 4 (symlink)
# Ou creer manuellement :
ln -s /chemin/partage/agents .kiss-claw/agents
```

Les variables d'environnement `KISS_CLAW_AGENTS_DIR`, `KISS_CLAW_PROJECT_DIR` et `KISS_CLAW_SESSIONS_DIR` permettent aussi de rediriger les chemins sans symlink.

## .gitignore

Le script ajoute automatiquement `.kiss-claw` au `.gitignore` du projet. Les donnees de session sont locales et ne doivent pas etre commitees.
