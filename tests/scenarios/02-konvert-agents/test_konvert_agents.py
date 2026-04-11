"""test_konvert_agents.py — Integration test: full agent loop producing konvert artifacts.

Invokes Claude with the kiss-claw agent workflow (orchestrator, executor,
verificator, improver) to implement a Markdown-to-HTML converter (konvert.sh)
with tests, plan, reviews, and insights.

This test validates that the agent loop produces the expected artifacts,
NOT that konvert.sh works correctly (see NR-1).
"""

import os
import shutil
import sys
import tempfile
import time
from pathlib import Path

# Ensure project root is on sys.path so "tests.lib" is importable
# when the runner loads this file via importlib.
# Path: tests/scenarios/02-konvert-agents/test_konvert_agents.py -> project root is 3 levels up
_project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if _project_root not in sys.path:
    sys.path.insert(0, _project_root)

from tests.lib.assertions import (
    assert_exit_code,
    assert_file_contains,
    assert_file_exists,
)
from tests.lib.claude_cli import invoke
from tests.lib.report import generate_report

# Derive kiss-claw repo root from this file's location
# tests/scenarios/02-konvert-agents/test_konvert_agents.py -> 3 levels up
_REPO_ROOT = str(Path(__file__).resolve().parents[3])

# INV-8: We include the kiss-orchestrator instruction directly in the prompt.
# Rationale: embedding the instruction in the user prompt is the most explicit
# and reliable approach — no dependency on agent-suggest hooks or slash commands
# that may not be available in all environments.
_KONVERT_PROMPT = """\
Use the kiss-claw agent workflow. Start by invoking /kiss-claw:kiss-orchestrator to plan and coordinate all work.

Voici la directive complète du projet konvert, en 6 phases :

Phase 1 — Analyse et Planification
Analyser les besoins : créer un script shell `konvert.sh` qui convertit des fichiers Markdown (.md) en HTML.
Le script doit accepter un fichier en argument et produire le HTML correspondant sur stdout.
Rédiger un plan structuré avec les étapes de chaque phase.

Phase 2 — Implémentation du script konvert.sh
Implémenter `konvert.sh` en bash pur (pas de dépendances externes comme pandoc).
Le script doit gérer au minimum : titres (h1-h3), paragraphes, texte en gras et italique, listes non ordonnées, et blocs de code.
Le script doit être exécutable (chmod +x).

Phase 3 — Tests
Créer `test_konvert.sh`, un script de tests qui vérifie le bon fonctionnement de konvert.sh.
Les tests doivent couvrir chaque fonctionnalité implémentée (titres, paragraphes, gras, italique, listes, code).
Le script de test doit être exécutable et retourner un code de sortie 0 si tous les tests passent.

Phase 4 — Vérification et Revue
Vérifier que konvert.sh et test_konvert.sh fonctionnent correctement.
Exécuter les tests et confirmer qu'ils passent.
Documenter les résultats de la revue.

Phase 5 — Amélioration
Identifier des améliorations possibles (robustesse, cas limites, lisibilité du code).
Documenter les insights et recommandations.

Phase 6 — Livraison
Confirmer que tous les artefacts sont en place :
- konvert.sh (exécutable)
- test_konvert.sh (exécutable)
- Plan documenté
- Revue documentée
"""


def run(ctx):
    """Execute the konvert agent integration test.

    Args:
        ctx: dict with keys 'scenario_dir', 'workspace', and 'dry_run'.

    Raises:
        AssertionError: If any must-pass acceptance criterion fails.
    """
    dry_run = ctx.get("dry_run", False)

    # --- SET-1: Create isolated temporary workspace ---
    workspace = tempfile.mkdtemp(prefix="kiss-claw-konvert-")
    ws = Path(workspace)
    all_passed = False
    ac_results = []  # list of (id, passed, description, error)
    start_time = time.time()
    result = None

    try:
        # --- Invocation (INV-1 through INV-9) ---
        result = invoke(
            _KONVERT_PROMPT,                                      # INV-1
            output_format="json",                                 # INV-2
            model="sonnet",                                       # INV-3
            max_turns=100,                                        # INV-4 (increased: full agent loop needs many turns)
            effort="medium",                                      # agents need reasoning
            max_budget_usd=10.0,                                  # INV-5 (increased: 4 agents need room)
            timeout=1200,                                         # INV-6 (20 min: full agent loop is slow)
            extra_flags=["--plugin-dir", _REPO_ROOT],             # INV-7
            cwd=workspace,                                        # INV-9
            dry_run=dry_run,                                      # DRY-RUN
        )
        duration = time.time() - start_time

        # --- ERR-1: Timeout ---
        if result.exit_code == -1:
            ac_results.append(("AC-1", False, "Exit code is 0", f"timeout after 900s"))
            raise AssertionError(
                f"timeout: claude invocation timed out after 900 seconds"
            )

        # --- ERR-2: Binary not found ---
        if result.exit_code == -2:
            ac_results.append(("AC-1", False, "Exit code is 0", "claude binary not found"))
            raise AssertionError(
                "not found: claude binary not found in PATH"
            )

        # --- ERR-3: Note budget exceeded in stderr (don't abort — let AC-1 catch it) ---
        if result.exit_code != 0:
            stderr_lower = (result.stderr or "").lower()
            if "budget" in stderr_lower or "cost" in stderr_lower:
                print(f"  Note: budget may have been exceeded (exit code {result.exit_code})")

        # Helper: find a file at multiple candidate paths, return first found
        def _find_file(candidates):
            for p in candidates:
                if p.exists():
                    return p
            return None

        # --- Collect all AC results without raising immediately ---
        has_failure = False

        # --- AC-1: Exit code is 0 ---
        if result.exit_code == 0:
            ac_results.append(("AC-1", True, "Exit code is 0", ""))
        else:
            ac_results.append(("AC-1", False, "Exit code is 0",
                               f"got exit code {result.exit_code}"))
            has_failure = True

        # --- AC-2: JSON parseable ---
        if result.json is not None:
            ac_results.append(("AC-2", True, "JSON response is parseable", ""))
        else:
            ac_results.append(("AC-2", False, "JSON response is parseable",
                               f"stdout preview: {(result.stdout or '')[:300]!r}"))
            has_failure = True

        # --- AC-3 through AC-8: Workspace artifact checks ---
        if dry_run:
            # In dry-run mode, skip workspace artifact checks — no LLM ran,
            # so no artifacts were created.
            ac_results.append(("AC-3", True, "PLAN.md exists — SKIP (dry-run)", ""))
            ac_results.append(("AC-4", True, "STATE.md exists — SKIP (dry-run)", ""))
            ac_results.append(("AC-5", True, "konvert.sh exists — SKIP (dry-run)", ""))
            ac_results.append(("AC-6", True, "test_konvert.sh exists — SKIP (dry-run)", ""))
            ac_results.append(("AC-7", True, "REVIEWS.md exists — SKIP (dry-run)", ""))
            ac_results.append(("AC-8", True, "INSIGHTS.md exists — SKIP (dry-run)", ""))
        else:
            # --- AC-3: PLAN.md exists and mentions phases ---
            plan = _find_file([ws / ".kiss-claw" / "PLAN.md", ws / "PLAN.md"])
            if plan:
                try:
                    assert_file_contains(str(plan), r"(?i)(phase|etape|étape)")
                    loc = "(.kiss-claw/)" if ".kiss-claw" in str(plan) else "(root — wrong location)"
                    ac_results.append(("AC-3", True, f"PLAN.md exists with phase content {loc}", ""))
                except AssertionError as e:
                    ac_results.append(("AC-3", False, "PLAN.md exists but no phase content", str(e)))
                    has_failure = True
            else:
                ac_results.append(("AC-3", False, "PLAN.md exists", "not found anywhere"))
                has_failure = True

            # --- AC-4: STATE.md exists ---
            state = _find_file([ws / ".kiss-claw" / "STATE.md", ws / "STATE.md"])
            if state:
                loc = "(.kiss-claw/)" if ".kiss-claw" in str(state) else "(root — wrong location)"
                ac_results.append(("AC-4", True, f"STATE.md exists {loc}", ""))
            else:
                ac_results.append(("AC-4", False, "STATE.md exists", "not found anywhere"))
                has_failure = True

            # --- AC-5: konvert.sh exists and is executable ---
            konvert_path = ws / "konvert.sh"
            if konvert_path.exists():
                if os.access(str(konvert_path), os.X_OK):
                    ac_results.append(("AC-5", True, "konvert.sh exists and is executable", ""))
                else:
                    ac_results.append(("AC-5", False, "konvert.sh exists but NOT executable", ""))
                    has_failure = True
            else:
                ac_results.append(("AC-5", False, "konvert.sh exists", "not found"))
                has_failure = True

            # --- AC-6: test_konvert.sh exists and is executable ---
            test_konvert_path = ws / "test_konvert.sh"
            if test_konvert_path.exists():
                if os.access(str(test_konvert_path), os.X_OK):
                    ac_results.append(("AC-6", True, "test_konvert.sh exists and is executable", ""))
                else:
                    ac_results.append(("AC-6", False, "test_konvert.sh exists but NOT executable", ""))
                    has_failure = True
            else:
                ac_results.append(("AC-6", False, "test_konvert.sh exists", "not found"))
                has_failure = True

            # --- AC-7: REVIEWS.md exists (checks multiple names/locations) ---
            reviews = _find_file([
                ws / ".kiss-claw" / "REVIEWS.md",
                ws / ".kiss-claw" / "REVIEW.md",
                ws / "REVIEWS.md",
                ws / "REVIEW.md",
            ])
            if reviews:
                loc = str(reviews.relative_to(ws))
                ac_results.append(("AC-7", True, f"Reviews file exists ({loc})", ""))
            else:
                ac_results.append(("AC-7", False, "REVIEWS.md exists", "not found anywhere"))
                has_failure = True

            # --- AC-8: INSIGHTS.md exists (SOFT — no fail) ---
            insights = _find_file([
                ws / ".kiss-claw" / "INSIGHTS.md",
                ws / ".kiss-claw" / "INSIGHT.md",
                ws / "INSIGHTS.md",
                ws / "IMPROVEMENTS.md",
            ])
            if insights:
                loc = str(insights.relative_to(ws))
                ac_results.append(("AC-8", True, f"Insights file exists ({loc}) (soft)", ""))
            else:
                ac_results.append(("AC-8", True, "Insights file not found (soft — not required)", ""))

        # --- Raise if any hard criterion failed ---
        if has_failure:
            failed = [ac for ac in ac_results if not ac[1]]
            summary = "; ".join(f"{ac[0]}: {ac[3]}" for ac in failed)
            raise AssertionError(f"Criteria failed: {summary}")

        all_passed = True

    except AssertionError:
        # Re-raise after logging in finally block
        raise

    finally:
        # --- Logging (LOG-1 through LOG-5) ---
        final_duration = time.time() - start_time
        preserved = True

        # --- SET-3: Cleanup strategy ---
        # Default: preserve workspace for inspection.
        # Set KISS_CLEANUP_ON_SUCCESS=1 to delete on success.
        if all_passed and os.environ.get("KISS_CLEANUP_ON_SUCCESS") == "1":
            preserved = False
            try:
                shutil.rmtree(workspace)
            except OSError:
                pass  # Best-effort cleanup
        else:
            if not dry_run:
                print(f"  Workspace preserved: {workspace}")

        _write_report(
            ctx,
            result=result,
            ac_results=ac_results,
            workspace=workspace,
            duration=final_duration,
            preserved=preserved,
        )


def _write_report(ctx, *, result, ac_results, workspace, duration, preserved):
    """Write a structured Markdown test report.

    Wrapped to satisfy LOG-3: log writing must not cause the test to fail.
    """
    try:
        # Write report to the scenario's own directory
        log_dir = ctx.get("scenario_dir", ".")
        os.makedirs(log_dir, exist_ok=True)
        report_path = os.path.join(log_dir, "konvert_agents_report.md")

        session_id = "(unknown)"
        if result and result.json:
            session_id = result.json.get("session_id", "(unknown)")

        report = generate_report(
            test_name="test_konvert_agents",
            session_id=session_id,
            duration=duration,
            workspace=workspace,
            ac_results=ac_results,
            result=result,
            preserved=preserved,
        )

        with open(report_path, "w") as f:
            f.write(report)

    except OSError:
        pass  # LOG-3: log failure must not break the test
