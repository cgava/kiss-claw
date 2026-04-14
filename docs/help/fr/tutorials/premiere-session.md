# Premiere session kiss-claw

Ce tutorial vous guide a travers votre premiere session complete avec kiss-claw : de l'initialisation du projet jusqu'a la fermeture de session.

## Pre-requis

- Claude Code installe et authentifie (OAuth)
- Un projet existant dans lequel vous voulez utiliser kiss-claw
- kiss-claw installe comme plugin Claude Code

## Etape 1 -- Initialiser le projet

Depuis la racine de votre projet, lancez le script d'initialisation :

```bash
./scripts/init.sh
```

Le script vous pose des questions sur les chemins de stockage. Pour un premier essai, acceptez tous les choix par defaut en appuyant sur Entree.

Vous devriez voir :

```
Initializing kiss-claw in ./. kiss-claw ...
Creating directory structure...
  created .kiss-claw/agents
  created .kiss-claw/project
  created .kiss-claw/sessions
Copying templates...
  created MEMORY.md
  created MEMORY_kiss-orchestrator.md
  created MEMORY_kiss-executor.md
  created MEMORY_kiss-verificator.md
  created MEMORY_kiss-improver.md
  created SESSIONS.json
Done.
```

Verifiez l'etat :

```bash
./scripts/init.sh --status
```

## Etape 2 -- Lancer kiss-orchestrator

Ouvrez une session Claude Code dans votre projet et invoquez l'orchestrateur :

```
/kiss-orchestrator
```

L'orchestrateur commence par verifier la configuration :

```
bash scripts/store.sh inspect
```

Puis il genere un identifiant de session (format `YYYYMMDD-HHmmss`) et lance le protocole INIT.

## Etape 3 -- Repondre aux 3 questions INIT

L'orchestrateur vous pose 3 questions, une par une :

1. **"What are you building? (1 sentence)"**

   Decrivez en une phrase ce que vous voulez faire. Exemple :
   > "Ajouter une commande CLI pour exporter les donnees en CSV."

   Apres votre reponse, l'orchestrateur peut vous demander de preciser le "pourquoi" de cette demande. Repondez simplement ou confirmez une des hypotheses proposees.

2. **"Main phases or milestones? (bullet list ok)"**

   Listez les grandes etapes. Exemple :
   > - Parser les arguments CLI
   > - Lire les donnees depuis la base
   > - Formater en CSV
   > - Ecrire le fichier de sortie

3. **"Constraints or non-goals?"**

   Mentionnez ce qui est hors scope. Exemple :
   > Pas de support Excel. Pas de streaming pour les gros fichiers dans cette version.

## Etape 4 -- Voir le plan genere

L'orchestrateur genere deux fichiers :

- **PLAN.md** : le plan immutable avec les phases et etapes
- **STATE.md** : l'etat de progression en direct

Il affiche un resume de session :

```
=== SESSION RESUME ===
Agent    : kiss-orchestrator
Session  : 20260414-153022
Phase    : Phase 1
Last done:
Blocked  : none
Next     : <premiere etape>
Insights : none
=====================
```

Il vous demande : "Proceed, or override?"

Repondez "Proceed" pour continuer.

## Etape 5 -- Deleguer a kiss-executor

L'orchestrateur vous propose de deleguer la premiere tache a kiss-executor :

```
That's kiss-executor territory. Delegate? (yes / handle it yourself)
```

Repondez "yes". L'orchestrateur passe la main a kiss-executor avec le contexte de session.

kiss-executor lit la tache, implemente le code, puis produit un rapport :

```
=== TASK REPORT ===
Agent  : kiss-executor
Task   : Parser les arguments CLI
Done   :
  - src/cli.py cree (42 lignes)
  - Tests unitaires dans tests/test_cli.py
Caveats: none
==================
```

## Etape 6 -- Faire reviewer par kiss-verificator

kiss-executor vous propose : "Send to kiss-verificator for review? (yes / skip)"

Repondez "yes". kiss-verificator examine le code produit et ecrit un rapport dans REVIEWS.md :

```
### REV-0001

- **date**     : 2026-04-14
- **subject**  : kiss-executor task -- Parser les arguments CLI
- **verdict**  : approved

**Summary**
Le code est correct et suit les conventions du projet.

**Issues**
No issues found.

**For kiss-orchestrator**
Proceed to next step.
```

## Etape 7 -- Fermer la session

Une fois toutes les etapes completees, dites a l'orchestrateur :

```
close session
```

L'orchestrateur :
1. Lit le CHECKPOINT.yaml pour synthetiser ce qui a ete fait
2. Met a jour SESSIONS.json avec un resume complet
3. Passe le statut a "done"
4. Affiche la banniere de fermeture :

```
=== SESSION CLOSED ===
Session  : 20260414-153022
Title    : Export CSV CLI
Duration : 2026-04-14T15:30:22 -> 2026-04-14T16:45:00
Files    : 3 files changed
Next     : none
=====================
```

## Etape 8 -- Lister les sessions

Pour voir l'historique de vos sessions :

```
/kiss-orchestrator list
```

Affiche :

```
=== SESSIONS ===
ID                | Created              | Status      | Title
------------------|----------------------|-------------|---------------------------
20260414-153022   | 2026-04-14T15:30:22  | done        | Export CSV CLI
================
```

## Et ensuite ?

- Consultez les [guides pratiques](../how-to/index.md) pour des operations specifiques
- Lisez la [reference des agents](../reference/agents.md) pour comprendre les roles de chacun
- Decouvrez la [boucle d'amelioration](../how-to/boucle-amelioration.md) avec kiss-improver
