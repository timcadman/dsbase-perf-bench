#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Quick pipeline check (no builds, no installs): connection + auth, then a short
# devtools::test capture, against the EXISTING "default" profile (current dsBase).
# Finishes in ~1-2 min. Reverts everything it touches on exit.
#
# One-time setup:
#   cp perf-bench/secrets.env.example perf-bench/secrets.env   # then edit in your password
#
# Run (from this tooling repo root):
#   bash perf-bench/smoke.sh
#
# Optional overrides:  SMOKE_FN=length PERF_DURATION_SEC=5 ARMADILLO_PROFILE=default
# -----------------------------------------------------------------------------
set -euo pipefail

TOOLING_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT_REPO="/Users/tcadman/github-repos/ds-core/dsBaseClient"   # == DSBASECLIENT_REPO in config.R

[[ -f "$TOOLING_ROOT/perf-bench/secrets.env" ]] && source "$TOOLING_ROOT/perf-bench/secrets.env"
: "${ARMADILLO_ADMIN_PASS:?set ARMADILLO_ADMIN_PASS in perf-bench/secrets.env (copy secrets.env.example)}"

cd "$CLIENT_REPO"
rm -rf perf-bench
cp -R "$TOOLING_ROOT/perf-bench" perf-bench

cleanup() {
  cd "$CLIENT_REPO"
  rm -rf perf-bench
  git checkout -- tests/testthat/connection_to_datasets 2>/dev/null || true
}
trap cleanup EXIT

ARMADILLO_PROFILE="${ARMADILLO_PROFILE:-default}" \
PERF_DURATION_SEC="${PERF_DURATION_SEC:-5}" \
SMOKE_FN="${SMOKE_FN:-mean}" \
  Rscript -e 'source("perf-bench/smoke_test.R")'
