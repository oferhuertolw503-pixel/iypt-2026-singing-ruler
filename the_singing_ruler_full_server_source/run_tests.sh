#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PYTHONDONTWRITEBYTECODE=1

python3 -B -m unittest discover -s "$SCRIPT_DIR/tests" -p "test_*.py"
