# ISSUES - kiss-claw

## Ouvertes

### ISSUE-001: Gestion d'issues et TODO via kiss-store
**Priorite:** haute
**Type:** feature
**Description:** kiss-store doit pouvoir ecrire/lire directement dans un fichier ISSUES.md situe dans `.kiss-claw/`. Cela permet de tracker les issues sans dependance externe.
**Evolution future:** kiss-store read/write issue devra pouvoir appeler les commandes GitHub CLI (`gh issue create`, `gh issue list`, etc.) pour synchroniser avec GitHub Issues.

---

### ISSUE-002: Execution de tests via Docker
**Priorite:** tres haute (prerequis pour valider les autres issues)
**Type:** feature
**Description:** Pouvoir instancier un conteneur Docker sur la machine, a partir d'un dossier vierge, avec des prompts etablis. Verifier en sortie que les prompts demandes ont bien produit les fichiers attendus. Forme de test de non-regression fonctionnel (smoke tests).
**Etapes:**
- Creer un Dockerfile / docker-compose pour l'environnement de test
- Definir un format de prompts de test + resultats attendus
- Script de verification automatique des outputs

---

### ISSUE-003: Integration kiss-claw avec d'autres frameworks (OMC, etc.)
**Priorite:** moyenne
**Type:** feature
**Description:** Pouvoir integrer le framework kiss-claw avec un autre framework deploye (OMC ou autre). Utiliser kiss pour orchestrer, appeler les orchestrateurs, et faire progresser l'autre framework via les agents kiss (improver, orchestrator, executor).

---

### ISSUE-004: Agent kiss-reducer (nettoyage et refactorisation)
**Priorite:** haute
**Type:** feature
**Description:** Nouvel agent qui parse les fichiers memoire et les agents pour reduire, refactoriser, nettoyer. Les fichiers MEMORY de chaque agent grossissent au fil du temps. Questions cles :
- Faut-il repercuter certaines memoires directement dans le code des agents plutot que les garder en fichiers MEMORY ?
- Qu'est-ce qu'on peut jeter sans casser les tests ?
- Necessite des tests de non-regression pour valider que le nettoyage ne change pas le comportement.
**Note:** Proche de kiss-improver mais oriente reduction/cleanup plutot qu'amelioration.

---

### ISSUE-005: Hooks broken (guard, session-end, agent-suggest)
**Priorite:** haute
**Type:** bug
**Status:** BROKEN - a reparer en temps voulu
**Description:** Les hooks (guard.sh, session-end.sh, agent-suggest.sh) ne fonctionnent pas du tout dans l'etat actuel. Marques comme broken, seront repares ulterieurement.

---

### ISSUE-006: Commande d'aide
**Priorite:** moyenne
**Type:** feature
**Description:** Ajouter une commande d'aide (`/kiss-help` ou equivalent) qui explique comment utiliser kiss-claw : agents disponibles, commandes store, workflow type, etc.

---

### ISSUE-007: Tracabilite directives/verifications
**Priorite:** basse (long terme)
**Type:** feature
**Description:** Implementer une forme de tracabilite entre les directives des agents et les verifications effectuees. Necessitera un ou plusieurs nouveaux types de store dedies a la tracabilite.
**Etapes:**
- Definir le modele de tracabilite (directive -> action -> verification -> resultat)
- Nouveau type de ressource store pour la tracabilite
- Integration avec kiss-verificator

---

## Fermees

(aucune pour l'instant)
