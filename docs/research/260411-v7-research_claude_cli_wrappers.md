# Research: Claude CLI Wrappers — State of the Art

> **Date**: 2026-04-11
> **Purpose**: Survey existing projects that wrap Claude Code CLI, identify patterns, and position my-claude-minion.

---

## Existing Projects

| Project | Approach | Link |
|---------|----------|------|
| claude-agent-sdk-python (official Anthropic) | Subprocess + JSON-lines stdin/stdout, asyncio+pydantic, bundles CLI in wheels | [github](https://github.com/anthropics/claude-agent-sdk-python) |
| tintinweb/claude-code-container | Docker isolation, shell scripts, non-root user, CLAUDE_CODE_OAUTH_TOKEN | [github](https://github.com/tintinweb/claude-code-container) |
| VishalJ99/claude-docker | Docker drop-in, auto-mounts (Conda/SSH/git), persistent state | [github](https://github.com/VishalJ99/claude-docker) |
| RichardAtCT/claude-code-openai-wrapper | FastAPI proxy, OpenAI-compatible API, Claude Agent SDK backend | [github](https://github.com/RichardAtCT/claude-code-openai-wrapper) |
| disler/claude-code-is-programmable | Direct subprocess Python/JS, flat examples | [github](https://github.com/disler/claude-code-is-programmable) |
| Chachamaru127/claude-code-harness | TypeScript guardrails, skills/agents/hooks layers | [github](https://github.com/Chachamaru127/claude-code-harness) |

---

## Additional Sources

- [Agentic CLI wrapper blog post](https://avasdream.com/blog/claude-cli-agentic-wrapper)
- [Why Claude Code subagents waste 50K tokens per turn](https://dev.to/jungjaehoon/why-claude-code-subagents-waste-50k-tokens-per-turn-and-how-to-fix-it-41ma)
- [Inside the Claude Agent SDK](https://buildwithaws.substack.com/p/inside-the-claude-agent-sdk-from)
- [Run Claude Code with Docker](https://www.docker.com/blog/run-claude-code-with-docker/)
- [Claude Code headless mode docs](https://code.claude.com/docs/en/headless)

---

## Structural Patterns Identified

| Pattern | Projects using it |
|---------|-------------------|
| `src/` layout | claude-agent-sdk-python, claude-code-harness |
| `pyproject.toml` (PEP 621) | claude-agent-sdk-python |
| Dedicated `docker/` directory | claude-code-container, claude-docker |
| Separate `docs/` directory | claude-agent-sdk-python, claude-code-harness |
| asyncio-based | claude-agent-sdk-python, claude-code-openai-wrapper |
| pip dependencies required | claude-agent-sdk-python (pydantic), claude-code-openai-wrapper (FastAPI) |
| stdlib only | disler/claude-code-is-programmable (partial) |

---

## Gap Analysis

| Capability | claude-agent-sdk | code-container | claude-docker | openai-wrapper | is-programmable | code-harness | **my-claude-minion** |
|------------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Synchronous subprocess | - | - | - | - | yes | - | **yes** |
| Stdlib only (zero pip) | - | n/a | n/a | - | partial | - | **yes** |
| OAuth only (no API key) | - | yes | yes | - | - | - | **yes** |
| Docker isolation | - | yes | yes | - | - | - | **yes** |
| Structured result object | yes | - | - | yes | - | - | **yes** |
| Dry-run mode (no LLM) | - | - | - | - | - | - | **yes** |
| Fine-grained CLI control | yes | - | - | - | partial | yes | **yes** |
| Session continuation | yes | - | - | - | - | - | **yes** |

---

## Conclusion

No existing project combines: synchronous subprocess + stdlib-only + zero pip + OAuth-only + Docker isolation + structured results + dry-run mode.

**my-claude-minion** fills this gap as a standalone, reusable component extracted from the kiss-claw test framework.
