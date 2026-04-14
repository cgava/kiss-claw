# Comment utiliser /kiss-help

Le skill `/kiss-help` permet de naviguer dans la documentation kiss-claw directement depuis Claude Code ou le terminal.

## Commandes disponibles

### Sans argument -- Index principal

```bash
/kiss-help
# ou
bash scripts/help.sh
```

Affiche l'index principal avec les 4 sections de documentation : tutorials, how-to, reference, explanation.

### Par section -- Index d'une section

```bash
/kiss-help tutorials
/kiss-help how-to
/kiss-help reference
/kiss-help explanation
```

Affiche l'index de la section choisie avec la liste des pages disponibles.

### Par nom de page -- Afficher une page

```bash
/kiss-help store-sh
/kiss-help premiere-session
/kiss-help architecture
```

Recherche et affiche la page correspondante, quel que soit la section dans laquelle elle se trouve. Le nom correspond au nom du fichier sans l'extension `.md`.

### `search` -- Recherche plein texte

```bash
/kiss-help search orchestrator
/kiss-help search session checkpoint
```

Recherche les termes dans toute la documentation et affiche les lignes correspondantes avec leur emplacement.

### `list` -- Lister toutes les pages

```bash
/kiss-help list
```

Affiche toutes les pages de documentation organisees par section, avec leur titre et chemin relatif.

## Quand utiliser /kiss-help

- **Chercher un processus** : vous ne savez plus comment fermer une session ? `/kiss-help search fermer session` ou `/kiss-help gerer-sessions`.
- **Verifier une commande** : quelle est la syntaxe de `store.sh update` ? `/kiss-help utiliser-store`.
- **Decouvrir kiss-claw** : premier contact ? `/kiss-help` puis `/kiss-help tutorials`.
- **Comprendre l'architecture** : pourquoi 4 agents ? `/kiss-help architecture`.
- **Trouver une reference** : quel est le format de CHECKPOINT.yaml ? `/kiss-help search CHECKPOINT`.

## Exemples concrets

```bash
# Nouveau sur kiss-claw : commencer par le tutorial
/kiss-help premiere-session

# Besoin de savoir comment le store fonctionne
/kiss-help utiliser-store

# Chercher tout ce qui parle de dry-run
/kiss-help search dry-run

# Lister toutes les pages disponibles pour avoir une vue d'ensemble
/kiss-help list

# Consulter la reference d'un script
/kiss-help store-sh
```
