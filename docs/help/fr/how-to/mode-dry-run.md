# Mode dry-run

Comment activer et desactiver le mode dry-run pour valider un workflow sans modifications.

## Activer le dry-run

Dites a kiss-orchestrator :

```
dry-run on
```

Ou directement via store.sh :

```bash
KISS_CLAW_SESSION=<id> bash scripts/store.sh update state mode "dry-run"
```

L'orchestrateur confirme :

```
mode: dry-run active -- kiss-executor will describe but not write
```

## Desactiver le dry-run

```
dry-run off
```

Ou :

```bash
KISS_CLAW_SESSION=<id> bash scripts/store.sh update state mode "live"
```

## Ce que fait le dry-run

Quand `mode: dry-run` est actif dans STATE.md, kiss-executor change de comportement :

- Au lieu d'ecrire des fichiers, il decrit ce qu'il **ferait** :

```
[dry-run] Would write: src/auth.py (42 lines)
[dry-run] Would run: pytest tests/test_auth.py
[dry-run] Would modify: .env -- add AUTH_SECRET key
```

- Il ne fait **aucun** appel aux outils Write, Edit ou Bash
- Il produit le task report normalement, avec le prefixe `[dry-run]` sur chaque ligne Done
- Le rapport est complet : vous voyez exactement ce qui serait fait

## Quand l'utiliser

- **Valider un plan** : avant d'executer, activez le dry-run pour voir ce que kiss-executor ferait a chaque etape
- **Tester un workflow** : verifier que les etapes s'enchainent correctement sans toucher au code
- **Demontrer kiss-claw** : montrer le fonctionnement du systeme sans effets de bord
- **Sessions d'exploration** : quand vous n'etes pas sur du plan et voulez voir le deroulement avant de vous engager
