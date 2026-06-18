# dsBase perf bench

Tooling to compare the performance of the **batch 1-2 refactored functions** in
DataSHIELD between **dsBase 6.3.6** and **dsBase 7.0**, run against a remote
Armadillo server (the MOLGENIS demo).

This repo is standalone: it does **not** live inside `dsBase` / `dsBaseClient`.
It drives local clones of those repos via absolute paths and git worktrees.

## What it does

Two arms, each built from source and run in its own isolated Armadillo profile so
it is certain which dsBase version answers each call:

| arm    | dsBase (server)      | dsBaseClient (client) | profile   |
|--------|----------------------|-----------------------|-----------|
| `v636` | `v6.3.6-dev` (6.3.6) | `v6.3.6-dev`          | `v636dev` |
| `v70`  | `v7.0-dev` (7.0)     | `v7.0-dev`            | `v70dev`  |

For each of the 25 batch 1-2 functions it runs the existing `test-perf-ds.*`
tests via `devtools::test`, captures the calls/second each prints, and plots a
side-by-side rate chart plus a 7.0÷6.3.6 speed-up chart.

## Secrets

The Armadillo admin password is read from the environment only — it is never
written to disk or committed. Set it before running:

```bash
export ARMADILLO_ADMIN_PASS='...'
```

## Run

Edit the paths/URL at the top of `perf-bench/config.R` if needed, then:

```bash
export ARMADILLO_ADMIN_PASS='...'
bash perf-bench/run_compare.sh
```

Step 1 is interactive (`armadillo.login` opens a browser for OAuth). Outputs land
in `perf-bench/results/` (git-ignored).

## Files

| file                          | role                                                        |
|-------------------------------|-------------------------------------------------------------|
| `perf-bench/config.R`         | server URL, repo paths, arms, function list, duration       |
| `perf-bench/build_and_install.R` | build both dsBase versions, create profiles, install     |
| `perf-bench/inject_harness.R` | idempotent URL/profile support injection (per worktree)     |
| `perf-bench/run_perf.R`       | `run_arm(label)`: filtered `devtools::test`, capture rates  |
| `perf-bench/plot_perf.R`      | comparison figures + `perf_comparison.csv`                  |
| `perf-bench/run_compare.sh`   | end-to-end orchestrator (worktrees, build, run, plot)       |
