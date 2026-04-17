# kiss-claw Test Framework

## Test strategy

Tests are organized in three levels:

| Level | LLM required | Model | Cost | Purpose |
|-------|-------------|-------|------|---------|
| Unit | No | -- | $0.00 | Pure Python tests against internal scripts |
| Smoke | Yes | haiku | ~$0.10 | Cheap validation of the prompt-to-response pipeline |
| Integration | Yes | sonnet | ~$0.20-0.50 | Full agent loop with plugin, multi-turn, artifacts |

All tests are written in Python stdlib only (no pip dependencies). LLM-based tests
invoke `claude -p` via subprocess, wrapped by `tests/lib/claude_cli.py` (sourced from
`vendor/my-claude-minion`). Docker is optional for environment isolation.

## Prerequisites

- Python 3.8+
- `claude` CLI installed and authenticated (OAuth login)
- Docker (optional, for containerized runs)

## Scenarios

### 01-hello-world -- Smoke test (interactive 2-step with --resume)

**Type:** smoke test | **Model:** haiku | **Cost:** ~$0.10

Tests the interactive pipeline: prompt, language detection, resume, response.

- **Step 1:** Asks Claude to pick a language (FR/EN/ES/DE) and greet the user with
  "how are you?" in that language.
- **Step 2:** The test code detects the language from Step 1 output, then responds in
  the same language via `--resume` using the session ID from Step 1.

Acceptance criteria verified:
- Exit codes are 0 for both steps
- Outputs are non-empty
- Session ID is a valid non-empty string
- Language is detected as one of fr/en/es/de

No `scenario.json` -- steps are dynamically constructed in Python
(`test_hello_world.py`).

### 02-konvert-agents -- Integration test (multi-turn with plugin)

**Type:** integration | **Model:** sonnet | **Cost:** ~$0.20-0.50

Tests the full agent workflow: orchestrator, executor, verificator working together
to produce artifacts in an isolated workspace.

- **5 steps** defined in `scenario.json`:
  1. `start` -- Launch orchestrator with the konvert project directive
  2. `init-q1-answer` -- Answer first INIT question (resume)
  3. `init-q2-answer` -- Answer second INIT question about phases (resume)
  4. `init-q3-answer` -- Answer third INIT question about constraints (resume)
  5. `delegation` -- Let the agent work through delegation (long-running, up to 5min timeout)

- **Workspace:** isolated tempdir, preserved after run for inspection
- **Plugin:** kiss-claw loaded via `--plugin-dir`

Acceptance criteria verified:
- `konvert.sh` exists and is executable
- `test_konvert.sh` exists and is executable
- `PLAN.md` created in session directory, contains phase information
- `STATE.md` created in session directory
- `REVIEWS.md` and `CHECKPOINT.yaml` (optional, non-blocking)

Uses `scenario_runner.py` for sequential step execution with `--resume` chaining.

### 03-enrich-checkpoint -- Unit tests (no LLM)

**Type:** unit test | **Model:** none | **Cost:** $0.00

Tests `scripts/enrich_checkpoint.py`, which enriches CHECKPOINT.yaml files by
extracting content from Claude session transcripts (.jsonl) and classifying blocks
into artifacts, decisions, issues, and rationale.

8 sub-tests using fixtures from `tests/fixtures/enrich-checkpoint/`:

| Test | What it verifies |
|------|-----------------|
| `test_parse_jsonl` | Extracts assistant text blocks, excludes thinking/tool_use/user, filters blocks < 100 chars |
| `test_classify_blocks` | Classifies blocks: tables to artifacts, decision keywords to decisions, caveats to issues |
| `test_enrich_step` | Given short task/result + blocks, enriches step with artifacts/decisions/issues |
| `test_no_overwrite` | Steps with long (>200 chars) task/result are NOT overwritten |
| `test_dry_run` | `--dry-run` flag prints output but does not modify CHECKPOINT file |
| `test_batch_mode` | All steps processed when no `--step` flag |
| `test_step_mode` | Only the specified step processed with `--step` flag |
| `test_missing_transcript` | Graceful handling (warning, no crash) when .jsonl not found |

No LLM calls, no `claude` subprocess. Uses `subprocess` only to invoke
`enrich_checkpoint.py` itself for CLI-level tests.

## Framework modules

| Module | Role |
|--------|------|
| `tests/lib/runner.py` | Recursive discovery of `test_*.py` files, execution of `run(ctx)`, pass/fail reporting |
| `tests/lib/claude_cli.py` | Wrapper around `claude -p` subprocess (from `vendor/my-claude-minion`) |
| `tests/lib/scenario_runner.py` | Interactive multi-turn runner with `--resume` chaining, driven by `scenario.json` |
| `tests/lib/assertions.py` | Assertion helpers: exit code, file exists, file contains, file executable, glob, stdout matches |
| `tests/lib/report.py` | Markdown test report generator |

## Running tests

```bash
# Run all scenarios
python tests/lib/runner.py

# Dry-run: validate imports, paths, and command construction without calling the LLM
python tests/lib/runner.py --dry-run

# Run in Docker (isolated environment)
./tests/docker/build-and-test.sh
```

## Cost note

Each LLM invocation costs approximately $0.05 (haiku) to $0.20 (sonnet).
The `--dry-run` flag validates structure and imports at zero cost. Unit test
scenarios (03-enrich-checkpoint) never call the LLM and are always free.
