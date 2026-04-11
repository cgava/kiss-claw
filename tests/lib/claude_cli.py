"""claude_cli.py — Re-export from my-claude-minion submodule."""
import sys
import os

# Add vendor submodule to path
_vendor = os.path.join(os.path.dirname(__file__), "..", "..", "vendor", "my-claude-minion", "src")
if _vendor not in sys.path:
    sys.path.insert(0, os.path.abspath(_vendor))

from my_claude_minion import invoke, ClaudeResult
