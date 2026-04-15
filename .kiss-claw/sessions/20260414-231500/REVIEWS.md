# Reviews — Session 20260414-231500

### REV-0001

- **date**     : 2026-04-14
- **subject**  : kiss-executor task — Phase 1 TDD red: fixtures and unit tests for checkpoint-enrich.py
- **verdict**  : approved-with-notes

**Summary**
Fixtures are realistic and well-structured. The 8 unit tests cover the spec's core behaviors (parsing, classification, enrichment, non-overwrite, CLI modes, missing transcript). Two minor issues around import viability and incomplete classification signal coverage.

**Issues**
- [minor] Import path `from scripts.checkpoint_enrich import ...` requires `scripts/__init__.py` AND file named `checkpoint_enrich.py` (underscore), while spec says `checkpoint-enrich.py` (hyphen). Executor flagged this. Implementation must reconcile.
- [minor] `test_classify_blocks` does not cover `Verdict :` or `REV-` signals from spec classification table. Add a block with verificator-style output.
- [minor] `_load_yaml_stdlib` helper is dead code — never called by any test.
- [minor] `test_classify_blocks` asserts only `artifacts, decisions, issues` but spec says `rationale` is synthesized from decisions. Test should verify `rationale` key presence.

**For kiss-orchestrator**
Proceed to next step (Phase 2 implementation). Minor issues can be addressed during green phase.

### REV-0002

- **date**     : 2026-04-14
- **subject**  : kiss-executor task — Phase 2 TDD green: checkpoint-enrich.py implementation
- **verdict**  : approved-with-notes

**Summary**
Implementation of `scripts/checkpoint_enrich.py` (~250 lines) covering JSONL parsing, block classification, step enrichment, and CLI modes (batch, --step, --dry-run). All 8 tests pass against the provided fixtures. Core logic is correct and clean. Two minor issues found related to spec conformance on output format and transcript path resolution.

**Issues**
- [minor] Classification fields stored as Python lists, not YAML block scalars — The spec and `expected_enriched.yaml` show `artifacts`, `decisions`, `issues`, `rationale` as `|` block scalar strings, but the implementation stores them as `list[str]`. `yaml.dump` will output YAML list syntax instead of `|` blocks. Tests pass because they only check `len() > 0`, not format. This will matter when other agents or humans read the CHECKPOINT.
- [minor] Transcript path resolution uses `~/.claude/projects/<slug>/` (live Claude storage) rather than `.kiss-claw/claude-sessions/` (synced location from spec). Both work, but using the live path means enrichment cannot run after sessions are cleaned from `~/.claude/`. The synced location would be more resilient.

**For kiss-orchestrator**
Proceed to next step. Minor format issue can be addressed in a follow-up refactor phase.

### REV-0003

- **date**     : 2026-04-14
- **subject**  : kiss-executor task — Phase 4 bug fixes: slug mismatch, children recursion, block scalar
- **verdict**  : approved-with-notes

**Summary**
Bug 1 (slug mismatch) fixed by reading `claude_sessions_path` from SESSIONS.json, computed correctly in `init.sh` (keeps leading dash). Bugs 2 (children recursion) and 3 (block scalar trailing whitespace) confirmed present in current code. One minor issue: fallback paths still contain the buggy `.lstrip("-")`.

**Issues**
- [minor] `_find_transcript` line 221 and `main()` line 268 both still use `.lstrip("-")` in their fallback slug derivation. While these fallbacks are now rarely reached (SESSIONS.json provides the correct path), they remain buggy and should be fixed for consistency: remove `.lstrip("-")` or remove the dead fallback in `_find_transcript` entirely since `transcripts_base` is always set from `main()`.
- [minor] `init.sh` line 328-332: inline Python uses shell variable interpolation (`'$claude_sessions_path'`) inside a Python string. Paths with single quotes would break. Low risk for typical paths but fragile.

**For kiss-orchestrator**
Proceed to next step. The `.lstrip("-")` remnants are dead-code-adjacent and non-blocking.
