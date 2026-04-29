#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "$SCRIPT_DIR/run_binary.sh"
bash "$SCRIPT_DIR/run_continuous.sh"
bash "$SCRIPT_DIR/run_survival.sh"

echo "All plaintext CmdStan runs completed."
