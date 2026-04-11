# Design Note: `tests/lib/claude_cli.py`

> **Type**: design-note  
> **Target**: `tests/lib/claude_cli.py`  
> **Date**: 2026-04-11  
> **Source sessions**: Phase 1 research (SCRATCH.md) + Phase 2 POCs (poc_08_summary.md)  
> **Status**: final

Ce document retranscrit le raisonnement qui a conduit au design de `claude_cli.py`, en articulant chaque décision de conception avec son origine empirique.

---

## Contexte : pourquoi ce module existe

Le projet kiss-claw nécessitait un framework de tests pour valider ses agents. Deux contraintes fondamentales ont orienté l'architecture :

1. **Zéro dépendance externe** — stdlib Python uniquement, pas de pip
2. **CLI only** — OAuth, pas d'`ANTHROPIC_API_KEY`, jamais l'API directe

La question était : peut-on invoquer `claude -p "..."` de façon fiable depuis Python et en tirer des assertions de test ? Les Phases 1 et 2 ont répondu empiriquement.

---

## Étape 1 — Inventaire des paramètres (Phase 1 Research)

> Source : `.kiss-claw/SCRATCH.md` — CLI Version 2.1.90

L'investigation exhaustive a révélé **6 catégories de flags** disponibles pour le mode programmatique (`-p` / `--print`) :

### 1.1 Flags d'invocation de base

```bash
claude -p "prompt"            # Mode non-interactif, stdout = réponse
claude -p --output-format json "prompt"  # JSON structuré avec métadonnées complètes
```

**Découverte clé** : `-p` / `--print` est **le seul flag** qui active le mode programmatique. Sans lui, Claude est interactif. Tout le reste en découle.

### 1.2 Flags de contrôle du modèle

| Flag | Description |
|------|-------------|
| `--model <model>` | Alias (`sonnet`, `opus`) ou nom complet (`claude-haiku-4-5-20251001`) |
| `--effort <level>` | `low`, `medium`, `high`, `max` |
| `--fallback-model <model>` | Fallback en cas de surcharge (mode `--print` only) |

**Impact design** : Ces deux flags sont exposés dans `invoke()` car ils contrôlent directement le coût par appel. Le défaut `--effort low` dans les tests réduit la consommation de tokens de raisonnement.

### 1.3 Flags de session

| Flag | Cas d'usage |
|------|------------|
| `--no-session-persistence` | Empêche l'écriture sur disque (tests isolés) |
| `--resume <id>` | Reprend une conversation par son session_id |
| `--session-id <uuid>` | Force un UUID spécifique |

**Découverte critique** : `--resume` est **incompatible** avec `--no-session-persistence`. On ne peut pas reprendre une session qui n'a jamais été persistée. Le design de `invoke()` gère ce conflit explicitement via le paramètre `resume_session`.

### 1.4 Flags de sécurité et permissions

```bash
--dangerously-skip-permissions   # Bypasse tous les prompts interactifs
--permission-mode <mode>          # default, acceptEdits, bypassPermissions, dontAsk, plan, auto
```

**Impact design** : `--dangerously-skip-permissions` est inclus dans les `_DEFAULT_FLAGS` car sans lui, les tests s'arrêtent sur des prompts interactifs dans un contexte subprocess.

### 1.5 Flags de restriction d'outils

Trois mécanismes distincts (non-exclusifs) :

```bash
--tools ""                          # Désactive TOUS les outils
--allowedTools "Read,Glob"          # Whitelist explicite
--disallowedTools "Bash"            # Blacklist explicite
```

### 1.6 Flags de coût et config

```bash
--max-budget-usd <amount>           # Plafond en dollars (erreur structurée si dépassé)
--mcp-config '{"mcpServers":{}}'    # Override config MCP
--settings <json>                   # Paramètres supplémentaires
```

### 1.7 Ce qui N'EXISTE PAS

Absence confirmée de :
- `--dry-run` — n'existe pas dans le CLI
- `--mock` — n'existe pas  
- `--replay` — n'existe pas
- `--offline` — n'existe pas
- `--temperature` — pas un flag CLI
- `--max-tokens` — contrôlé par le modèle, pas exposé

**Conséquence directe** : le `dry_run=True` dans `claude_cli.py` est implémenté **côté Python** (intercepter avant subprocess.run), pas côté CLI.

---

## Étape 2 — Validation empirique (Phase 2 POCs)

> Source : `tests/poc/poc_08_summary.md` — 7 POCs, 7/7 PASS

### POC 01 — subprocess.run() fonctionne

```python
# Pattern validé :
result = subprocess.run(
    ["claude", "-p", "say hello"],
    capture_output=True, text=True, timeout=60
)
# stdout = réponse texte brute, exit_code=0
```

**→ Décision** : `subprocess.run()` synchrone, pas asyncio. Zéro complexité, zéro dépendance.

### POC 02 — JSON output est fiable

```python
data = json.loads(result.stdout)
# Champs disponibles :
data["result"]          # Texte de réponse
data["is_error"]        # Boolean
data["session_id"]      # UUID pour --resume
data["total_cost_usd"]  # Coût en dollars
data["num_turns"]       # Nombre de tours
data["modelUsage"]      # Quel modèle a tourné
data["duration_ms"]     # Durée en ms
data["subtype"]         # Type d'erreur si is_error=True
```

**→ Décision** : `ClaudeResult.json` stocke le dict parsé. `ClaudeResult.session_id` est extrait automatiquement pour faciliter les tests multi-tours.

### POC 03 — Flags de contrôle fonctionnent

```bash
# Validés :
--system-prompt "Reply with exactly: X"  # Sortie déterministe ✓
--max-turns 1                            # Limite respectée ✓
--model haiku                            # Confirmé via modelUsage ✓
--effort low                             # Raisonnement minimal ✓
```

**→ Décision** : `--system-prompt` est **le mécanisme de mock** pour les tests déterministes. Sans mock CLI natif, c'est le seul moyen de forcer une réponse prévisible.

### POC 04 — Restriction d'outils fonctionne

```bash
--tools ""           # Tous les outils désactivés ✓
--allowedTools Read  # Whitelist fonctionnelle ✓  
--disallowedTools Bash  # Blacklist fonctionnelle ✓
```

**Gotcha découvert** : Sans `--system-prompt`, le CLAUDE.md du projet contamine les réponses. Les tests 1-2 du POC initial ont échoué pour cette raison. Fix : ajouter `--system-prompt` à tous les appels de test.

### POC 05 — Gestion des erreurs

```python
# Timeout : subprocess.TimeoutExpired levé
except subprocess.TimeoutExpired as e:
    return ClaudeResult(exit_code=-1, ...)

# Budget dépassé :
# exit_code=1, is_error=True, subtype="error_max_budget_usd"
```

**Correction Phase 1** : la recherche initiale notait "exit code 0 même en cas d'erreur budget". Le POC a corrigé : **exit code 1** pour les erreurs budget. Mais `is_error` dans le JSON reste la source autoritaire.

**→ Décision** : exit_code=-1 pour timeout, -2 pour `FileNotFoundError` (binary claude absent). Ces codes non-standards distinguent les erreurs subprocess des erreurs CLI.

### POC 06 — Config isolée

```bash
--mcp-config '{"mcpServers":{}}'  # Pas de serveurs MCP ✓
--settings '{"permissions":{"allow":[],"deny":[]}}'  # Config minimale ✓
```

**→ Décision** : Ces flags sont exposés dans `invoke()` pour permettre des tests avec isolation maximale.

### POC 07 — Session continuation

```python
# Run 1 :
result1 = subprocess.run(["claude", "-p", "--output-format", "json", "hello"])
session_id = json.loads(result1.stdout)["session_id"]

# Run 2 :
result2 = subprocess.run(["claude", "-p", "--resume", session_id, "remember me?"])
```

**Contrainte découverte** : `--resume` est incompatible avec `--no-session-persistence`. La première invocation doit écrire sur disque pour que la session soit resumable.

**→ Décision** : Dans `invoke()`, si `resume_session` est fourni, on n'ajoute pas `--no-session-persistence`.

---

## Étape 3 — Traduction en design `claude_cli.py`

### 3.1 Deux types d'objets

```python
@dataclass
class ClaudeResult:
    stdout: str = ""
    stderr: str = ""
    exit_code: int = 0
    json: Optional[Dict[str, Any]] = None   # Parsé si JSON détecté
    session_id: Optional[str] = None        # Extrait de json["session_id"]
```

**Choix** : `ClaudeResult` est un dataclass, pas une classe riche. Le test accède directement aux champs — pas de méthodes d'assertion intégrées (elles sont dans `assertions.py`).

### 3.2 Defaults figés pour les tests

```python
_DEFAULT_FLAGS = [
    "--no-session-persistence",     # Isolation disque
    "--dangerously-skip-permissions",  # Pas de prompts interactifs
    "--effort", "low",              # Coût minimal
]
```

Ces trois flags sont **systématiques** dans le contexte de test. Les rendre overridables complexifierait l'API sans bénéfice réel.

### 3.3 Logique de session dans la construction de commande

```python
if resume_session:
    # --no-session-persistence exclu (incompatible avec --resume)
    cmd.extend(["--resume", resume_session])
    cmd.extend(["--dangerously-skip-permissions"])
    cmd.extend(["--effort", effort or "low"])
else:
    # Flags par défaut normaux
    cmd.extend(_DEFAULT_FLAGS)
```

Ce branchement traduit directement la contrainte découverte en POC 07.

### 3.4 Dry-run implémenté côté Python

Puisque `--dry-run` n'existe pas dans le CLI :

```python
if dry_run:
    cmd_str = " ".join(cmd)
    print(f"[DRY RUN] Would execute: {cmd_str[:500]}")
    fake_json = {"result": "[dry-run]", "is_error": False, "session_id": "dry-run-000"}
    return ClaudeResult(
        stdout=json.dumps(fake_json),
        exit_code=0,
        json=fake_json,
        session_id="dry-run-000",
    )
```

**Cas d'usage** : valider les imports, chemins et construction de commande sans coût LLM. `python tests/lib/runner.py --dry-run` utilise ce mécanisme.

### 3.5 Parsing JSON heuristique

```python
if output_format == "json" or _looks_like_json(proc.stdout):
    try:
        data = json.loads(proc.stdout)
        result.json = data
        result.session_id = data.get("session_id")
    except (json.JSONDecodeError, ValueError):
        pass

def _looks_like_json(text: str) -> bool:
    stripped = text.strip()
    return stripped.startswith("{") or stripped.startswith("[")
```

**Choix pragmatique** : même sans `--output-format json` explicite, si la réponse ressemble à du JSON, on tente le parsing. Utile pour des tests où le format n'est pas contrôlé.

---

## Étape 4 — Décisions clés et compromis

### 4.1 subprocess.run() synchrone vs asyncio

**Option écartée** : asyncio (requis par le SDK officiel `claude-code-sdk`)  
**Option retenue** : `subprocess.run()` synchrone

**Justification** :
- Zéro dépendance externe (contrainte hard du projet)
- Les tests kiss-claw sont séquentiels par nature
- Le SDK v0.0.25 est trop immature (version early-stage)
- Code plus simple = moins de surface d'erreur

### 4.2 SDK vs subprocess

Le SDK `claude-code-sdk` a été évalué. Il wrape lui-même le CLI en subprocess avec `--output-format stream-json --verbose`. On aurait une dépendance pip pour récupérer ce qui est faisable en stdlib.

**→ Décision** : subprocess direct. Les seuls avantages du SDK (streaming, multi-turn avec callbacks) ne sont pas nécessaires pour le pattern de tests kiss-claw.

### 4.3 Gestion des exit codes non-standard

```
exit_code  0  → succès (ou erreur budget capturée en JSON)
exit_code  1  → erreur CLI (budget, permissions)
exit_code -1  → subprocess.TimeoutExpired
exit_code -2  → FileNotFoundError (claude binary absent)
```

Les codes -1 et -2 sont des conventions internes à `claude_cli.py`. Ils permettent aux assertions de distinguer une erreur CLI d'une erreur environnement.

### 4.4 Ce qui est délibérément absent

- `--output-format stream-json` — non exposé (requiert `--verbose`, complexité inutile pour tests synchrones)
- `--bare` mode — non exposé (requiert `ANTHROPIC_API_KEY`, incompatible avec OAuth)
- `--json-schema` — non exposé (cas d'usage spécialisé, pas nécessaire pour kiss-claw)
- `--debug` — non exposé (debug via stderr direct si nécessaire)

---

## Récapitulatif : de la recherche au code

| Découverte Phase 1/2 | Décision de design dans claude_cli.py |
|----------------------|--------------------------------------|
| `-p` obligatoire pour mode non-interactif | `cmd = ["claude", "-p"]` — toujours en premier |
| `--dangerously-skip-permissions` nécessaire | Dans `_DEFAULT_FLAGS` |
| `--no-session-persistence` pour isolation | Dans `_DEFAULT_FLAGS` |
| `--resume` incompatible avec `--no-session-persistence` | Branchement conditionnel sur `resume_session` |
| Pas de `--dry-run` dans le CLI | `dry_run=True` intercepté avant subprocess.run() |
| JSON fiable et auto-suffisant | `ClaudeResult.json` + extraction `session_id` |
| exit_code 1 pour erreurs budget | Codes -1/-2 pour erreurs subprocess distinctes |
| `--system-prompt` = seul mécanisme mock | Exposé comme `system_prompt` dans `invoke()` |
| CLAUDE.md contamine sans `--system-prompt` | Documenté — à charge du test de le fournir |
| SDK asyncio = complexité sans bénéfice | subprocess.run() synchrone, zéro dépendance |

---

## Exemple complet — test avec assertions

```python
from tests.lib.claude_cli import invoke
from tests.lib.assertions import assert_exit_code, assert_json_field

# Test déterministe avec system-prompt
result = invoke(
    prompt="say hello",
    output_format="json",
    system_prompt="You are a test bot. Always reply with exactly: MOCK_OK",
    max_turns=1,
    model="haiku",
    timeout=30,
)

assert_exit_code(result, 0)
assert_json_field(result, "is_error", False)
assert "MOCK_OK" in result.json["result"]
print(f"Cost: ${result.json['total_cost_usd']:.4f}")

# Test multi-turn avec session continuation
r1 = invoke("remember: secret=42", output_format="json")
r2 = invoke("what is secret?", resume_session=r1.session_id, output_format="json")
assert "42" in r2.json["result"]

# Test dry-run (pas d'appel LLM)
r = invoke("any prompt", dry_run=True)
assert r.session_id == "dry-run-000"
assert r.exit_code == 0
```

---

*Note générée à partir des sessions de design Phase 1 (2026-04-10) et des 7 POCs validés.*

---

## Q&A — Isolation du contexte de démarrage

### Q : Peut-on démarrer Claude avec un contexte vraiment minimaliste (pas de MCP, pas de skills, contrôle sur les CLAUDE.md chargés) ?

**Réponse courte** : oui pour MCP et outils, non natif pour les fichiers CLAUDE.md.

### `--bare` — le plus complet, mais incompatible OAuth

```bash
ANTHROPIC_API_KEY=xxx claude -p --bare "prompt"
```

Élimine d'un coup :
- ✗ Hooks (PreToolUse, PostToolUse, etc.)
- ✗ LSP
- ✗ Plugins / skills
- ✗ Auto-memory
- ✗ CLAUDE.md discovery (tous les niveaux)

**Mais** : requiert `ANTHROPIC_API_KEY` en variable d'environnement. **Incompatible avec OAuth.** Ce qui casse la contrainte fondamentale du projet kiss-claw.

### Sans `--bare` : combinaison de flags (compatible OAuth)

| Ce qu'on veut éliminer | Flag |
|------------------------|------|
| Serveurs MCP | `--mcp-config '{"mcpServers":{}}'` |
| MCP additionnels uniquement | `+ --strict-mcp-config` |
| Tous les outils | `--tools ""` |
| Outils spécifiques | `--disallowedTools "Bash,Edit,Write"` |
| Sources de settings | `--setting-sources user` (exclut project/local) |
| Comportement CLAUDE.md | `--system-prompt "..."` (override total du system prompt) |

### Sur les fichiers CLAUDE.md : pas de contrôle natif

Il n'existe **aucun flag** pour choisir quels CLAUDE.md sont chargés (projet, parent, global).  
Claude charge la hiérarchie automatiquement.

Le seul contournement : `--system-prompt` **remplace entièrement** le system prompt — écrase l'effet des CLAUDE.md sur le comportement du modèle, mais ne les empêche pas d'être lus.

### Contexte minimal validé sous OAuth (POC 06)

```python
invoke(
    prompt="...",
    mcp_config='{"mcpServers":{}}',
    settings='{"permissions":{"allow":[],"deny":[]}}',
    allowed_tools=[],       # aucun outil disponible
    system_prompt="...",    # override comportemental des CLAUDE.md
)
```

### Conclusion

| Niveau d'isolation | Mécanisme | Fonctionne avec OAuth ? |
|--------------------|-----------|------------------------|
| Isolation totale (MCP + skills + CLAUDE.md) | `--bare` | ✗ (requiert API key) |
| Isolation MCP + outils | `--mcp-config + --tools ""` | ✓ |
| Isolation comportementale CLAUDE.md | `--system-prompt` | ✓ (partiel) |
| Isolation répertoire (pas de CLAUDE.md) | Docker + workdir sans CLAUDE.md | ✓ |

Si l'isolation totale est nécessaire sans API key : utiliser un **répertoire de travail sans CLAUDE.md** (via `cwd=` vers un tmpdir vide) combiné à `--mcp-config '{"mcpServers":{}}'` et `--tools ""`.

```python
import tempfile
with tempfile.TemporaryDirectory() as tmpdir:
    result = invoke(
        prompt="...",
        cwd=tmpdir,                          # Pas de CLAUDE.md dans ce dir
        mcp_config='{"mcpServers":{}}',
        allowed_tools=[],
        system_prompt="You are a test bot.",
    )
```
