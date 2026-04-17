"""test_hello_world.py — Interactive 2-step smoke test with --resume chaining.

Proves the interactive test pipeline (prompt -> resume -> assertions) is
operational using a cheap haiku model.

Scenario:
  Step 1: Ask Claude to pick a language and greet the user.
  Step 2: Detect the language and respond in kind via --resume.
"""

import os
import sys
import time

# Ensure project root is on sys.path so "tests.lib" is importable
# when the runner loads this file via importlib.
_project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if _project_root not in sys.path:
    sys.path.insert(0, _project_root)

from tests.lib.assertions import assert_exit_code
from tests.lib.claude_cli import invoke
from tests.lib.report import generate_report


# --- Language detection and responses ---

RESPONSES = {
    "fr": "Je vais tres bien, merci ! Et toi ?",
    "en": "I'm doing great, thank you! And you?",
    "es": "Estoy muy bien, gracias! Y tu?",
    "de": "Mir geht es sehr gut, danke! Und dir?",
}

LANG_LABELS = {"fr": "French", "en": "English", "es": "Spanish", "de": "German"}


def _detect_language(text):
    """Detect which language Claude used from its output."""
    text_lower = text.lower()
    if any(w in text_lower for w in ["comment", "bonjour", "salut", "ca va", "allez"]):
        return "fr"
    if any(w in text_lower for w in ["how", "hello", "doing", "are you"]):
        return "en"
    if any(w in text_lower for w in ["como", "hola", "estas"]):
        return "es"
    if any(w in text_lower for w in ["wie", "hallo", "geht", "ihnen"]):
        return "de"
    return None  # no language detected


# --- Main test ---

STEP1_PROMPT = (
    "Pick ONE language among French, English, Spanish, or German. "
    "Then ask the user 'how are you?' in that language. "
    "Reply with ONLY the greeting question, nothing else."
)


def run(ctx):
    """Execute the interactive hello-world smoke test.

    Args:
        ctx: dict with keys 'scenario_dir', 'workspace', and 'dry_run'.

    Raises:
        AssertionError: If any acceptance criterion fails.
    """
    ac_results = []
    step_rows = []
    dry_run = ctx.get("dry_run", False)
    start_time = time.time()
    session_id = None
    result_step1 = None
    result_step2 = None
    detected_lang = "en"
    step2_start = start_time  # initialize early; updated before step 2 actually starts

    # ---- Step 1: Ask Claude to greet in a chosen language ----
    step1_start = time.time()
    result_step1 = invoke(
        STEP1_PROMPT,
        model="haiku",
        effort="low",
        max_turns=1,
        output_format="json",
        session_persistence=True,
        dry_run=dry_run,
    )
    step1_duration = time.time() - step1_start

    # Handle fatal errors
    if result_step1.exit_code == -1:
        ac_results.append(("AC-1", False, "Step 1 exit code is 0", "timeout"))
        step_rows.append(("step-1-greet", step1_duration, False, "timeout"))
        _write_report(ctx, ac_results=ac_results, step_rows=step_rows,
                       result=result_step1, duration=time.time() - start_time)
        raise AssertionError("timeout: step 1 timed out")
    if result_step1.exit_code == -2:
        ac_results.append(("AC-1", False, "Step 1 exit code is 0", "claude binary not found"))
        step_rows.append(("step-1-greet", step1_duration, False, "claude not found"))
        _write_report(ctx, ac_results=ac_results, step_rows=step_rows,
                       result=result_step1, duration=time.time() - start_time)
        raise AssertionError("not found: claude binary not found in PATH")

    try:
        # AC-1: Step 1 exit code is 0
        try:
            assert_exit_code(result_step1, 0)
            ac_results.append(("AC-1", True, "Step 1 exit code is 0", ""))
        except AssertionError as e:
            ac_results.append(("AC-1", False, "Step 1 exit code is 0", str(e)))
            raise

        # Extract text from step 1
        step1_text = ""
        if result_step1.json and "result" in result_step1.json:
            step1_text = result_step1.json["result"]
        elif result_step1.stdout:
            step1_text = result_step1.stdout

        # AC-2: Step 1 output is non-empty and contains a greeting/question
        try:
            assert len(step1_text.strip()) > 0, (
                "AC-2 failed: step 1 output is empty"
            )
            ac_results.append(("AC-2", True, "Step 1 output is non-empty", ""))
        except AssertionError as e:
            ac_results.append(("AC-2", False, "Step 1 output is non-empty", str(e)))
            raise

        # AC-3: Language detected is one of fr/en/es/de
        if dry_run:
            detected_lang = "en"  # fallback for dry-run
            ac_results.append(("AC-3", True, "Language detected — SKIP (dry-run)", ""))
        else:
            detected_lang = _detect_language(step1_text)
            try:
                assert detected_lang is not None, (
                    f"AC-3 failed: could not detect language from output: {step1_text[:100]!r}"
                )
                ac_results.append(("AC-3", True,
                                   f"Language detected: {LANG_LABELS[detected_lang]}", ""))
            except AssertionError as e:
                ac_results.append(("AC-3", False, "Language detected is one of fr/en/es/de", str(e)))
                raise

        # Capture session_id for resume
        session_id = None
        if result_step1.json:
            session_id = result_step1.json.get("session_id")

        step_rows.append(("step-1-greet", step1_duration, True,
                          f"lang={detected_lang}, text={step1_text[:60]}"))

        # ---- Step 2: Resume with a response in the detected language ----
        step2_start = time.time()

        # AC-4: session_id is a non-empty string (checked before resume)
        try:
            assert isinstance(session_id, str) and len(session_id) > 0, (
                f"AC-4 failed: session_id={session_id!r}"
            )
            ac_results.append(("AC-4", True, "session_id is non-empty string", ""))
        except AssertionError as e:
            ac_results.append(("AC-4", False, "session_id is non-empty string", str(e)))
            raise

        result_step2 = invoke(
            RESPONSES[detected_lang],
            model="haiku",
            effort="low",
            max_turns=1,
            output_format="json",
            resume_session=session_id,
            dry_run=dry_run,
        )
        step2_duration = time.time() - step2_start

        # AC-5: Step 2 exit code is 0
        try:
            assert_exit_code(result_step2, 0)
            ac_results.append(("AC-5", True, "Step 2 exit code is 0", ""))
        except AssertionError as e:
            ac_results.append(("AC-5", False, "Step 2 exit code is 0", str(e)))
            raise

        # Extract text from step 2
        step2_text = ""
        if result_step2.json and "result" in result_step2.json:
            step2_text = result_step2.json["result"]
        elif result_step2.stdout:
            step2_text = result_step2.stdout

        # AC-6: Step 2 output is non-empty
        try:
            assert len(step2_text.strip()) > 0, (
                "AC-6 failed: step 2 output is empty"
            )
            ac_results.append(("AC-6", True, "Step 2 output is non-empty", ""))
        except AssertionError as e:
            ac_results.append(("AC-6", False, "Step 2 output is non-empty", str(e)))
            raise

        step_rows.append(("step-2-respond", step2_duration, True,
                          f"response={step2_text[:60]}"))

    except AssertionError:
        # Record step 2 row on failure if not yet recorded
        if len(step_rows) < 2 and result_step2 is not None:
            step_rows.append(("step-2-respond", time.time() - step2_start, False,
                              "failed"))
        raise
    finally:
        _write_report(
            ctx,
            ac_results=ac_results,
            step_rows=step_rows,
            result=result_step2 or result_step1,
            duration=time.time() - start_time,
            session_id=session_id,
        )


def _write_report(ctx, *, ac_results, step_rows, result, duration, session_id=None):
    """Write a structured Markdown test report with step table.

    Wrapped to satisfy LOG-3: log writing must not cause the test to fail.
    """
    try:
        log_dir = ctx.get("scenario_dir", ".")
        os.makedirs(log_dir, exist_ok=True)
        report_path = os.path.join(log_dir, "hello_world_report.md")

        if session_id is None and result and result.json:
            session_id = result.json.get("session_id", "(unknown)")
        session_id = session_id or "(unknown)"

        # Build step table
        step_section = ""
        if step_rows:
            lines = [
                "\n## Scenario Steps\n",
                "| # | Step | Duration | Status | Detail |",
                "|---|------|----------|--------|--------|",
            ]
            for i, (step_id, dur, passed, detail) in enumerate(step_rows):
                status = "PASS" if passed else "FAIL"
                detail_safe = detail.replace("|", "\\|")[:100]
                lines.append(f"| {i+1} | {step_id} | {dur:.1f}s | {status} | {detail_safe} |")
            step_section = "\n".join(lines)

        report = generate_report(
            test_name="test_hello_world",
            session_id=session_id,
            duration=duration,
            workspace="",
            ac_results=ac_results,
            result=result,
            preserved=False,
        )

        # Insert step section before "## Acceptance Criteria"
        if step_section:
            report = report.replace(
                "## Acceptance Criteria",
                step_section + "\n\n## Acceptance Criteria",
            )

        with open(report_path, "w") as f:
            f.write(report)

    except OSError:
        pass  # LOG-3: log failure must not break the test
