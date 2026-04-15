# Design: Interactive Test Runner for Agent Scenarios

> Session kiss-claw `20260415-113650` — Phase 2 Design
> Date : 2026-04-15
> Prerequis : [260415-agent-interactive-testing-state-of-art.md](../research/260415-agent-interactive-testing-state-of-art.md)

---

## Table des matieres

1. [Decisions de design](#1-decisions-de-design)
2. [Format de scenario](#2-format-de-scenario)
3. [Approche technique](#3-approche-technique)
4. [Analyse des dependances](#4-analyse-des-dependances)
5. [Contrat du runner interactif](#5-contrat-du-runner-interactif)
6. [Integration avec le framework existant](#6-integration-avec-le-framework-existant)
7. [Migration du scenario 02-konvert-agents](#7-migration-du-scenario-02-konvert-agents)

---

## 1. Decisions de design

| Decision | Choix | Justification |
|----------|-------|---------------|
| Format de scenario | YAML sequentiel avec `alternatives` optionnel | Simple a ecrire, lisible, extensible vers DAG si besoin |
| Approche technique | `--resume` chaining (subprocess par tour) | Prouve dans poc_07, zero dep, debug facile |
| Dependances | stdlib only (v1) | Coherent avec les contraintes projet, pexpect en fallback |
| Assertions | Structurelles + regex + `output_matches` | Pas de LLM-as-judge en v1 |
| Debug output | `--debug-file` par defaut dans tous les runs | Observabilite sans polluer stdout |
| Dry-run | Le runner simule les tours sans appeler le CLI | Compatibilite avec `--dry-run` existant |

---

## 2. Format de scenario

### 2.1 Fichier scenario

Chaque scenario interactif est decrit dans un fichier `scenario.yaml` place dans le
repertoire du scenario (ex: `tests/scenarios/02-konvert-agents/scenario.yaml`).

Le fichier `test_*.py` charge et execute le scenario via le runner interactif.

### 2.2 Structure YAML

```yaml
# scenario.yaml — Interactive agent test scenario
name: "02-konvert-agents"
description: "Integration test: orchestrator INIT -> plan -> executor delegation"

# Configuration agent
agent:
  model: "sonnet"
  effort: "medium"
  max_turns: 0                    # 0 = no limit per step
  timeout_per_step: 300           # seconds per invoke() call
  extra_flags:
    - "--plugin-dir"
    - "{{repo_root}}"             # interpolated at runtime

# Configuration test
test:
  workspace: "tempdir"            # "tempdir" = create temp dir, or path
  debug_file: true                # write --debug-file per step
  cleanup_on_success: false       # preserve workspace for inspection

# Steps — ordered sequence of interactions
steps:
  - id: "start"
    description: "Launch orchestrator with konvert project context"
    action:
      type: "prompt"              # first turn = new session
      content: |
        Use the kiss-claw agent workflow. Start by invoking
        /kiss-claw:kiss-orchestrator to plan and coordinate all work.
        [... full prompt ...]
    expect:
      - type: "output_matches"
        pattern: "(?i)(what are you building|question 1|que construi)"
        description: "Agent asks first INIT question"
    on_failure: "abort"           # abort | continue | skip_to:<id>

  - id: "init-q1-answer"
    description: "Answer INIT question 1"
    action:
      type: "resume"              # continues session from previous step
      content: |
        Building a konvert.sh script that converts Markdown to HTML.
        Accept all defaults and move to next steps.
    expect:
      - type: "output_matches"
        pattern: "(?i)(phase|milestone|question 2|jalons)"
        description: "Agent asks about phases/milestones"
    on_failure: "continue"

  - id: "init-q2-answer"
    description: "Answer INIT question 2"
    action:
      type: "resume"
      content: |
        Phase 1: parser, Phase 2: CLI script, Phase 3: tests,
        Phase 4: review, Phase 5: improvements, Phase 6: delivery.
    expect:
      - type: "output_matches"
        pattern: "(?i)(constraint|non.?goal|question 3|contrainte)"
        description: "Agent asks about constraints"
    on_failure: "continue"

  - id: "init-q3-answer"
    description: "Answer INIT question 3"
    action:
      type: "resume"
      content: |
        No external dependencies, bash only, no pandoc.
        Proceed with the plan.
    expect:
      - type: "output_matches"
        pattern: "(?i)(proceed|plan|phase 1|ready)"
        description: "Agent confirms plan and is ready to proceed"
      - type: "file_exists"
        path: ".kiss-claw/sessions/*/PLAN.md"
        description: "PLAN.md created in session directory"
    on_failure: "continue"

  - id: "delegation"
    description: "Let agent work through delegation (long-running)"
    action:
      type: "resume"
      content: "Yes, proceed. Execute all phases."
      timeout: 18000              # 5h override for this step
    expect:
      - type: "file_exists"
        path: "konvert.sh"
        description: "konvert.sh script created"
      - type: "file_exists"
        path: "test_konvert.sh"
        description: "test_konvert.sh script created"
      - type: "file_contains"
        path: ".kiss-claw/sessions/*/PLAN.md"
        pattern: "(?i)(phase|etape)"
        description: "PLAN.md contains phase information"
    on_failure: "abort"

# Final assertions — checked after all steps complete
final_assertions:
  - type: "exit_code"
    value: 0
    description: "Last step exited cleanly"
  - type: "file_exists"
    path: "konvert.sh"
    required: true
  - type: "file_executable"
    path: "konvert.sh"
    required: true
  - type: "file_exists"
    path: "test_konvert.sh"
    required: true
  - type: "file_executable"
    path: "test_konvert.sh"
    required: true
  - type: "file_exists"
    path: ".kiss-claw/sessions/*/PLAN.md"
    required: true
  - type: "file_contains"
    path: ".kiss-claw/sessions/*/PLAN.md"
    pattern: "(?i)(phase|etape|étape)"
    required: true
  - type: "file_exists"
    path: ".kiss-claw/sessions/*/STATE.md"
    required: true
  - type: "file_exists"
    path: ".kiss-claw/sessions/*/REVIEWS.md"
    required: false              # soft criterion
  - type: "file_exists"
    path: ".kiss-claw/sessions/*/CHECKPOINT.yaml"
    required: false              # soft criterion
```

### 2.3 Types d'action

| Type | Comportement |
|------|-------------|
| `prompt` | Premier tour — `invoke(content, ...)` cree une nouvelle session |
| `resume` | Tour suivant — `invoke(content, resume_session=session_id)` |
| `wait` | Pause N secondes (pour laisser des side-effects se completer) |

### 2.4 Types d'assertion (expect)

| Type | Parametres | Description |
|------|-----------|-------------|
| `output_matches` | `pattern` (regex) | stdout du tour matche le pattern |
| `output_not_matches` | `pattern` (regex) | stdout ne matche PAS le pattern |
| `file_exists` | `path` (glob ok) | Fichier existe dans le workspace |
| `file_not_exists` | `path` | Fichier n'existe PAS |
| `file_contains` | `path`, `pattern` (regex) | Contenu du fichier matche |
| `file_executable` | `path` | Fichier est executable |
| `exit_code` | `value` (int) | Exit code du tour |

### 2.5 Controle de flux

| Champ | Valeurs | Description |
|-------|---------|-------------|
| `on_failure` | `abort` | Arrete le scenario immediatement |
| | `continue` | Enregistre l'echec et continue au step suivant |
| | `skip_to:<id>` | Saute au step indique (branchement) |

### 2.6 Interpolation

Le runner interpole les variables suivantes dans les champs `content` et `path` :

| Variable | Valeur |
|----------|--------|
| `{{repo_root}}` | Chemin absolu de la racine kiss-claw |
| `{{workspace}}` | Chemin absolu du workspace de test |
| `{{session_id}}` | Session ID Claude du tour courant |
| `{{step_id}}` | ID du step en cours |

### 2.7 Extensions futures (non implementees en v1)

- **`alternatives`** : liste de patterns accept dans `expect`, avec branchement different par pattern matche (decision tree)
- **`parallel_steps`** : groupe de steps executables en parallele
- **`loop`** : repetition d'un step jusqu'a condition
- **`mock_response`** : reponse pre-enregistree au lieu d'appel CLI (pour tests unitaires du runner)

---

## 3. Approche technique

### 3.1 Architecture du runner interactif

```
scenario.yaml
     |
     v
scenario_runner.py          # Nouveau module dans tests/lib/
     |
     |-- load_scenario()    # Parse YAML, valide structure
     |-- run_scenario()     # Execute les steps sequentiellement
     |       |
     |       |-- step "prompt"  --> invoke(content, ...) --> capture session_id
     |       |-- step "resume"  --> invoke(content, resume_session=id, ...)
     |       |-- step "wait"    --> time.sleep(N)
     |       |
     |       |-- pour chaque step: evaluer expect[]
     |       |-- si echec: appliquer on_failure (abort/continue/skip_to)
     |       |
     |       \-- apres tous les steps: evaluer final_assertions[]
     |
     \-- ScenarioResult     # Nouveau dataclass avec resultats par step
```

### 3.2 Sequence d'execution detaillee

```python
def run_scenario(scenario_path, workspace, dry_run=False):
    """Execute un scenario interactif step par step.
    
    Returns:
        ScenarioResult avec step_results[], final_results[], session_id
    """
    scenario = load_scenario(scenario_path)
    session_id = None
    step_results = []
    
    for step in scenario["steps"]:
        # Interpoler les variables
        content = interpolate(step["action"]["content"], {
            "repo_root": REPO_ROOT,
            "workspace": workspace,
            "session_id": session_id,
            "step_id": step["id"],
        })
        
        # Construire les flags depuis scenario.agent
        agent_config = scenario["agent"]
        
        # Determiner le type d'action
        if step["action"]["type"] == "prompt":
            result = invoke(
                content,
                output_format="json",
                model=agent_config["model"],
                effort=agent_config["effort"],
                max_turns=agent_config.get("max_turns", 0),
                timeout=step["action"].get("timeout", agent_config["timeout_per_step"]),
                extra_flags=_interpolate_flags(agent_config.get("extra_flags", []), vars),
                cwd=workspace,
                dry_run=dry_run,
            )
            session_id = result.session_id
            
        elif step["action"]["type"] == "resume":
            assert session_id, f"Step {step['id']}: resume sans session_id"
            result = invoke(
                content,
                output_format="json",
                model=agent_config["model"],
                effort=agent_config["effort"],
                max_turns=agent_config.get("max_turns", 0),
                timeout=step["action"].get("timeout", agent_config["timeout_per_step"]),
                resume_session=session_id,
                extra_flags=_interpolate_flags(agent_config.get("extra_flags", []), vars),
                cwd=workspace,
                dry_run=dry_run,
            )
            
        elif step["action"]["type"] == "wait":
            time.sleep(step["action"].get("duration", 5))
            continue
        
        # Evaluer les assertions du step
        step_passed, step_failures = evaluate_expects(
            step.get("expect", []),
            result=result,
            workspace=workspace,
        )
        
        step_results.append(StepResult(
            id=step["id"],
            description=step.get("description", ""),
            passed=step_passed,
            failures=step_failures,
            result=result,
        ))
        
        # Controle de flux
        if not step_passed:
            on_failure = step.get("on_failure", "abort")
            if on_failure == "abort":
                break
            elif on_failure.startswith("skip_to:"):
                target = on_failure.split(":", 1)[1]
                # Sauter au step cible (a implementer)
                pass
            # "continue" = on continue naturellement
    
    # Assertions finales
    final_results = evaluate_final_assertions(
        scenario.get("final_assertions", []),
        last_result=result,
        workspace=workspace,
    )
    
    return ScenarioResult(
        name=scenario["name"],
        step_results=step_results,
        final_results=final_results,
        session_id=session_id,
    )
```

### 3.3 Debug output

Chaque invocation CLI recoit `--debug-file <path>` quand `test.debug_file: true` :

```python
debug_path = os.path.join(workspace, f".kiss-claw-debug/{step['id']}.log")
os.makedirs(os.path.dirname(debug_path), exist_ok=True)
extra_flags.extend(["--debug-file", debug_path])
```

Les fichiers debug sont preserves dans le workspace pour analyse post-mortem.

### 3.4 Dry-run

En mode `--dry-run`, le runner :
1. Parse et valide le `scenario.yaml` (syntaxe, types, references)
2. Simule chaque step avec `invoke(..., dry_run=True)` (retourne fake result)
3. Skip les assertions `output_matches` (pas de stdout reel)
4. Valide les assertions `file_exists` seulement si `required: true` et pas en dry-run
5. Retourne un `ScenarioResult` avec status "dry-run" par step

---

## 4. Analyse des dependances

### 4.1 stdlib only (v1 — recommande)

| Module | Usage |
|--------|-------|
| `subprocess` | `invoke()` via `my-claude-minion` |
| `json` | Parse JSON responses |
| `re` | Regex assertions |
| `pathlib` | Glob pour `file_exists` avec wildcards |
| `dataclasses` | `StepResult`, `ScenarioResult` |
| `time` | `wait` steps, durations |
| `tempfile` | Workspace temporaire |
| `os` | File permissions, env vars |

**Pas besoin de PyYAML** — le format YAML utilise est un sous-ensemble simple
parseable avec un parser minimaliste integre, OU on passe au format JSON.

### 4.2 Decision : YAML vs JSON pour le format scenario

| Critere | YAML | JSON |
|---------|------|------|
| Lisibilite | Excellente (multiline, pas de quotes) | Correcte mais verbose |
| Commentaires | Natifs (`#`) | Pas supportes |
| Multiline strings | Natif (`\|`) | Escaping `\n` |
| Parser stdlib | Non (PyYAML requis) | Oui (`json` stdlib) |
| Authoring effort | Bas | Medium |

**Decision** : utiliser **JSON** pour la v1 (zero dep), avec possibilite de migrer vers
YAML si on ajoute PyYAML plus tard. Le scenario est principalement ecrit une fois et lu
par le runner — la lisibilite est importante mais pas bloquante.

**Alternative evaluee** : parser YAML minimaliste en Python pur (~100 lignes pour le
sous-ensemble utilise). Rejete : fragile, maintenance additionnelle, fausse economie.

**Note** : PyYAML est deja dans le `.venv` du projet (utilise par `enrich_checkpoint.py`).
On pourrait l'utiliser directement. Mais pour la v1, JSON garde la coherence "zero dep
hors venv".

### 4.3 Dependances optionnelles evaluees

| Dependance | Avantage | Inconvenient | Decision |
|-----------|----------|-------------|----------|
| **PyYAML** | Format scenario plus lisible | Dep pip (mais deja dans .venv) | **v2** — quand le format se stabilise |
| **pexpect** | Simplifie wait-for-pattern/respond | Dep pip, pseudo-terminal | **Non** — `--resume` suffit |
| **promptfoo** | Multi-turn natif | Node.js, lourd, SDK-first | **Non** |
| **deepeval** | Metriques agent | SDK-first, pas CLI | **Non** |

---

## 5. Contrat du runner interactif

### 5.1 API publique

```python
# tests/lib/scenario_runner.py

@dataclass
class StepResult:
    """Result of a single scenario step."""
    id: str
    description: str
    passed: bool
    failures: list          # list of (assertion_type, description, error_msg)
    duration: float
    result: ClaudeResult    # raw CLI result (None for wait steps)

@dataclass
class ScenarioResult:
    """Result of a complete scenario execution."""
    name: str
    description: str
    step_results: list      # list of StepResult
    final_results: list     # list of (assertion_id, passed, description, error)
    session_id: str         # Claude session ID from first step
    total_duration: float
    workspace: str
    
    @property
    def passed(self) -> bool:
        """True if all steps and final assertions passed."""
        steps_ok = all(s.passed for s in self.step_results)
        finals_ok = all(f[1] for f in self.final_results if f[3] != "soft")
        return steps_ok and finals_ok


def load_scenario(scenario_path: str) -> dict:
    """Load and validate a scenario.json file.
    
    Raises ValueError if the scenario is malformed.
    """

def run_scenario(
    scenario_path: str,
    workspace: str,
    *,
    repo_root: str,
    dry_run: bool = False,
) -> ScenarioResult:
    """Execute a scenario step by step.
    
    Args:
        scenario_path: Path to scenario.json file.
        workspace: Path to test workspace directory.
        repo_root: Path to kiss-claw repository root.
        dry_run: If True, simulate without CLI calls.
    
    Returns:
        ScenarioResult with all step and final assertion results.
    """
```

### 5.2 Integration avec run(ctx)

Le scenario interactif s'integre dans le contrat `run(ctx)` existant :

```python
# tests/scenarios/02-konvert-agents/test_konvert_agents.py (v2)

from tests.lib.scenario_runner import run_scenario, load_scenario
from tests.lib.report import generate_scenario_report

def run(ctx):
    dry_run = ctx.get("dry_run", False)
    scenario_path = os.path.join(ctx["scenario_dir"], "scenario.json")
    repo_root = ctx["workspace"]  # kiss-claw repo root
    
    # Create isolated workspace (or use dry-run placeholder)
    workspace = tempfile.mkdtemp(prefix="kiss-claw-konvert-") if not dry_run else "(dry-run)"
    
    try:
        # Validate scenario even in dry-run
        scenario = load_scenario(scenario_path)
        
        # Execute
        result = run_scenario(
            scenario_path,
            workspace,
            repo_root=repo_root,
            dry_run=dry_run,
        )
        
        # Convert to AC results for report compatibility
        ac_results = _scenario_to_ac_results(result)
        
        # Write report
        _write_report(ctx, result, ac_results, workspace)
        
        # Raise if any hard criterion failed
        if not result.passed:
            failed = [s for s in result.step_results if not s.passed]
            summary = "; ".join(f"{s.id}: {s.failures}" for s in failed)
            raise AssertionError(f"Scenario steps failed: {summary}")
    
    finally:
        if not dry_run:
            print(f"  Workspace preserved: {workspace}")
```

### 5.3 Rapport enrichi

Le `generate_report()` existant dans `report.py` est etendu avec une section
"Scenario Steps" montrant le resultat de chaque tour :

```markdown
## Scenario Steps

| # | Step | Duration | Status | Detail |
|---|------|----------|--------|--------|
| 1 | start | 12.3s | PASS | Agent asks first INIT question |
| 2 | init-q1-answer | 8.7s | PASS | Agent asks about phases |
| 3 | init-q2-answer | 9.1s | PASS | Agent asks about constraints |
| 4 | init-q3-answer | 15.2s | PASS | PLAN.md created |
| 5 | delegation | 2341.0s | PASS | konvert.sh and test_konvert.sh created |
```

---

## 6. Integration avec le framework existant

### 6.1 Fichiers a creer

| Fichier | Description |
|---------|-------------|
| `tests/lib/scenario_runner.py` | Module runner interactif (load, run, evaluate) |
| `tests/scenarios/02-konvert-agents/scenario.json` | Scenario interactif pour konvert |

### 6.2 Fichiers a modifier

| Fichier | Modification |
|---------|-------------|
| `tests/lib/assertions.py` | Ajouter `assert_file_executable()`, `assert_output_matches()` |
| `tests/lib/report.py` | Ajouter section "Scenario Steps" dans `generate_report()` |
| `tests/scenarios/02-konvert-agents/test_konvert_agents.py` | Refactorer pour utiliser `scenario_runner` |
| `vendor/my-claude-minion/src/my_claude_minion/cli.py` | Ajouter support `--debug-file` dans `invoke()` |

### 6.3 Fichiers inchanges

| Fichier | Raison |
|---------|--------|
| `tests/lib/runner.py` | Le contrat `run(ctx)` reste identique |
| `tests/scenarios/01-hello-world/` | Scenario single-turn, pas concerne |
| `tests/scenarios/03-enrich-checkpoint/` | Scenario single-turn, pas concerne |

### 6.4 Retrocompatibilite

- Les scenarios single-turn existants continuent de fonctionner sans modification
- `runner.py` decouvre et execute les `test_*.py` comme avant
- `--dry-run` continue de fonctionner (le runner interactif le supporte)
- Le rapport de test conserve le meme format (enrichi avec les steps)

---

## 7. Migration du scenario 02-konvert-agents

### 7.1 Etat actuel

Le scenario actuel dans `test_konvert_agents.py` :
1. Envoie un mega-prompt unique avec toutes les instructions
2. Attend que l'agent finisse tout en un seul tour
3. Asserte sur les artefacts produits

**Probleme** : l'orchestrateur pose 3 questions INIT interactives avant de generer
le plan. En mode `claude -p` non-interactif, il s'arrete apres la question 1.

### 7.2 Migration

1. Creer `scenario.json` avec les 5 steps (start + 3 reponses INIT + delegation)
2. Refactorer `test_konvert_agents.py` pour utiliser `run_scenario()`
3. Conserver les AC-1 a AC-9 comme `final_assertions`
4. Ajouter les assertions intermediaires (output_matches sur les questions INIT)

### 7.3 Risques

| Risque | Mitigation |
|--------|-----------|
| L'agent ne pose pas exactement 3 questions | Patterns regex larges, `on_failure: continue` |
| L'agent reformule les questions | Regex multi-pattern avec alternatives OR |
| Le timeout par step est trop court | Configurable par step dans scenario.json |
| Session ID non preserve entre steps | Deja prouve dans poc_07 que ca marche |
| Le prompt de delegation est trop vague | Enrichir le content avec des instructions explicites |
