# Design: Docker Isolation for SUT Agents

**Date**: 2025-04-19
**Status**: Draft
**Context**: kiss-claw test framework needs to run agents-under-test (SUT) inside a clean Docker container to guarantee zero pollution from host plugins, hooks, MCP servers, CLAUDE.md files, or settings.

---

## 1. Architecture

```
HOST                                       DOCKER CONTAINER
+-------------------------------+          +----------------------------------+
|  test runner (pytest)         |          |  my-claude-minion image          |
|  scenario_runner.py           |          |  (debian-slim + claude CLI)      |
|  assertions, reports          |          |                                  |
|                               |          |  /workspace  (project, ro)       |
|  invoke(prompt, isolation=    |  docker  |  /root/.claude/  (OAuth, ro)     |
|    "docker") ----+            |   run    |  /kiss-claw/  (plugin, ro)       |
|                  |            |--------->|                                  |
|                  v            |  stdout  |  claude -p "prompt" ...          |
|  docker_invoke() builds      |<---------|  (no ~/.claude/settings.json)    |
|  `docker run` command,       |          |  (no CLAUDE.md)                  |
|  captures stdout/stderr      |          |  (no MCP, no hooks)              |
+-------------------------------+          +----------------------------------+
```

**Flow**:
1. Test runner calls `invoke(prompt, ..., isolation="docker")`
2. `invoke()` detects `isolation="docker"` and delegates to `docker_invoke()`
3. `docker_invoke()` builds a `docker run` command with mounts and env
4. Container starts, entrypoint activates venv, runs `claude -p "prompt" ...`
5. Container exits, stdout/stderr captured, parsed into `ClaudeResult`
6. Assertions run on host against the result + workspace artifacts

---

## 2. Docker Image Audit (my-claude-minion)

### What is installed
| Layer | Contents |
|-------|----------|
| Base | `debian:stable-slim` |
| System packages | bash, git, curl, jq, ca-certificates, npm, openssh-client, python3, python3-venv |
| Claude CLI | `@anthropic-ai/claude-code` (npm global) |
| Python venv | `/opt/venv` (stdlib only, no pip packages) |

### What is mounted (documented, not baked in)
| Mount | Target | Mode |
|-------|--------|------|
| Host project dir | `/workspace` | `ro` |
| `~/.claude` | `/root/.claude` | `ro` |
| `$SSH_AUTH_SOCK` | `/ssh-agent` | optional |

### What is excluded
- No `settings.json` baked in (but `~/.claude` mount would include it -- see Mount Strategy below)
- No CLAUDE.md
- No MCP servers
- No oh-my-claudecode hooks or plugins
- No pip packages

### OAuth handling
- OAuth tokens are expected at `/root/.claude` via bind mount from host `~/.claude`
- Entrypoint checks for the mount and warns if absent
- No token refresh mechanism inside container (read-only mount)

### Entrypoint behavior
1. Activates `/opt/venv`
2. Prints environment info (Python version, Claude version, workdir)
3. Validates OAuth mount presence
4. `exec "$@"` if command provided, else exits after validation

---

## 3. Scenario Runner & CLI Audit

### invoke() (cli.py)
- Builds a `claude -p` subprocess command with flags
- Default flags: `--no-session-persistence`, `--dangerously-skip-permissions`, `--effort low`
- Session resume: uses `--resume <session_id>`, drops `--no-session-persistence`
- Subprocess execution via `subprocess.run(capture_output=True, text=True, timeout=...)`
- Returns `ClaudeResult(stdout, stderr, exit_code, json, session_id)`

### scenario_runner.py
- Loads scenario.json, iterates steps (prompt/resume/wait)
- Calls `invoke()` for each prompt/resume step
- Chains sessions via `--resume` when scenario has resume steps
- Evaluates per-step and final assertions
- Variables interpolation (`{{workspace}}`, `{{session_id}}`, etc.)

### Injection points for Docker mode
1. **invoke() level** -- Add `isolation` parameter. When `isolation="docker"`, build a `docker run` command instead of bare `claude -p`. This is the cleanest injection point.
2. **scenario_runner level** -- Pass `isolation` from scenario.json `agent.isolation` field down to `invoke()`.
3. **claude_cli.py re-export** -- No changes needed; it just re-exports from vendor.

---

## 4. Interface: invoke() Changes (kiss-claw side only)

**Constraint: we do NOT modify my-claude-minion.** Changes go in `tests/lib/claude_cli.py` or a new `tests/lib/docker_invoke.py`.

### Proposed API

```python
# In tests/lib/docker_invoke.py (new file)

def docker_invoke(
    prompt: str,
    *,
    image: str = "my-claude-minion",
    workspace: str,              # host path, mounted as /workspace
    oauth_dir: str = "~/.claude",# host path for OAuth tokens
    extra_mounts: list = None,   # additional -v mounts
    exclude_paths: list = None,  # paths to NOT mount from oauth_dir
    **invoke_kwargs,             # forwarded to build the claude command
) -> ClaudeResult:
```

### How it translates to `docker run`

```bash
docker run --rm \
  -v /path/to/workspace:/workspace \
  -v /tmp/kiss-claw-oauth-XXXX:/root/.claude:ro \
  -v /path/to/kiss-claw/plugins:/kiss-claw-plugins:ro \
  -e CLAUDE_CODE_DISABLE_NONESSENTIAL=1 \
  my-claude-minion \
  claude -p "prompt" \
    --dangerously-skip-permissions \
    --effort medium \
    --output-format json \
    --no-session-persistence
```

### Wrapper in tests/lib/claude_cli.py

```python
from tests.lib.docker_invoke import docker_invoke

_original_invoke = invoke  # from vendor

def invoke(prompt, *, isolation=None, workspace=None, **kwargs):
    if isolation == "docker":
        return docker_invoke(prompt, workspace=workspace, **kwargs)
    return _original_invoke(prompt, **kwargs)
```

### Scenario.json integration

```json
{
  "agent": {
    "isolation": "docker",
    "model": "sonnet",
    "effort": "medium"
  }
}
```

`scenario_runner.py` reads `agent_config.get("isolation")` and passes it to `invoke()`.

---

## 5. Mount Strategy

### What to mount

| Host path | Container path | Mode | Purpose |
|-----------|---------------|------|---------|
| `$workspace` (test workspace) | `/workspace` | **rw** | Agent needs to write files |
| Filtered OAuth dir (see below) | `/root/.claude` | `ro` | Auth tokens only |
| kiss-claw plugin dir (if needed) | `/kiss-claw-plugins` | `ro` | Test-specific tools |

### What to exclude from ~/.claude

The host `~/.claude` directory contains items that would pollute the SUT environment:

| File/Dir | Action | Reason |
|----------|--------|--------|
| `settings.json` | **EXCLUDE** | Contains host permissions, MCP servers, allowed tools |
| `settings.local.json` | **EXCLUDE** | Same |
| `CLAUDE.md` | **EXCLUDE** | Host-level system prompt |
| `projects/` | **EXCLUDE** | Project-specific CLAUDE.md and settings |
| `todos/` | **EXCLUDE** | Host task state |
| `.credentials.json` | **INCLUDE** | OAuth tokens (required) |
| `statsig/` | **INCLUDE** | Feature flags (harmless) |
| `session_markers/` | **EXCLUDE** | Host session state |

### Exclusion implementation

Rather than selective excludes (complex with bind mounts), use a **staged copy** approach:

```python
def _prepare_oauth_dir(source="~/.claude"):
    """Copy only auth-essential files to a temp dir."""
    tmp = tempfile.mkdtemp(prefix="kiss-claw-oauth-")
    # Copy only .credentials.json (and statsig/ if present)
    shutil.copy2(expanduser(source) + "/.credentials.json", tmp)
    return tmp  # Mount this as /root/.claude:ro
```

This is simple, explicit, and avoids accidental inclusion of new files that Anthropic might add to `~/.claude` in the future.

---

## 6. Session Resume in Docker Mode

### Problem
Session persistence requires state in `~/.claude` between invocations. In Docker, the container is ephemeral (`--rm`).

### Options

| Option | Approach | Complexity |
|--------|----------|------------|
| A. Named volume | `docker volume create kiss-session-X`, mount at `/root/.claude/projects/` | Medium |
| B. Host temp dir | Stage a session dir on host, mount it rw at `/root/.claude/projects/` | Low |
| C. No resume in Docker | Disallow resume steps when `isolation="docker"` | Trivial |

### Recommendation: Option C (v1), Option B (v2)

For v1, multi-turn scenarios with `--resume` are not the primary use case for isolation testing. Most isolation tests verify that the agent works correctly without host contamination in a single prompt.

If resume is needed later (v2):
- After each step, copy session state from container to a host temp dir
- Before next step, mount that temp dir back in
- This requires **removing `--rm`** and using `docker cp` or a persistent volume

---

## 7. Constraints Summary

| Constraint | Status |
|------------|--------|
| SUT agent runs in Docker | Core requirement |
| Test runner stays on host | Core requirement |
| Zero external dependencies added | Satisfied (Docker is already available) |
| Do NOT modify my-claude-minion | Satisfied (all changes in kiss-claw) |
| OAuth auth works in container | Via staged `.credentials.json` copy |
| No host CLAUDE.md / settings / MCP leaks | Via selective mount (staged copy) |
| Session resume support | Deferred to v2 |

---

## 8. Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Docker image not built | Tests fail immediately | Medium | Pre-check in `docker_invoke()`, auto-build via `build.sh` |
| OAuth token expired inside container | Auth failure, test fails | Low | Tokens are short-lived but refreshed on host; test runner can pre-validate |
| Read-only workspace blocks agent | Agent cannot write files | High if mounted ro | Mount workspace as **rw** (test workspace is ephemeral anyway) |
| Claude CLI version drift (host vs container) | Different behavior | Low | Pin version in Dockerfile or check at test start |
| Container startup latency | Slow tests | Medium | Accept for isolation tests; these are not meant to be fast |
| `--rm` prevents session resume | Multi-turn scenarios break | N/A in v1 | Deferred; v1 only supports single-turn isolation tests |
| Docker socket permissions | Non-root user cannot run Docker | Medium | Document: user must be in `docker` group or use rootless Docker |
| New files in ~/.claude contaminate SUT | Pollution despite precautions | Low | Staged copy approach (allowlist) is future-proof |

---

## 9. Files to Create/Modify (Implementation Plan)

| File | Action | Description |
|------|--------|-------------|
| `tests/lib/docker_invoke.py` | **CREATE** | Docker-aware invoke wrapper |
| `tests/lib/claude_cli.py` | **MODIFY** | Add `isolation` parameter routing |
| `tests/lib/scenario_runner.py` | **MODIFY** | Pass `agent.isolation` to invoke |
| `tests/scenarios/*/scenario.json` | **MODIFY** | Add `"isolation": "docker"` to agent config (opt-in) |

No changes to `vendor/my-claude-minion/`.
