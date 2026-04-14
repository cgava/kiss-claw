# Protection des fichiers

Pourquoi kiss-claw protege certains fichiers contre l'ecriture directe, et comment ce mecanisme fonctionne.

## Le probleme

Dans un systeme multi-agents, les fichiers d'etat sont critiques :

- **PLAN.md** est immutable apres creation. Si un agent le modifie, le plan perd sa valeur de reference.
- **STATE.md** est la source de verite de la progression. Deux agents ecrivant en meme temps corrompent l'etat.
- **REVIEWS.md** ne doit contenir que des verdicts de kiss-verificator. Un autre agent y ecrivant fausserait le processus de review.
- **MEMORY.md** contient le contexte partage. Des modifications non coordonnees creent des incoherences.

Le risque principal : un agent LLM peut decider d'utiliser l'outil `Write` ou `Edit` directement sur ces fichiers, contournant le protocole de persistence.

## La solution : guard.sh

`guard.sh` est un hook `PreToolUse` qui s'execute **avant** chaque utilisation des outils `Write`, `Edit`, `str_replace_based_edit_tool` et `Bash` par Claude Code.

Le guard maintient une table de propriete implicite :

| Fichier              | Proprietaire      |
|---------------------|-------------------|
| `MEMORY_kiss-*.md`   | L'agent lui-meme  |
| `INSIGHTS.md`        | kiss-improver     |
| `ANALYZED.md`        | kiss-improver     |
| `MEMORY.md`          | kiss-improver     |
| `PLAN.md`            | kiss-orchestrator |
| `STATE.md`           | kiss-orchestrator |
| `CHECKPOINT.md`      | kiss-orchestrator |
| `REVIEWS.md`         | kiss-verificator  |

Quand le guard detecte une tentative d'ecriture sur un fichier protege, il bloque l'operation et affiche un message explicatif :

```
BLOCK: .kiss-claw/sessions/20260414-153022/STATE.md is a protected session file.
Only kiss-orchestrator may write to it via /kiss-store.
```

## L'exception store.sh

Le guard laisse passer toutes les commandes bash contenant `scripts/store.sh`. C'est le **seul chemin autorise** pour modifier les fichiers proteges.

Concretement, quand le guard intercepte une commande bash :
1. Il verifie si la commande contient `scripts/store.sh`
2. Si oui : laisse passer (code de sortie 0)
3. Si non : verifie les redirections (`>`, `>>`) vers des fichiers proteges

Cela signifie que `store.sh` est le gardien de facto de la coherence. Les agents appellent `store.sh` via bash, le guard laisse passer, et `store.sh` effectue l'ecriture.

## Comment ca fonctionne techniquement

1. Claude Code appelle un outil (Write, Edit, Bash)
2. Le hook `PreToolUse` est declenche
3. `guard.sh` recoit les variables d'environnement :
   - `CLAUDE_TOOL_NAME` : nom de l'outil (Write, Edit, Bash)
   - `CLAUDE_TOOL_INPUT_PATH` : chemin du fichier cible (pour Write/Edit)
   - `CLAUDE_TOOL_INPUT_COMMAND` : commande bash (pour Bash)
4. Le guard normalise le chemin (supprime les `./` en prefixe)
5. Il verifie si le fichier est dans la liste des proteges :
   - Pour Write/Edit : compare le chemin aux patterns proteges
   - Pour Bash : cherche les redirections vers des fichiers proteges
6. Si protege : affiche le message BLOCK et retourne code 1 (blocage)
7. Si non protege : retourne code 0 (autorisation)

## Limites connues

- Le guard ne peut pas verifier les ecritures indirectes (un script bash appelant un autre script qui ecrit)
- La protection est basee sur le nom de fichier, pas sur le contenu. Renommer un fichier contournerait le guard.
- Le guard ne differencie pas les agents. Il ne sait pas quel agent est actif. La restriction est que **personne** ne peut ecrire directement, seul store.sh est autorise.
- La table de propriete est codee en dur dans le script. L'ajout d'un nouveau fichier protege necessite une modification de guard.sh.
