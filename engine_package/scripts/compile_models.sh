#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${CMDSTAN:-}" ]]; then
  echo "Error: CMDSTAN is not set. Set it first, for example: export CMDSTAN=/path/to/cmdstan" >&2
  exit 1
fi

if [[ ! -f "$CMDSTAN/makefile" ]]; then
  echo "Error: CMDSTAN does not point to a CmdStan installation root with a makefile: $CMDSTAN" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

mkdir -p "$PACKAGE_DIR/outputs/draws" "$PACKAGE_DIR/outputs/logs" "$PACKAGE_DIR/outputs/summaries"

make -C "$CMDSTAN" "$PACKAGE_DIR/models/binary"
make -C "$CMDSTAN" "$PACKAGE_DIR/models/continuous"
make -C "$CMDSTAN" "$PACKAGE_DIR/models/survival"

echo "Compiled CmdStan models under $PACKAGE_DIR/models"
