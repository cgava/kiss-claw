# Etat de l'art : Test interactif d'agents conversationnels LLM

> Session kiss-claw `20260415-113650` — Phase 1 Recherche
> Date : 2026-04-15
> Contexte : les scenarios de test kiss-claw (ex: `02-konvert-agents`) echouent car l'orchestrateur
> pose 3 questions INIT interactives mais `claude -p` est non-interactif.

---

## Table des matieres

1. [Problematique](#1-problematique)
2. [Vocabulaire et taxonomie](#2-vocabulaire-et-taxonomie)
3. [Formats de description de scenarios](#3-formats-de-description-de-scenarios)
4. [Outils et frameworks existants](#4-outils-et-frameworks-existants)
5. [Approches de creation de scenarios](#5-approches-de-creation-de-scenarios)
6. [Gestion du non-determinisme](#6-gestion-du-non-determinisme)
7. [Etat du framework kiss-claw actuel](#7-etat-du-framework-kiss-claw-actuel)
8. [Recommandations](#8-recommandations)
9. [References](#9-references)

---

## 1. Problematique

Le scenario `02-konvert-agents` illustre un probleme structurel :

```
claude -p "prompt contenant tout le contexte"
  → orchestrator demarre
  → pose la question INIT 1/3
  → attend une reponse humaine
  → end_turn apres 15 turns sans reponse
  → pas de PLAN.md, pas de delegation
```

Le mode `claude -p` (non-interactif) envoie un prompt unique et attend une reponse complete.
L'orchestrateur, lui, est concu pour un echange multi-tours avec un humain. Ces deux modeles
sont incompatibles sans un mecanisme d'injection de reponses entre les tours.

**Objectif** : concevoir un framework de test capable de simuler un humain interagissant
avec un agent multi-tours, en utilisant le CLI Claude comme seul point d'entree.

---

## 2. Vocabulaire et taxonomie

### 2.1 Terminologie retenue

Le domaine n'utilise pas "conversation testing" ou "dialog testing" — ces termes viennent
de l'ere chatbot (flux scriptes, intent matching). Pour les agents LLM autonomes :

| Terme | Definition | Source |
|-------|-----------|--------|
| **Agent evaluation / agent evals** | Terme dominant pour l'evaluation d'agents LLM | Anthropic, LangChain, AWS Strands |
| **Trajectory evaluation** | Evaluation de la sequence complete (steps, tool calls, reasoning) | LangSmith/LangChain (standard de facto) |
| **Scenario-based evaluation** | Scenario nomme = contexte initial + trajectory attendue + criteres de succes | General |
| **Behavioral testing** | Test black-box des actions/decisions observables de l'agent | General |
| **Simulation-based testing** | Utilisateur simule ou environnement simule pour driver l'agent | General |
| **Elicitation testing** | Verification que l'agent sollicite, parse et agit sur les clarifications utilisateur | Specifique a notre cas |
| **Simulated user turns** | Injection de reponses scriptees comme si elles venaient d'un humain | LangSmith, DeepEval |

### 2.2 Niveaux de test

Analogie directe avec le test logiciel classique, codifiee par la communaute agent :

| Niveau | Signification agent | Exemple kiss-claw |
|--------|--------------------|--------------------|
| **Component (unit)** | Un prompt, un tool call, un retrieval isole | Test unitaire de `store.sh checkpoint upsert` |
| **Integration** | Flux de donnees entre composants, transitions d'etat sur quelques tours | INIT → PLAN genere (orchestrateur seul) |
| **End-to-end (E2E)** | Session complete du premier tour a la completion de tache | orchestrator → executor → verificator |

Source : Anthropic "Demystifying Evals for AI Agents" ajoute un axe **type de grader** :
- **Code-based** : exact match, regex, assertions structurelles
- **Model-based** : LLM-as-judge
- **Human graders** : review manuelle

LangSmith "Multi-turn Evals" (2024) decompose en 3 sous-dimensions :
- *Semantic intent* : ce que l'utilisateur voulait
- *Semantic outcome* : si l'objectif est atteint
- *Agent trajectory* : comment l'agent y est arrive (sequence d'outils)

### 2.3 Taxonomie des scenarios

Classification standard utilisee dans les benchmarks et suites d'evaluation :

| Type | Description | Pertinence kiss-claw |
|------|-------------|---------------------|
| **Happy path** | Inputs canoniques, usage d'outils attendu, completion bien formee | Priorite 1 — faire marcher le cas nominal |
| **Edge case** | Inputs limites, reponses vides, intent ambigu | Phase 2 — apres le happy path |
| **Adversarial** | Prompt injection, violation de contraintes, contournement de policy | Faible priorite pour kiss-claw |
| **Regression** | Comportements precedemment casses, epingles comme tests de non-regression | Automatique apres chaque fix |
| **Robustness** | Inputs paraphrases, contexte reordonne, echecs d'outils aleatoires | Nice to have |
| **Long-horizon / multi-session** | Taches necessitant une persistance d'etat sur de nombreux tours | Le cas `02-konvert-agents` |

---

## 3. Formats de description de scenarios

### 3.1 Comparaison des approches

#### 3.1.1 Sequentiel (AC-list)

Ce que kiss-claw utilise actuellement : une liste ordonnee de criteres d'acceptation
verifies apres une invocation unique de l'agent.

```python
# Extrait de test_konvert_agents.py
assert_file_exists(workspace, ".kiss-claw/sessions/*/STATE.md")
assert_file_contains(workspace, ".kiss-claw/sessions/*/PLAN.md", r"(?i)(phase|etape)")
```

- **Authoring** : Low — lister ce qu'on attend
- **Non-determinisme** : Low — regex seulement, pas de sens semantique
- **Extensibilite** : Poor — branching = `if/else` dans Python, pas dans le format
- **Outils** : xUnit, pytest, kiss-claw runner

#### 3.1.2 DAG / Graph-based

Noeuds = etats, aretes = transitions avec conditions. L'agent peut etre re-entre
depuis n'importe quel noeud correspondant.

- **Authoring** : High — modeliser tous les etats atteignables en amont
- **Non-determinisme** : Good — plusieurs noeuds successeurs valides, fuzzy matching aux aretes
- **Extensibilite** : Excellent — chemins paralleles, joins, cycles
- **Outils** : LangGraph eval, Promptflow (Microsoft), ELEET

#### 3.1.3 FSM (Finite State Machine)

Etats + transitions explicites + guards (conditions booleennes sur la sortie agent).

- **Authoring** : High — formaliser toutes les guards
- **Non-determinisme** : Moderate — guards peuvent inclure LLM-as-judge, mais espace d'etats enumere
- **Extensibilite** : Good pour agents deterministes, fragile quand l'agent saute des etats
- **Outils** : AgentBench, moteurs FSM custom

#### 3.1.4 BDD / Gherkin adapte

Given/When/Then etendu avec "And the agent responds with" et matchers semantiques.

- **Authoring** : Low-Medium — prose lisible, familier aux non-ingenieurs
- **Non-determinisme** : Moderate — matchers au niveau phrase, souvent regex ou embedding similarity
- **Extensibilite** : Poor pour multi-agent — Gherkin n'a pas de modele de concurrence natif
- **Outils** : Behave, Cucumber avec step definitions custom, AgentEval

#### 3.1.5 Decision tree (arbre de decision)

Racine = prompt initial, branches = reponses possibles de l'agent, feuilles = verdict pass/fail.
Mappe naturellement sur du Q&A multi-tours.

- **Authoring** : Medium — l'arbre est facile a visualiser mais large pour des workflows profonds
- **Non-determinisme** : Good — alternatives de branches (OR-branches a chaque noeud)
- **Extensibilite** : Good pour agents dialogiques, poor pour agents avec side-effects d'outils
- **Outils** : Format interne Anthropic (YAML trees), OpenAI Evals

#### 3.1.6 Record-and-replay

Capturer un transcript de session reelle (`.jsonl`), rejouer avec matching requete/reponse.

- **Authoring** : Zero — juste enregistrer un run qui passe
- **Non-determinisme** : Very poor — exact-match echoue sur toute derive du modele
- **Extensibilite** : Poor — transcripts captures sont des snapshots figes
- **Outils** : VCR.py adapte aux flux LLM, `sync-sessions.sh` + `CHECKPOINT.yaml` (partiel)

### 3.2 Tableau comparatif

| Approche | Authoring | Non-determinisme | Extensibilite | Outils existants |
|----------|-----------|-----------------|---------------|-----------------|
| Sequentiel (AC-list) | :green_circle: Low | :red_circle: Low | :red_circle: Poor | pytest, kiss-claw runner |
| DAG/Graph | :red_circle: High | :green_circle: High | :green_circle: Excellent | LangGraph, Promptflow |
| FSM | :red_circle: High | :yellow_circle: Moderate | :yellow_circle: Good | AgentBench |
| BDD/Gherkin | :yellow_circle: Medium | :yellow_circle: Moderate | :red_circle: Poor | Behave, Cucumber |
| **Decision tree** | :yellow_circle: Medium | :green_circle: Good | :yellow_circle: Good | OpenAI Evals, Anthropic YAML |
| Record-replay | :green_circle: Zero | :red_circle: Very poor | :red_circle: Poor | VCR, sync-sessions |

### 3.3 Analyse pour kiss-claw

Le format actuel (AC-list sequentiel) est le bon point de depart. Deux lacunes a combler :

1. **Branching** : le format n'a aucun moyen d'exprimer "si l'agent a choisi l'approche A,
   asserter X ; si approche B, asserter Y". Une couche legere de **decision tree** en YAML
   (champ `condition` par entree AC) couvrirait 80% des cas sans la complexite FSM.

2. **Multi-tour** : le format actuel suppose un seul appel agent. Il faut un mecanisme
   de **turns** sequentiels avec assertions intermediaires.

---

## 4. Outils et frameworks existants

### 4.1 Capacites du CLI Claude Code

Le CLI installe dispose de mecanismes directement pertinents :

| Flag | Fonction | Pertinence |
|------|----------|-----------|
| `--resume <session_id>` | Reprend une session par ID | **Cle** — permet le multi-tour via subprocess enchaines |
| `--continue` (`-c`) | Reprend la conversation la plus recente du repertoire | Fragile en parallele (scope repertoire) |
| `--input-format stream-json` | Flux JSON sur stdin en temps reel | **Puissant** — multi-tour en un seul process |
| `--output-format stream-json` | Flux JSON sur stdout | Complementaire de `--input-format` |
| `--max-turns N` | Plafonne les boucles agentic tool loops | Utile pour prevenir les agents en boucle |
| `--debug [filter]` / `--debug-file <path>` | Logs de debug structures | Observation du comportement agent pendant les tests |
| `--no-session-persistence` | Desactive la sauvegarde de session | Economie I/O pour tests unitaires |
| `--dangerously-skip-permissions` | Saute les confirmations de permission | Requis pour tests non-interactifs |

**Decouverte cle** : `--resume` + `--input-format stream-json` sont les deux primitives
qui resolvent nativement le probleme multi-tour, sans bibliotheque externe.

**Preuve** : `poc_07_session_continuation.py` (deja dans le repo) demontre que le pattern
`--resume` fonctionne :

```python
# Tour 1 : nouvelle session
r1 = invoke("start task", output_format="json", ...)
session_id = r1.json["session_id"]

# Tour 2 : reprend la meme session
r2 = invoke("follow-up", resume_session=session_id, ...)
# r2 maintient le contexte conversationnel de r1
```

### 4.2 Frameworks de test d'agents (2024-2026)

| Framework | Multi-tour | CLI subprocess | Licence | Maturite | Verdict |
|-----------|-----------|---------------|---------|----------|---------|
| **Inspect AI** (UK AISI) | Oui via `TaskState` | Non (SDK-first) | MIT | Haute | Non adaptable sans wrapper |
| **promptfoo** | Oui (`conversationHistory`) | Partiel (`exec` provider) | Apache 2.0 | Haute | Le plus proche mais Node.js |
| **deepeval** | Oui (`ConversationalTestCase`) | Non (SDK) | Apache 2.0 | Medium-Haute | Non adaptable |
| **AgentBench** | Oui (boucles env-step) | Non (API directe) | MIT | Recherche | Non adaptable |
| **LATS / AgentEval** | Metriques seulement | Non | Recherche | Basse | Hors scope |
| **ragas** | RAG-specifique | Non | Apache 2.0 | Medium | Hors scope |

**Constat** : aucun framework existant ne wrappe nativement un subprocess CLI avec support
multi-tour. Tous supposent un acces SDK ou HTTP au modele. Les adapter necessiterait
de wrapper le CLI comme "model provider" custom.

**promptfoo** est le plus proche : son type de provider `exec` execute une commande shell
et capture la sortie, et le threading `conversationHistory` est natif. Mais il utilise
Node.js et ajoute une dependance lourde.

### 4.3 Outils de test conversationnel (generation pre-LLM)

| Outil | Statut | Verdict |
|-------|--------|---------|
| **Botium** | Archive/commercial | Concu pour intent-matching, pas LLM | 
| **Chatbottest** | Abandonne | Intent-based, pas adaptable |
| **conversation-test** (npm) | YAML turn-by-turn | Leger mais Node.js, pattern-matching only |

Ces outils precedent l'ere LLM agent et portent des hypotheses chatbot (slots d'intent,
extraction d'entites) incompatibles avec les sorties prose non-deterministes.

### 4.4 Patterns DIY (LangChain / CrewAI / AutoGen)

Trois patterns dominent les discussions communautaires (2024-2025) :

**State-file handoff** — Chaque tour agent ecrit l'etat dans un fichier partage ; le harness
de test lit le fichier, asserte sur la structure, puis injecte le tour suivant. C'est
exactement ce que kiss-claw fait deja avec PLAN.md / STATE.md.

**Mock agent substitution** — Remplacer le subprocess agent reel par un mock qui retourne
des reponses pre-enregistrees. Isole la logique de routing de l'orchestrateur du
non-determinisme LLM.

**Checkpoint replay** — Enregistrer un transcript de session reelle (CHECKPOINT.yaml / `.jsonl`),
puis rejouer les tours de maniere deterministe. Le flag `--resume` le permet : capturer
une session orchestrateur reelle une fois, sauver le session_id, ecrire des tours de test
qui reprennent depuis cet etat connu.

### 4.5 Approches Python

| Approche | Description | Dependance | Verdict |
|----------|-------------|-----------|---------|
| `subprocess.Popen` + `--input-format stream-json` | Un seul Popen, stdin/stdout JSON streaming | stdlib | **Recommande** — zero dep, flag officiel |
| `subprocess.run` + `--resume` | Un subprocess par tour, session_id chain | stdlib | **Recommande** — deja prouve dans poc_07 |
| `pty` module | Pseudo-terminal, l'agent croit avoir un TTY | stdlib | Fragile, edge cases encoding |
| `pexpect` | Wrapper pty avec pattern-match `expect()` | pip | Simplifie wait-for/respond mais ajoute dep |
| `tmux` scripting | `tmux send-keys` dans un pane | systeme | Dep externe, difficile a rendre deterministe en CI |

---

## 5. Approches de creation de scenarios

### 5.1 Comparaison

#### 5.1.1 Authoring manuel

L'humain ecrit le scenario complet a la main (JSON/YAML).

- **Effort** : Eleve. Chaque scenario necessite de connaitre les tours attendus exactement.
- **Maintenance** : Fragile. Tout changement de prompt ou comportement necessite re-edition manuelle.
- **Couverture** : Basse sauf si fait systematiquement. Les humains se concentrent sur le happy path.
- **Outillage** : Aucun requis au-dela d'un editeur texte.
- **Verdict** : Utile pour les smoke tests et la couverture du chemin critique. Ne scale pas au-dela de ~10 scenarios.

#### 5.1.2 Record-and-replay

L'humain joue le scenario une fois, les interactions sont enregistrees, puis rejouees.

- **Effort** : Faible a creer, mais l'infra d'enregistrement est non-triviale a construire.
- **Maintenance** : Tres fragile. Les sorties LLM sont non-deterministes — le replay exact echoue
  sauf si on fixe le modele, temperature et seed (ce qui defait l'objet du test).
- **Couverture** : Couvre les chemins reels mais manque les flux non-testes.
- **Outillage** : Necessite un proxy d'enregistrement ou une couche de capture de session.
- **Verdict** : Ne fonctionne que si on remplace les assertions exact-match par des assertions semantiques.

#### 5.1.3 Semi-automatise (Human-in-the-loop)

Le runner fait le travail ; l'humain comble les trous progressivement. L'agent tourne,
quand il se bloque en attendant un input, l'humain fournit la reponse qui est sauvee
dans le scenario pour la prochaine execution.

- **Effort** : Medium. Construction progressive et organique.
- **Maintenance** : Medium. Les scenarios s'enrichissent au fil des interactions reelles.
- **Couverture** : Bonne. Les scenarios refletent les vrais modes d'echec rencontres.
- **Outillage** : Necessite un runner qui peut pauser, prompter, et serialiser le resultat.
- **Verdict** : **Meilleure approche pratique pour les projets en phase initiale.** L'architecture
  runner existante de kiss-claw est bien adaptee a ce pattern.

#### 5.1.4 Generation IA complete

Un LLM genere les scenarios a partir des instructions de l'agent.

- **Effort** : Tres faible pour generer un squelette. Eleve pour valider la qualite.
- **Maintenance** : Facile a regenerer, mais les scenarios generes manquent souvent les edge cases.
- **Couverture** : Large mais superficielle. L'IA genere des chemins optimistes.
- **Outillage** : Un appel LLM + une etape de validation.
- **Verdict** : Utile pour generer des squelettes en masse que l'humain trie et raffine.

#### 5.1.5 Hybride (squelette IA + raffinement humain)

L'IA genere la structure ; l'humain corrige les assertions et ajoute les edge cases.

- **Effort** : Low-Medium.
- **Maintenance** : L'IA regenere les squelettes sur changement ; l'humain ne review que les diffs.
- **Couverture** : Best of both — largeur de l'IA, profondeur de l'humain.
- **Outillage** : Idem generation IA + workflow diff/review.
- **Verdict** : **Approche production-grade.** Les equipes Anthropic, OpenAI et LangChain convergent
  vers ce pattern.

### 5.2 Tableau comparatif

| Approche | Effort creation | Maintenance | Couverture | Outillage requis |
|----------|----------------|-------------|-----------|-----------------|
| Manuel | Eleve | Fragile | Basse | Aucun |
| Record-replay | Faible | Tres fragile | Reelle | Proxy enregistrement |
| **Human-in-the-loop** | Medium | Medium | Bonne | Runner interactif |
| Generation IA | Tres faible | Facile | Superficielle | LLM + validation |
| **Hybride** | Low-Medium | Medium | Best of both | LLM + diff/review |

### 5.3 Maintenance des scenarios quand l'agent evolue

Trois patterns qui fonctionnent en production :

1. **Assertions semantiques plutot que golden files** — Asserter qu'un fichier existe et a un header
   matchant `r"(?i)phase"`, pas qu'il matche une phrase specifique. `assertions.py` de kiss-claw
   suit deja ce modele — l'etendre plutot qu'ajouter des comparaisons de strings.

2. **Snapshot testing avec gates d'approbation humaine** — Sur changement de comportement, le runner
   flag les scenarios divergents comme "needs review" plutot que de les faire echouer automatiquement.
   Pattern Playwright / Jest qui se transfere directement au test d'agents.

3. **Jeux de scenarios versionnes par revision prompt** — Tagger les scenarios avec la version agent
   contre laquelle ils ont ete ecrits. Sur changement de prompt significatif, retirer l'ancien jeu
   et generer une nouvelle baseline plutot que patcher chaque scenario.

---

## 6. Gestion du non-determinisme

Le defi central du test d'agents LLM : les sorties ne sont jamais identiques d'un run a l'autre.

### 6.1 Strategies par ordre de complexite

| # | Strategie | Cout | Fiabilite | Quand l'utiliser |
|---|-----------|------|-----------|-----------------|
| 1 | **Assertions structurelles** | Zero | Haute | Toujours — fichier existe, exit code, header YAML |
| 2 | **Regex + ancres semantiques** | Zero | Medium-Haute | Vocabulaire requis (`artifacts:`, `decisions:`, `Phase`) |
| 3 | **LLM-as-judge** | $$ (appel LLM) | Haute | Assertions sur le raisonnement agent (texte libre) |
| 4 | **Embedding similarity** | $ (embedding) | Medium | Pre-filtre avant LLM-as-judge |

### 6.2 Recommandation pour kiss-claw

Rester sur les strategies 1 + 2 (deja en place dans `assertions.py`).
Ajouter LLM-as-judge uniquement pour les assertions sur du texte de raisonnement agent,
pas sur la structure de fichiers.

L'agent produit des **artefacts structures** (PLAN.md, STATE.md, CHECKPOINT.yaml) —
c'est sur ces artefacts qu'il faut asserter, pas sur le texte conversationnel.

---

## 7. Etat du framework kiss-claw actuel

### 7.1 Architecture

```
tests/
  lib/
    runner.py        — Decouverte recursive + execution des scenarios
    claude_cli.py    — Wrapper subprocess Claude CLI (re-export my-claude-minion)
    assertions.py    — Helpers assert (exit code, JSON, fichiers)
    report.py        — Generateur rapport Markdown
  scenarios/
    01-hello-world/  — Smoke test (single-turn, fonctionne)
    02-konvert-agents/ — Integration multi-tour (ECHOUE en mode reel)
    03-enrich-checkpoint/ — Test unitaire enrich (fonctionne)
```

### 7.2 Contrat `run(ctx)`

Chaque scenario expose une fonction `run(ctx)` avec :
- `ctx["scenario_dir"]` : chemin absolu du repertoire du scenario
- `ctx["workspace"]` : chemin absolu de la racine projet
- `ctx["dry_run"]` : boolean

Le runner attrape `AssertionError` → fail, autre exception → error, rien → pass.

### 7.3 Wrapper Claude CLI (`invoke()`)

```python
invoke(
    prompt,
    output_format=None,       # --output-format json
    max_turns=None,            # --max-turns N
    model=None,                # --model haiku|sonnet|opus
    effort=None,               # --effort low|medium|high
    timeout=60,                # subprocess timeout (seconds)
    resume_session=None,       # --resume <session_id>  ← DEJA SUPPORTE
    extra_flags=None,          # flags bruts (ex: --plugin-dir)
    cwd=None,                  # working directory
    dry_run=False,             # skip execution entirely
)
```

- Default flags : `--no-session-persistence`, `--dangerously-skip-permissions`, `--effort low`
- `--no-session-persistence` est desactive quand `resume_session` est set
- Dry-run retourne `{"result": "[dry-run]", "is_error": False, "session_id": "dry-run-000"}`
- `ClaudeResult` : `.stdout`, `.stderr`, `.exit_code`, `.json`, `.session_id`

### 7.4 Ce qui manque

1. **Multi-tour** : le runner execute chaque scenario une seule fois. Pas de boucle interactive.
2. **Format scenario structure** : pas de fichier YAML/JSON decrivant les tours attendus.
3. **Debug output** : pas de `--debug-file` par defaut dans les invocations de test.
4. **Assertions intermediaires** : on asserte seulement a la fin, pas entre les tours.

### 7.5 Ce qui existe deja et est reutilisable

- `invoke(resume_session=...)` fonctionne (prouve par `poc_07`)
- `ClaudeResult.session_id` permet de chainer les tours
- `assertions.py` a deja `assert_file_exists`, `assert_file_contains` (regex)
- Le runner supporte la decouverte recursive et le `--dry-run`

---

## 8. Recommandations

### 8.1 Format de scenario

**Choix** : sequentiel (AC-list) + couche legere decision tree en YAML.

Commencer simple (liste ordonnee de tours), avec possibilite d'ajouter des conditions
par entree pour gerer les branchements sans complexite FSM/DAG.

Structure proposee (a affiner en Phase 2 Design) :

```yaml
scenario: "02-konvert-agents"
description: "Integration test: orchestrator INIT → plan → executor delegation"
agent: "kiss-orchestrator"
max_turns_per_step: 30
timeout_per_step: 120

steps:
  - id: "init-start"
    action:
      type: "prompt"
      content: "Launch orchestrator with konvert project context"
    expect:
      - type: "output_contains"
        pattern: "(?i)(what are you building|question 1)"
    on_success: "init-answer-1"

  - id: "init-answer-1"
    action:
      type: "resume"
      content: "Building a YAML-to-JSON converter CLI tool"
    expect:
      - type: "output_contains"
        pattern: "(?i)(phase|milestone|question 2)"
    on_success: "init-answer-2"

  - id: "init-answer-2"
    action:
      type: "resume"
      content: "Phase 1: parser, Phase 2: CLI, Phase 3: tests"
    expect:
      - type: "output_contains"
        pattern: "(?i)(constraint|non.?goal|question 3)"
    on_success: "init-answer-3"

  - id: "init-answer-3"
    action:
      type: "resume"
      content: "No external dependencies, Python stdlib only"
    expect:
      - type: "file_exists"
        path: ".kiss-claw/sessions/*/PLAN.md"
      - type: "file_contains"
        path: ".kiss-claw/sessions/*/STATE.md"
        pattern: "(?i)phase"
    on_success: "done"
```

### 8.2 Approche technique

**Choix primaire** : `--resume` chaining via `invoke(resume_session=...)`.

```
turn1 = invoke("start", output_format="json") → session_id + question 1
turn2 = invoke("answer 1", resume_session=id)  → question 2
turn3 = invoke("answer 2", resume_session=id)  → question 3
turn4 = invoke("answer 3", resume_session=id)  → agent proceeds
assert sur STATE.md / PLAN.md
```

- Zero dependance externe
- Deja prouve dans `poc_07_session_continuation.py`
- Chaque tour = subprocess independant, facile a debugger

**Choix secondaire** (si latence critique) : `--input-format stream-json` en single process.

### 8.3 Assertions

Rester sur assertions structurelles + regex (`assertions.py` existant).
Pas de LLM-as-judge pour la v1.

### 8.4 Creation de scenarios

1. **Human-in-the-loop** pour les 5-10 premiers scenarios reels
2. **Assertions semantiques** (proprietes, pas strings) dans `assertions.py`
3. **Generation IA** pour les squelettes edge cases, humain valide avant commit
4. **Retirement** des scenarios sur changement majeur de version agent

### 8.5 Debug output

Ajouter `--debug-file <path>` par defaut dans les invocations de test pour observer
le comportement agent sans polluer stdout.

---

## 9. References

### Publications academiques

- **AgentBench**: Evaluating LLMs as Agents (Liu et al., ICLR 2024) — arxiv:2308.03688
  Premier benchmark multi-environnement ; classifie les scenarios en code-grounded, game-grounded, web-grounded.

- **Evaluating LLM-based Agents for Multi-Turn Conversations: A Survey** (arxiv:2503.22458, Mars 2025)
  Couvre directement l'evaluation turn-level vs task-level.

- **KDD 2025 Tutorial: Evaluation & Benchmarking of LLM Agents** (Mohammadi et al., arxiv:2507.21504)
  Taxonomie comprehensive : objectif d'evaluation x processus d'evaluation.

- **INJECAGENT: Benchmarking Indirect Prompt Injections** (ACL Findings 2024)
  Benchmark de tests adversariaux d'agents.

- **Challenges in Testing Large Language Model Based Software: A Faceted Taxonomy** (arxiv:2503.00481)
  Taxonomie a facettes des defis de test LLM.

### Documentation industrie

- **Anthropic** — "Demystifying Evals for AI Agents" (blog engineering, 2024)
  Taxonomie pratique des graders : code-based, model-based, human.

- **LangSmith** — "How to evaluate your agent with trajectory evaluations"
  Standard de facto pour l'evaluation de trajectoire agent.

- **LangSmith** — "Improve agent quality with Multi-turn Evals" (blog, 2024)
  Multi-turn evals avec logique conditionnelle.

- **DeepEval** — "AI Agent Evaluation Metrics" (Confident AI)
  Framework open-source avec metriques de trajectoire agent.

### Outils

- **Inspect AI** (UK AISI) — MIT — framework d'evaluation d'agents avec TaskState
- **promptfoo** — Apache 2.0 — evaluation multi-tour avec provider exec
- **deepeval** — Apache 2.0 — ConversationalTestCase
- **AgentBench** — MIT — benchmark de recherche
- **pexpect** — ISC — pseudo-terminal interaction pour Python (pip)
