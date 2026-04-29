#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${CMDSTAN:-}" ]]; then
  echo "Error: CMDSTAN is not set. Set it first, for example: export CMDSTAN=/path/to/cmdstan" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MODEL="$PACKAGE_DIR/models/binary"
DATA="$PACKAGE_DIR/data/stan_input_binary.json"
DRAWS="$PACKAGE_DIR/outputs/draws/binary_draws.csv"
LOG="$PACKAGE_DIR/outputs/logs/binary.log"

mkdir -p "$PACKAGE_DIR/outputs/draws" "$PACKAGE_DIR/outputs/logs" "$PACKAGE_DIR/outputs/summaries"

if [[ ! -x "$MODEL" ]]; then
  echo "Error: compiled model not found: $MODEL. Run bash engine_package/scripts/compile_models.sh first." >&2
  exit 1
fi

"$MODEL" sample \
  num_warmup=1000 \
  num_samples=1000 \
  random seed=20260407 \
  data file="$DATA" \
  output file="$DRAWS" \
  > "$LOG" 2>&1

echo "Binary draws written to $DRAWS"
