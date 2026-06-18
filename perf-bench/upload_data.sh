#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Upload the cnsim tables the perf tests need (datashield/cnsim/CNSIM1..3) to the
# demo server. Idempotent; covers all profiles (shared storage). Run only if
# smoke.sh Stage 1 reports the data is missing.
#
#   bash perf-bench/upload_data.sh           # skip tables that already exist
#   FORCE_UPLOAD=1 bash perf-bench/upload_data.sh   # overwrite
# -----------------------------------------------------------------------------
set -euo pipefail

TOOLING_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[[ -f "$TOOLING_ROOT/perf-bench/secrets.env" ]] && source "$TOOLING_ROOT/perf-bench/secrets.env"
: "${ARMADILLO_ADMIN_PASS:?set ARMADILLO_ADMIN_PASS in perf-bench/secrets.env (copy secrets.env.example)}"

cd "$TOOLING_ROOT"
Rscript -e 'source("perf-bench/upload_data.R")'
