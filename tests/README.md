# kiss-claw Test Framework

End-to-end tests that invoke the real Claude CLI and verify behavior.

## Prerequisites

- Python 3.8+
- `claude` CLI installed and authenticated (OAuth login)
- Docker (optional, for containerized runs)

## Local setup

```bash
./tests/setup-venv.sh
source tests/.venv/bin/activate
```

No pip dependencies -- stdlib only.

## Running tests locally

From the project root:

```bash
python tests/lib/runner.py
# or
python -m tests.lib.runner
```

The runner discovers all `test_*.py` files in `tests/scenarios/`, calls each
`run(ctx)` function, and reports pass/fail/error with timing.

## Running tests in Docker

```bash
./tests/docker/build-and-test.sh [commit_sha]
```

For remote clone via SSH agent forwarding:

```bash
GIT_REMOTE_URL=git@github.com:user/kiss-claw.git \
  ./tests/docker/build-and-test.sh --ssh [commit_sha]
```

Requires `SSH_AUTH_SOCK` (ssh-agent running) and `GIT_REMOTE_URL` set.

## Writing a new test scenario

1. Create `tests/scenarios/test_<name>.py`
2. Implement a `run(ctx)` function:

```python
import os, sys

_project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if _project_root not in sys.path:
    sys.path.insert(0, _project_root)

from tests.lib.claude_cli import invoke
from tests.lib.assertions import assert_exit_code, assert_stdout_contains

def run(ctx):
    """ctx has keys: scenario_dir, workspace"""
    result = invoke("your prompt here", model="haiku", max_turns=1)
    assert_exit_code(result, 0)
    assert_stdout_contains(result, r"expected pattern")
```

- `ctx["scenario_dir"]` -- absolute path to `tests/scenarios/`
- `ctx["workspace"]` -- absolute path to the project root
- Raise `AssertionError` to signal failure

## Framework modules

| Module | Purpose |
|--------|---------|
| `tests/lib/runner.py` | Discovers `test_*.py` scenarios, runs `run(ctx)`, reports results |
| `tests/lib/assertions.py` | Assertion helpers: `assert_exit_code`, `assert_file_exists`, `assert_file_contains`, `assert_stdout_contains`, `assert_json_field` |
| `tests/lib/claude_cli.py` | Wraps `claude -p` subprocess calls, returns `ClaudeResult` with stdout/stderr/exit_code/json |

## Cost note

Each test invocation calls the Claude API. Typical cost per invocation: ~$0.05-0.15
(haiku model, effort low). Keep scenarios minimal to control spend.
