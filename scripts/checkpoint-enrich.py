#!/usr/bin/env python3
"""CLI entry point for checkpoint-enrich (hyphenated name).

This file delegates to checkpoint_enrich.py (underscore) which contains
the actual implementation and is importable as a Python module.
"""

import os
import sys

# Ensure the scripts directory is importable
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from scripts.checkpoint_enrich import main

if __name__ == "__main__":
    main()
