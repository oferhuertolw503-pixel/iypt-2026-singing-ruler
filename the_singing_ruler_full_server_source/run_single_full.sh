#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDY_ID="smoke_full"
export PYTHONDONTWRITEBYTECODE=1

ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --study-id)
      STUDY_ID="$2"
      shift 2
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

exec python3 "$SCRIPT_DIR/tools/run_case.py" \
  --case-id "$STUDY_ID" \
  --output-root "$SCRIPT_DIR/outputs/$STUDY_ID" \
  --runtime-root "$SCRIPT_DIR/runtime/$STUDY_ID" \
  "${ARGS[@]}"
