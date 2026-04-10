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
_project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if _project_root not in sys.path:
    sys.path.insert(0, _project_root)

from tests.lib.assertions import (
    assert_exit_code,
    assert_file_contains,
    assert_file_exists,
)
from tests.lib.claude_cli import invoke

# Derive kiss-claw repo root from this file's location (tests/scenarios/test_konvert_agents.py)
_REPO_ROOT = str(Path(__file__).resolve().parents[2])

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
        ctx: dict with keys 'scenario_dir' and 'workspace'.

    Raises:
        AssertionError: If any must-pass acceptance criterion fails.
    """
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
            max_turns=50,                                         # INV-4
            effort="medium",                                      # agents need reasoning
            max_budget_usd=5.0,                                   # INV-5
            timeout=900,                                          # INV-6
            extra_flags=["--plugin-dir", _REPO_ROOT],             # INV-7
            cwd=workspace,                                        # INV-9
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

        # --- ERR-3: Budget exceeded ---
        if result.exit_code != 0:
            stderr_lower = (result.stderr or "").lower()
            if "budget" in stderr_lower or "cost" in stderr_lower:
                ac_results.append(("AC-1", False, "Exit code is 0", "budget exceeded"))
                raise AssertionError(
                    f"budget exceeded: claude exited with code {result.exit_code}. "
                    f"stderr: {result.stderr[:300]}"
                )

        # --- AC-1: Exit code is 0 ---
        try:
            assert_exit_code(result, 0)
            ac_results.append(("AC-1", True, "Exit code is 0", ""))
        except AssertionError as e:
            ac_results.append(("AC-1", False, "Exit code is 0", str(e)))
            raise

        # --- AC-2: JSON parseable ---
        try:
            assert result.json is not None, (
                "AC-2 failed: result.json is None — stdout could not be parsed as JSON. "
                f"stdout preview: {(result.stdout or '')[:300]!r}"
            )
            ac_results.append(("AC-2", True, "JSON response is parseable", ""))
        except AssertionError as e:
            ac_results.append(("AC-2", False, "JSON response is parseable", str(e)))
            raise

        # --- AC-3: .kiss-claw/PLAN.md exists and mentions phases ---
        plan_path = ws / ".kiss-claw" / "PLAN.md"
        try:
            assert_file_exists(str(plan_path))
            assert_file_contains(str(plan_path), r"(?i)(phase|etape|étape)")
            ac_results.append(("AC-3", True, "PLAN.md exists with phase content", ""))
        except AssertionError as e:
            ac_results.append(("AC-3", False, "PLAN.md exists with phase content", str(e)))
            raise

        # --- AC-4: .kiss-claw/STATE.md exists ---
        state_path = ws / ".kiss-claw" / "STATE.md"
        try:
            assert_file_exists(str(state_path))
            ac_results.append(("AC-4", True, "STATE.md exists", ""))
        except AssertionError as e:
            ac_results.append(("AC-4", False, "STATE.md exists", str(e)))
            raise

        # --- AC-5: konvert.sh exists and is executable ---
        konvert_path = ws / "konvert.sh"
        try:
            assert_file_exists(str(konvert_path))
            assert os.access(str(konvert_path), os.X_OK), (
                f"AC-5 failed: {konvert_path} exists but is not executable"
            )
            ac_results.append(("AC-5", True, "konvert.sh exists and is executable", ""))
        except AssertionError as e:
            ac_results.append(("AC-5", False, "konvert.sh exists and is executable", str(e)))
            raise

        # --- AC-6: test_konvert.sh exists and is executable ---
        test_konvert_path = ws / "test_konvert.sh"
        try:
            assert_file_exists(str(test_konvert_path))
            assert os.access(str(test_konvert_path), os.X_OK), (
                f"AC-6 failed: {test_konvert_path} exists but is not executable"
            )
            ac_results.append(("AC-6", True, "test_konvert.sh exists and is executable", ""))
        except AssertionError as e:
            ac_results.append(("AC-6", False, "test_konvert.sh exists and is executable", str(e)))
            raise

        # --- AC-7: .kiss-claw/REVIEWS.md exists ---
        reviews_path = ws / ".kiss-claw" / "REVIEWS.md"
        try:
            assert_file_exists(str(reviews_path))
            ac_results.append(("AC-7", True, "REVIEWS.md exists", ""))
        except AssertionError as e:
            ac_results.append(("AC-7", False, "REVIEWS.md exists", str(e)))
            raise

        # --- AC-8: .kiss-claw/INSIGHTS.md exists (SOFT — no fail) ---
        insights_path = ws / ".kiss-claw" / "INSIGHTS.md"
        if insights_path.exists():
            ac_results.append(("AC-8", True, "INSIGHTS.md exists (soft)", ""))
        else:
            ac_results.append(("AC-8", True, "INSIGHTS.md not found (soft — not required)", ""))

        all_passed = True

    except AssertionError:
        # Re-raise after logging in finally block
        raise

    finally:
        # --- Logging (LOG-1 through LOG-5) ---
        _write_log(
            ctx,
            result=result,
            ac_results=ac_results,
            all_passed=all_passed,
            workspace=workspace,
            duration=time.time() - start_time,
        )

        # --- SET-3: Cleanup strategy ---
        if all_passed:
            try:
                shutil.rmtree(workspace)
            except OSError:
                pass  # Best-effort cleanup
        # On failure, workspace is preserved (LOG-5 handles the message)


def _write_log(ctx, *, result, ac_results, all_passed, workspace, duration):
    """Write a detailed log file with per-criterion results.

    Wrapped to satisfy LOG-3: log writing must not cause the test to fail.
    """
    try:
        log_dir = os.path.join(
            ctx.get("workspace", ctx.get("scenario_dir", ".")),
            "tests",
            "scenarios",
        )
        os.makedirs(log_dir, exist_ok=True)
        log_path = os.path.join(log_dir, "konvert_agents_result.log")

        status = "PASS" if all_passed else "FAIL"

        # Extract metadata from result
        exit_code = result.exit_code if result else "(no result)"
        session_id = "(unknown)"
        cost = "(unknown)"
        if result and result.json:
            session_id = result.json.get("session_id", "(unknown)")
            cost = result.json.get("cost_usd", result.json.get("cost", "(unknown)"))

        lines = [
            f"test: test_konvert_agents",
            f"status: {status}",
            f"exit_code: {exit_code}",
            f"duration: {duration:.1f}s",
            f"cost: {cost}",
            f"session_id: {session_id}",
            f"workspace: {workspace}",
            "",
            "--- Acceptance Criteria Results ---",
        ]

        # LOG-4: One line per criterion
        for ac_id, passed, description, error in ac_results:
            if passed:
                lines.append(f"{ac_id}: PASS — {description}")
            else:
                lines.append(f"{ac_id}: FAIL — {description} — {error}")

        # LOG-5: Preserve workspace message on failure
        if not all_passed:
            lines.append("")
            lines.append(f"WORKSPACE PRESERVED FOR INSPECTION: {workspace}")

        with open(log_path, "w") as f:
            f.write("\n".join(lines) + "\n")

    except OSError:
        pass  # LOG-3: log failure must not break the test
