#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Orchestrate the full batch 1-2 comparison: 6.3.6 vs 7.0, both built from source.
#
# This tooling lives in its own repo and drives the local dsBase / dsBaseClient
# clones (it does NOT live inside them). Steps:
#   1. Build both dsBase versions and install them into isolated profiles.
#   2. For each arm, check out the matching dsBaseClient branch in a git worktree,
#      copy the tooling in, inject remote-server support, and run the perf subset.
#   3. Collect results and draw the comparison figures.
#
# Prereqs:
#   export ARMADILLO_ADMIN_PASS='...'        # demo admin password (never committed)
#   step 1 (build_and_install.R) is interactive (armadillo.login opens a browser).
#
# Usage (from this tooling repo's root):
#   bash perf-bench/run_compare.sh
# -----------------------------------------------------------------------------
set -euo pipefail

TOOLING_ROOT="$(cd "$(dirname "$0")/.." && pwd)"   # this repo (contains perf-bench/)
CLIENT_REPO="/Users/tcadman/github-repos/ds-core/dsBaseClient"   # keep == DSBASECLIENT_REPO in config.R
cd "$TOOLING_ROOT"

[[ -f "$TOOLING_ROOT/perf-bench/secrets.env" ]] && source "$TOOLING_ROOT/perf-bench/secrets.env"
if [[ -z "${ARMADILLO_ADMIN_PASS:-}" ]]; then
  echo "ERROR: set ARMADILLO_ADMIN_PASS in perf-bench/secrets.env (copy secrets.env.example)." >&2; exit 1
fi

# Keep in sync with ARMS in config.R:  label : client_branch  (profile derived in R)
ARMS=("v636:v6.3.6-dev" "v70:v7.0-dev")

echo "==> [1/3] Building both dsBase versions and installing into isolated profiles"
Rscript -e 'source("perf-bench/build_and_install.R")'

echo "==> [2/3] Running perf subset per client version (git worktrees)"
git -C "$CLIENT_REPO" fetch --quiet origin
for entry in "${ARMS[@]}"; do
  label="${entry%%:*}"; cbranch="${entry##*:}"
  wt="$CLIENT_REPO-$label"          # e.g. .../ds-core/dsBaseClient-v636

  echo "--- arm '$label' : dsBaseClient $cbranch ---"
  git -C "$CLIENT_REPO" worktree add --force --detach "$wt" "origin/$cbranch"
  rm -rf "$wt/perf-bench"
  cp -R "$TOOLING_ROOT/perf-bench" "$wt/perf-bench"   # bring tooling into the worktree

  (
    cd "$wt"
    Rscript -e 'source("perf-bench/inject_harness.R")'                  # add URL/profile support
    Rscript -e "source('perf-bench/run_perf.R'); run_arm('$label')"     # measure -> rates_<label>.csv
  )

  cp "$wt/perf-bench/results/rates_$label.csv" "$TOOLING_ROOT/perf-bench/results/"
  echo "    (worktree left at $wt; remove with: git -C '$CLIENT_REPO' worktree remove --force '$wt')"
done

echo "==> [3/3] Plotting"
Rscript perf-bench/plot_perf.R
echo "Done. See perf-bench/results/{perf_rates.png,perf_speedup.png,perf_comparison.csv}"
