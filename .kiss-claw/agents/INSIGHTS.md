### INS-0001

- **session**   : 223bd4e1-8696-40b7-8208-6ff23b42dbf5
- **session-agent** : kiss-orchestrator
- **date**      : 2026-04-10
- **target**    : agent:kiss-orchestrator
- **type**      : proposal
- **confidence**: high
- **status**    : applied
- **applied_at**: 2026-04-10

**Fact**
Human requested a WIP commit before applying kiss-verificator feedback, but kiss-orchestrator proceeded to apply feedback first, merging everything into one commit. The human corrected this twice, stating the workflow should produce two commits per plan/execute/verify cycle: one before verificator rework, one after.

**Proposal**
Add commit protocol to kiss-orchestrator. Already applied by the agent in `.kiss-claw/MEMORY_kiss-orchestrator.md`.

**Rejection reason**

### INS-0002

- **session**   : 223bd4e1-8696-40b7-8208-6ff23b42dbf5
- **session-agent** : kiss-orchestrator
- **date**      : 2026-04-10
- **target**    : memory:kiss-orchestrator
- **type**      : proposal
- **confidence**: low
- **status**    : deferred

**Fact**
kiss-orchestrator edited `.kiss-claw/STATE.md` directly via the Edit tool instead of using `/kiss-store update state`. However, this session predates the creation of `/kiss-store` — the store skill was being built during this session, so direct edits were the only option at the time.

**Proposal**
Re-check in future kiss-improver runs: verify that post-store sessions use `/kiss-store` exclusively. If direct edits still occur after store availability, escalate to a blocking constraint in `memory:kiss-orchestrator`.

**Rejection reason**
Deferred — not a real violation since /kiss-store did not exist yet during this session.

### INS-0003

- **session**   : 223bd4e1-8696-40b7-8208-6ff23b42dbf5
- **session-agent** : kiss-orchestrator
- **date**      : 2026-04-10
- **target**    : agent:kiss-orchestrator
- **type**      : fact
- **confidence**: low
- **status**    : rejected

**Fact**
Parallel agent delegation (launching kiss-executor and kiss-verificator concurrently on independent steps) worked well. The human confirmed this pattern without pushback. Orchestrator successfully ran verify+execute in parallel for steps 1.1/1.2, then sequential verify-fix-re-verify cycles when needed.

**Proposal**
Document parallel delegation as a validated pattern.

**Rejection reason**
Incorrect analysis. kiss-verificator cannot run before kiss-executor finishes — it reviews executor output. The observed parallelism was on different steps (verify completed step N while executing step N+1), which is sequential dependency, not true parallel independence. This pattern should not be documented as "parallel delegation" as it misrepresents the dependency chain.
### INS-0004

- **session**   : 8a38db90-e9ae-47b8-8fb4-64b935eb5bc8
- **session-agent** : kiss-orchestrator
- **date**      : 2026-04-10
- **target**    : memory
- **type**      : fact
- **confidence**: high
- **status**    : proposed

**Fact**
Session invoked kiss-orchestrator to plan Issue 2 (functional tests). User provided detailed requirements for a Docker-based test framework with scenario evaluation and prompt tracing. No friction signals detected — clean delegation pattern with kiss-executor/verificator.

**Proposal**
In `memory` section "Project > Issue tracking", add: "ISSUE-002: Functional test framework (GitHub CI/CD, not GitLab). Tests run in Docker with isolated projects/.claude cache for state inspection."

**Rejection reason**

### INS-0005

- **session**   : 8a38db90-e9ae-47b8-8fb4-64b935eb5bc8
- **session-agent** : kiss-orchestrator
- **date**      : 2026-04-10
- **target**    : memory:kiss-orchestrator
- **type**      : proposal
- **confidence**: medium
- **status**    : proposed

**Fact**
During Issue 2 planning, Docker orchestration and test container patterns were extensively discussed (36 mentions), including isolation patterns from /backup-strategy/tools. However, no explicit Docker strategy is documented in MEMORY — creating knowledge gap risk on future test infra decisions.

**Proposal**
Add to `memory:kiss-orchestrator` section "Docker test strategy": "For functional testing: stateless containers with shared ~/.claude/projects cache for transcript analysis. Dockerfile derives from orchestrator template in backup-strategy project. Rebuild container per test cycle to ensure clean state."

**Rejection reason**

### INS-0006

- **session**   : 8a38db90
- **session-agent** : kiss-orchestrator
- **date**      : 2026-04-10
- **target**    : memory
- **type**      : fact
- **confidence**: high
- **status**    : applied

**Fact**
Toute la session 8a38db90 (kiss-orchestrator, Issue 2) a tourné sur `claude-haiku-4-5-20251001` au lieu d'Opus. Les 7 sous-agents aussi. Haiku n'a pas la capacité de raisonnement suffisante pour suivre les protocoles multi-étapes complexes des agents kiss-claw, ce qui est la cause racine de la majorité des violations observées dans cette session.

**Proposal**
Ajouter à MEMORY.md section "## Contraintes modèle" :
```
## Contraintes modèle
- kiss-orchestrator et kiss-executor DOIVENT tourner sur Opus (ou Sonnet au minimum). Haiku est interdit pour ces agents — capacité de raisonnement insuffisante pour suivre les protocoles.
- Vérifier le modèle en début de session : si Haiku détecté, alerter immédiatement l'utilisateur.
```

**Rejection reason**

applied_at: 2026-04-10


### INS-0007

- **session**   : 8a38db90
- **session-agent** : kiss-orchestrator
- **date**      : 2026-04-10
- **target**    : agent:kiss-orchestrator
- **type**      : proposal
- **confidence**: high
- **status**    : proposed

**Fact**
L'orchestrateur a commencé à travailler (recherche, TaskCreate x6, exploration de projets externes) sans avoir créé PLAN.md ni mis à jour STATE.md. L'utilisateur a dû interrompre (Turn 55 : "est-ce que tu as bien crée un fichier PLAN.md ???"). La startup protocol existe mais n'a pas été suivie.

**Proposal**
Renforcer la startup protocol dans `agents/kiss-orchestrator/agent.md` en ajoutant un bloc de garde explicite après l'étape 2 :
```
2b. HARD GATE: Do NOT proceed to any planning, research, or task creation until PLAN.md
    and STATE.md are confirmed to exist (via /kiss-store exists plan && /kiss-store exists state).
    If they don't exist, create them FIRST via the INIT protocol. No exceptions.
```

**Rejection reason**


### INS-0008

- **session**   : 8a38db90
- **session-agent** : kiss-orchestrator
- **date**      : 2026-04-10
- **target**    : agent:kiss-orchestrator
- **type**      : proposal
- **confidence**: high
- **status**    : proposed

**Fact**
L'orchestrateur a utilisé `Write` et `Edit` directement sur `.kiss-claw/PLAN.md` et `.kiss-claw/STATE.md` (Turns 66-74) au lieu de `/kiss-store`. Plus tard, il a fait `rm -f .kiss-claw/PLAN.md .kiss-claw/STATE.md` (Turn 119) — opération destructive. L'agent a reconnu la violation (Turn 92) mais le mal était fait.

**Proposal**
Ajouter un avertissement explicite en tête de la section "Resources you own" dans `agents/kiss-orchestrator/agent.md` :
```
⚠️ NEVER use Read/Write/Edit tools directly on .kiss-claw/*.md files.
   NEVER use rm/Bash to delete .kiss-claw/*.md files.
   ALL access goes through /kiss-store. This rule has zero exceptions.
```

**Rejection reason**


### INS-0009

- **session**   : 8a38db90
- **session-agent** : kiss-orchestrator
- **date**      : 2026-04-10
- **target**    : agent:kiss-orchestrator
- **type**      : proposal
- **confidence**: high
- **status**    : proposed

**Fact**
L'orchestrateur a délégué aux sous-agents via `Agent(subagent_type: "general-purpose", name: "kiss-executor")`. Ceci lance un agent générique qui ne charge PAS la définition `agents/kiss-executor/agent.md`. Le nom "kiss-executor" n'est qu'un label — l'agent ne connaît pas ses contraintes, son protocole, ni ses fichiers autorisés. Les 7 sous-agents tournaient tous comme des agents génériques sans instructions kiss-claw.

**Proposal**
Ajouter à `agents/kiss-orchestrator/agent.md` section "Delegation rules" :
```
## How to delegate correctly

To invoke kiss-executor or kiss-verificator, use the Skill tool:
  Skill(skill: "kiss-claw:kiss-executor", args: "<task description>")
  Skill(skill: "kiss-claw:kiss-verificator", args: "<review request>")

NEVER use Agent(subagent_type: "general-purpose", name: "kiss-executor") — this creates
a generic agent that does NOT load the agent.md definition. The name is just a label.
```

**Rejection reason**


### INS-0010

- **session**   : 8a38db90
- **session-agent** : kiss-orchestrator
- **date**      : 2026-04-10
- **target**    : agent:kiss-orchestrator
- **type**      : fact
- **confidence**: high
- **status**    : proposed

**Fact**
Après avoir invoqué kiss-executor via Skill (Turn 204), l'orchestrateur a continué dans le même contexte comme s'il ÉTAIT kiss-executor (Turn 220 : "kiss-executor ready — last task: 4.1"). Il n'y a pas eu de séparation de contexte. L'utilisateur a signalé la confusion (Turn 291) : "maintenant on se perd entre executor/orchestrator/validator". Ce problème de rôle-confusion est structurel : invoquer un Skill dans le même contexte ne crée pas un agent séparé.

**Proposal**
Documenter dans `agents/kiss-orchestrator/agent.md` la distinction Skill vs Agent :
```
## Delegation: Skill vs Agent

- Skill(skill: "kiss-claw:kiss-executor") runs IN YOUR CONTEXT — you become the executor.
  Use this ONLY if you understand you will follow executor protocol until task complete,
  then explicitly return to orchestrator role.
  
- For true isolation, use Agent(subagent_type: "kiss-claw:kiss-executor:kiss-executor").
  This spawns a separate context that loads the agent.md independently.

Preferred: Agent for implementation. Skill only for lightweight operations.
```

**Rejection reason**


### INS-0011

- **session**   : 8a38db90
- **session-agent** : kiss-orchestrator
- **date**      : 2026-04-10
- **target**    : memory:kiss-orchestrator
- **type**      : proposal
- **confidence**: medium
- **status**    : proposed

**Fact**
L'orchestrateur a essayé `store.sh write research` (Turn 101) qui a échoué — "research" n'est pas une ressource valide. Il a dû lire le code source de store.sh pour trouver les ressources disponibles. Le `scratch` resource a finalement été utilisé comme fallback.

**Proposal**
Ajouter à `memory:kiss-orchestrator` :
```
## Valid /kiss-store resources
plan, state, scratch, memory, memory:<agent>, reviews, insights, analyzed, token-stats, checkpoint
Pour stocker des notes temporaires (recherche, brouillons) : utiliser `scratch`.
```

**Rejection reason**


### INS-0012

- **session**   : 8a38db90
- **session-agent** : kiss-orchestrator
- **date**      : 2026-04-10
- **target**    : memory:kiss-orchestrator
- **type**      : fact
- **confidence**: medium
- **status**    : proposed

**Fact**
L'orchestrateur a créé un `.gitlab-ci.yml` (Turn 283) alors que le dépôt est hébergé sur GitHub (repo: https://github.com/ccgava/kiss-claw, visible dans MEMORY.md). L'utilisateur a dû demander la suppression (Turn 294). Cette erreur de contexte aurait été évitée en lisant MEMORY.md en début de session.

**Proposal**
Ajouter à `memory:kiss-orchestrator` :
```
## CI/CD
- Le dépôt est sur GitHub (pas GitLab). Utiliser GitHub Actions, pas .gitlab-ci.yml.
```

**Rejection reason**


### INS-0013

- **session**   : 8a38db90
- **session-agent** : kiss-orchestrator
- **date**      : 2026-04-10
- **target**    : agent:kiss-orchestrator
- **type**      : proposal
- **confidence**: medium
- **status**    : proposed

**Fact**
L'orchestrateur a créé 6 TaskCreate (Turns 38-49) avant même d'avoir établi le PLAN.md. Ces tâches étaient des doublons du plan et ont dû être toutes supprimées. L'utilisateur a dit : "elles sont un reliquat de l'anomalie initiale de process".

**Proposal**
Ajouter à la startup protocol dans `agents/kiss-orchestrator/agent.md` :
```
NOTE: Do NOT use TaskCreate before PLAN.md is written and validated.
The plan IS the task list. TaskCreate is only used for sub-step tracking
within an already-established phase, never as a substitute for planning.
```

**Rejection reason**


### INS-0014

- **session**   : 8a38db90
- **session-agent** : kiss-orchestrator
- **date**      : 2026-04-10
- **target**    : memory:kiss-orchestrator
- **type**      : fact
- **confidence**: low
- **status**    : proposed

**Fact**
L'orchestrateur a passé ~6 turns (15, 25-35) à explorer des fichiers dans `/home/omc/workspace/backup-strategy/` (Dockerfile, orchestrate.sh) pour "inspiration". Bien que la référence soit pertinente (Docker test pattern), cela a consommé du contexte sans contribution directe au plan final.

**Proposal**
Ajouter à `memory:kiss-orchestrator` :
```
## Projets connexes
- backup-strategy contient un pattern Docker/orchestrate.sh utilisable comme référence pour les tests fonctionnels. Mais ne pas explorer ces fichiers systématiquement — les consulter seulement si le pattern est explicitement requis.
```

**Rejection reason**


### INS-0015

- **session**   : test-konvert-run-1 (0a874eff)
- **session-agent** : test-framework
- **date**      : 2026-04-11
- **target**    : agent:kiss-orchestrator
- **type**      : fact
- **confidence**: high
- **status**    : proposed

**Fact**
Lors du test d'intégration konvert (run 1), l'orchestrator n'a pas été invoqué du tout. Claude a directement planifié et exécuté sans passer par /kiss-claw:kiss-orchestrator. Les fichiers PLAN.md, REVIEW.md et IMPROVEMENTS.md ont été créés à la racine du workspace (pas dans .kiss-claw/). init.sh n'a pas tourné.

**Proposal**
Le prompt d'invocation doit être plus explicite pour forcer le routing vers kiss-orchestrator. Investiguer si `--system-prompt` avec une instruction de routing obligatoire serait plus fiable que l'instruction dans le prompt utilisateur.

**Rejection reason**


### INS-0016

- **session**   : test-konvert-run-3 (881cdfc1)
- **session-agent** : test-framework
- **date**      : 2026-04-11
- **target**    : agent:kiss-executor
- **type**      : fact
- **confidence**: high
- **status**    : proposed

**Fact**
L'erreur `Agent type 'kiss-claw:kiss-executor' not found` a été enregistrée dans last-tool-error.json. L'agent a utilisé le nom court `kiss-claw:kiss-executor` au lieu du FQDN `kiss-claw:kiss-executor:kiss-executor`. Après retry avec le bon nom, un seul executor a tourné mais n'a complété que la Phase 1 (planification). max_turns=50 insuffisant pour un loop complet.

**Proposal**
1. Documenter le format FQDN obligatoire (plugin:group:agent) dans tous les agent.md
2. Augmenter max_turns à 100+ pour les tests d'intégration multi-agents
3. Ajouter un alias/fallback dans le routing pour que les noms courts fonctionnent

**Rejection reason**


### INS-0017

- **session**   : test-konvert-runs 1-3
- **session-agent** : test-framework
- **date**      : 2026-04-11
- **target**    : system
- **type**      : fact
- **confidence**: high
- **status**    : proposed

**Fact**
Le comportement du loop d'agents est non-déterministe entre les runs :
- Run 1 (PASS, 427s) : 2x executor + 1x verificator, fichiers à la racine, pas d'init.sh
- Run 2 (FAIL, 280s) : fichiers à la racine, PLAN.md absent de .kiss-claw/
- Run 3 (FAIL, 144s) : init.sh invoqué (fichiers dans .kiss-claw/), 1x executor seulement, exit code 1
Les noms de fichiers varient aussi : REVIEW.md vs REVIEWS.md, IMPROVEMENTS.md vs INSIGHTS.md.

**Proposal**
1. Le test doit accepter les variations de noms/emplacements (tolérance aux chemins alternatifs)
2. Les agents doivent être plus stricts sur les noms de fichiers — utiliser les noms définis dans init.sh/store.sh
3. Investiguer pourquoi init.sh est invoqué dans certains runs et pas d'autres

**Rejection reason**
### INS-0018

- **session**   : 589d5e8e-a6db-44e5-bef1-c91d1c370851
- **session-agent** : kiss-orchestrator
- **date**      : 2026-04-14
- **target**    : agent:kiss-orchestrator
- **type**      : fact
- **confidence**: high
- **status**    : applied
- **applied_at**: 2026-04-14

**Fact**
kiss-orchestrator a créé PLAN.md et STATE.md dans `.kiss/` (un dossier inventé) au lieu de `.kiss-claw/sessions/<id>/`. L'agent n'a jamais exécuté le startup protocol : pas de génération de session ID, pas d'appel à `store.sh`, pas de SESSIONS.json. Il a utilisé `mkdir -p .kiss` puis `Write` directement. C'est la 3ème session où l'agent écrit les fichiers au mauvais endroit (voir aussi INS-0015, INS-0017).

**Proposal**
Ce problème est récurrent malgré les instructions existantes dans agent.md. Renforcer la section startup protocol avec un bloc de garde **avant toute autre action** :

```
## CRITICAL FIRST ACTION (before anything else)

1. Generate session ID: YYYYMMDD-HHmmss
2. export KISS_CLAW_SESSION=<id>
3. bash scripts/store.sh write state (creates .kiss-claw/sessions/<id>/)
4. bash scripts/store.sh write plan

If you find yourself about to write PLAN.md or STATE.md via Write/Edit tool:
STOP. You are violating the protocol. Use store.sh.
If you find yourself creating a directory that is NOT .kiss-claw/sessions/<id>/:
STOP. You are violating the protocol.
```

De plus, ajouter un self-check en début d'agent.md :
```
SELF-CHECK: The ONLY valid paths for session files are:
  .kiss-claw/sessions/<session-id>/PLAN.md
  .kiss-claw/sessions/<session-id>/STATE.md
Any other path (.kiss/, .kiss-claw/PLAN.md, root PLAN.md) is WRONG.
```

**Rejection reason**


### INS-0019

- **session**   : 589d5e8e-a6db-44e5-bef1-c91d1c370851
- **session-agent** : kiss-orchestrator
- **date**      : 2026-04-14
- **target**    : agent:kiss-orchestrator
- **type**      : fact
- **confidence**: high
- **status**    : applied
- **applied_at**: 2026-04-14

**Fact**
L'agent n'a pas exécuté le protocole INIT (3 questions une par une). Il a directement exploré le projet via un sous-agent Explore, puis produit le PLAN.md sans poser de questions à l'utilisateur. L'agent.md dit : "Ask the human 3 questions one at a time: 1. What are you building? 2. Main phases or milestones? 3. Constraints or non-goals?" — aucune de ces questions n'a été posée.

**Proposal**
Rendre le protocole INIT non-contournable en ajoutant :
```
INIT is MANDATORY even if the user's initial message contains enough context.
The 3 questions serve as alignment checkpoints, not just information gathering.
If the user already provided answers, confirm them:
  "You said you're building X — correct, or should I adjust?"
```

**Rejection reason**


### INS-0020

- **session**   : 589d5e8e-a6db-44e5-bef1-c91d1c370851
- **session-agent** : kiss-orchestrator
- **date**      : 2026-04-14
- **target**    : agent:kiss-orchestrator
- **type**      : fact
- **confidence**: high
- **status**    : rejected

**Fact**
L'agent a créé le dossier `.kiss` — un nom qui n'existe dans aucune documentation kiss-claw. Ce n'est ni `.kiss-claw` (v7) ni `.kiss-claw/sessions/<id>` (v8). L'agent a inventé un chemin. Cela suggère que l'agent ne lit pas store.sh et ne connaît pas la structure de fichiers réelle.

**Proposal**
Ajouter un bloc de contrainte explicite dans agent.md avec les chemins hardcodés.

**Rejection reason**
Les chemins sont la responsabilité de store.sh (configurable via KISS_CLAW_DIR, etc.). Hardcoder les chemins dans agent.md violerait cette séparation. La bonne solution est d'ajouter un mode d'inspection à store.sh pour que l'agent puisse découvrir les chemins résolus. Voir INS-0021.


### INS-0021

- **session**   : 589d5e8e-a6db-44e5-bef1-c91d1c370851
- **session-agent** : kiss-orchestrator
- **date**      : 2026-04-14
- **target**    : agent:kiss-orchestrator
- **type**      : proposal
- **confidence**: high
- **status**    : applied
- **applied_at**: 2026-04-14

**Fact**
L'agent a créé `.kiss/` au lieu de `.kiss-claw/sessions/<id>/`. Il ne connaît pas les chemins résolus car il n'appelle jamais store.sh. Hardcoder les chemins dans agent.md n'est pas la solution — store.sh est configurable (KISS_CLAW_DIR, etc.). L'agent a besoin d'un moyen de **découvrir** les chemins résolus.

**Proposal**
1. Ajouter une action `inspect` à `scripts/store.sh` qui affiche la configuration résolue :
```bash
  inspect)
    echo "kiss_claw_dir: $KC_DIR"
    echo "agents_dir: $AGENTS_DIR"
    echo "project_dir: $PROJECT_DIR"
    echo "sessions_dir: $SESSIONS_DIR"
    echo "session: ${KISS_CLAW_SESSION:-<not set>}"
    if [[ -n "${KISS_CLAW_SESSION:-}" ]]; then
      echo "session_path: $SESSIONS_DIR/$KISS_CLAW_SESSION"
    fi
    # Show resolved paths for all resources
    echo "---"
    echo "Resources:"
    for r in plan state reviews scratch checkpoint memory insights analyzed sessions; do
      path=$(resolve "$r" 2>/dev/null) && echo "  $r: $path" || echo "  $r: (requires session)"
    done
    ;;
```

2. Modifier la startup protocol de kiss-orchestrator pour commencer par `bash scripts/store.sh inspect` afin de vérifier la configuration avant toute écriture.

**Rejection reason**

