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

The Armadillo admin password is read from the environment only — never written
to a tracked file. Set it once in a git-ignored secrets file:

```bash
cp perf-bench/secrets.env.example perf-bench/secrets.env   # then edit in your password
```

The wrapper scripts source `secrets.env` automatically, so you never paste the
password into a terminal. (`secrets.env` is git-ignored; `secrets.env.example`
is the committed template.)

## Run

Edit the paths/URL at the top of `perf-bench/config.R` if needed.

**Quick check first** (no builds/installs, ~1-2 min, uses the existing `default`
profile and reverts everything it touches):

```bash
bash perf-bench/smoke.sh
```

**Full comparison** (builds both dsBase versions, installs into isolated
profiles, runs both arms, plots):

```bash
bash perf-bench/run_compare.sh
```

The full run's build step is interactive (`armadillo.login` opens a browser for
OAuth). Outputs land in `perf-bench/results/` (git-ignored).

## Files

| file                          | role                                                        |
|-------------------------------|-------------------------------------------------------------|
| `perf-bench/config.R`         | server URL, repo paths, arms, function list, duration       |
| `perf-bench/build_and_install.R` | build both dsBase versions, create profiles, install     |
| `perf-bench/inject_harness.R` | idempotent URL/profile support injection (per worktree)     |
| `perf-bench/run_perf.R`       | `run_arm(label)`: filtered `devtools::test`, capture rates  |
| `perf-bench/plot_perf.R`      | comparison figures + `perf_comparison.csv`                  |
| `perf-bench/smoke.sh`         | quick connection + capture check (no builds)                |
| `perf-bench/smoke_test.R`     | the two-stage smoke logic invoked by `smoke.sh`             |
| `perf-bench/run_compare.sh`   | end-to-end orchestrator (worktrees, build, run, plot)       |
| `perf-bench/secrets.env.example` | template for the git-ignored `secrets.env`               |
