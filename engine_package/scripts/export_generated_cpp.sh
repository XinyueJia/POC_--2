#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${CMDSTAN:-}" ]]; then
  echo "ERROR: CMDSTAN is not set. Please export CMDSTAN=/path/to/cmdstan" >&2
  exit 1
fi

STANC="${CMDSTAN}/bin/stanc"

if [[ ! -x "${STANC}" ]]; then
  echo "ERROR: stanc not found at ${STANC}. Please check your CmdStan installation." >&2
  exit 1
fi

mkdir -p engine_package/generated_cpp

"${STANC}" engine_package/models/binary.stan \
  --o=engine_package/generated_cpp/binary.hpp

"${STANC}" engine_package/models/continuous.stan \
  --o=engine_package/generated_cpp/continuous.hpp

"${STANC}" engine_package/models/survival.stan \
  --o=engine_package/generated_cpp/survival.hpp

echo "Generated stanc C++ headers under engine_package/generated_cpp/"
