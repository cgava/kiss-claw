# Boucle d'amelioration

Comment utiliser kiss-improver pour analyser les sessions passees et ameliorer progressivement les agents.

## Invoquer kiss-improver

```
/kiss-improver
```

kiss-improver analyse automatiquement les nouveaux transcripts de session Claude non encore traites.

## Analyse automatique

A l'invocation, kiss-improver :

1. **Detecte les nouveaux transcripts** dans `~/.claude/projects/<slug>/` ou `.kiss-claw/claude-sessions/`
2. **Identifie l'agent** de chaque session (orchestrator, executor, verificator, improver, ou general)
3. **Charge la definition de l'agent** pour l'utiliser comme reference
4. **Extrait les tokens consommes** par session
5. **Detecte les signaux** : frictions, patterns positifs, lacunes de configuration, derives de scope
6. **Ecrit les propositions** dans INSIGHTS.md
7. **Met a jour ANALYZED.md** avec l'index des sessions traitees

A la fin, un resume s'affiche :

```
=== ANALYSIS COMPLETE ===
Sessions analyzed : 3 (kiss-orchestrator: 1, kiss-executor: 2)
New facts         : 4
New proposals     : 2  (agent-scoped: 1, config-scoped: 1)
Top proposal      : Ajouter "ORM: SQLAlchemy 2.x" a MEMORY_kiss-executor.md

Token consumption (new sessions):
  Total tokens   : 45200
  Avg tpt        : 380  (lower = more efficient)
  Budget status  : ok: 2 / warn: 1 / over: 0
  See token-stats resource for full history

Run /insights to review proposals
=========================
```

## Consulter les propositions

```
/kiss-improver /insights
```

Affiche les propositions groupees par cible :

```
-- agent:kiss-executor (2) --
[INS-0003] confidence: high
  Fact    : kiss-executor asked which ORM to use in 3 consecutive sessions
  Proposal: Add to MEMORY_kiss-executor.md -> "ORM: SQLAlchemy 2.x. Never swap this."
  > accept / reject / defer

-- CLAUDE.md (1) --
[INS-0005] confidence: medium  [general session]
  Fact    : Claude asked about Python version in 2 general sessions
  Proposal: Add to CLAUDE.md -> "Python: 3.12+. No exceptions."
  > accept / reject / defer
```

## Decider sur une proposition

### Accepter

```
accept #3
```

La proposition passe en statut `accepted`. kiss-improver propose de l'appliquer immediatement.

### Rejeter

```
reject #3 pas pertinent pour notre stack
```

La proposition passe en statut `rejected` avec la raison enregistree.

### Differer

```
defer #3
```

La proposition passe en statut `deferred` et n'apparait plus dans les futures listes `/insights` (sauf demande explicite).

## Appliquer une proposition

```
apply #3
```

kiss-improver :
1. Charge le contenu actuel de la ressource cible
2. Localise la section appropriee
3. Fait une modification minimale et chirurgicale
4. Montre le diff :

```diff
--- memory:kiss-executor (before)
+++ memory:kiss-executor (after)
@@ -8,2 +8,3 @@
 ## Stack constraints
+ORM: SQLAlchemy 2.x. Never swap this.
 Python 3.12+
```

5. Demande confirmation : "Apply? (yes / edit / cancel)"
6. Si confirme : ecrit la modification, passe le statut a `applied`, notifie l'orchestrateur

## Rapport de consommation tokens

```
/kiss-improver /tokens
```

Affiche un resume de la consommation de tokens par session et par agent :

```
=== TOKEN CONSUMPTION ===
Sessions tracked : 12
Total tokens     : 542000  (input: 380000 / output: 162000)
Avg / session    : 45166 tokens
Avg tpt          : 320  (tokens per turn -- lower = more efficient)

By agent:
  kiss-executor     : avg 52000 tok/session, avg 380 tpt  [6 sessions]
  kiss-orchestrator : avg 38000 tok/session, avg 280 tpt  [4 sessions]
  kiss-verificator  : avg 25000 tok/session, avg 200 tpt  [2 sessions]

Budget violations: 1 over / 2 warn
Most expensive session: 2026-04-10 kiss-executor -- 78000 tokens (many corrections)
=========================
```
