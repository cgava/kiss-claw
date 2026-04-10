#!/usr/bin/env bash
# setup-venv.sh — Create Python venv for kiss-claw test suite
# Idempotent: safe to re-run. Stdlib only — no pip install.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/.venv"

if [ -d "${VENV_DIR}" ]; then
    echo "venv already exists at ${VENV_DIR} — skipping creation."
else
    echo "Creating Python venv at ${VENV_DIR} ..."
    python3 -m venv "${VENV_DIR}"
    echo "venv created."
fi

echo ""
echo "To activate:"
echo "  source ${VENV_DIR}/bin/activate"
echo ""
echo "To run tests:"
echo "  python -m tests.lib.runner"
echo "  # or: python tests/lib/runner.py"
