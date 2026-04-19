### REV-0001

- **date**     : 2026-04-17
- **subject**  : kiss-executor task — Phase 1 design document: Docker isolation for SUT agents
- **verdict**  : approved-with-notes

**Summary**
Reviewed `docs/designs/260419-docker-isolation-tests.md`. The design accurately describes the host/Docker architecture, correctly audits the my-claude-minion image and entrypoint against actual source, proposes a clean injection point at `invoke()` level, and uses a staged-copy mount strategy that is simple and future-proof. The my-claude-minion non-modification constraint is respected. Session resume deferral to v2 is acceptable. Three minor issues found, no blockers.

**Issues**
- [minor] Date in header says "2025-04-19" — should be 2026.
- [minor] Section 4 docker run example uses env var `CLAUDE_CODE_DISABLE_NONESSENTIAL=1` which is undocumented and may not exist. Should either verify this env var works with Claude CLI or remove it to avoid confusion during implementation.
- [minor] `_prepare_oauth_dir()` copies only `.credentials.json`. If Anthropic changes token storage (e.g., adds a companion file), auth will silently break. The risk table (section 8) does not cover this — consider adding it or documenting the exact files that constitute "auth-essential" with a verification step at test startup.

**For kiss-orchestrator**
Proceed to next step (Phase 2 implementation).
