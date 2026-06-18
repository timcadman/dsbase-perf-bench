# ------------------------------------------------------------------------------
# Shared configuration for the batch 1-2 performance comparison.
#
# Two arms, each built from source and run in an ISOLATED Armadillo profile so we
# are certain which dsBase version answers each call:
#
#   "v636" : dsBase v6.3.6-dev  + dsBaseClient v6.3.6-dev   (current)
#   "v70"  : dsBase v7.0-dev     + dsBaseClient v7.0-dev      (refactored)
#
# The dsBase (server) packages are built and installed into profiles by
# build_and_install.R; the dsBaseClient (client) versions are exercised via
# git worktrees by run_compare.sh (see that file).
# ------------------------------------------------------------------------------

# --- Demo server (Armadillo) ---
ARMADILLO_URL <- "https://armadillo-demo.molgenis.net"
ADMIN_USER    <- "admin"
ADMIN_PASS    <- Sys.getenv("ARMADILLO_ADMIN_PASS")   # export in your shell; never commit

if (nchar(ADMIN_PASS) == 0)
  warning("ARMADILLO_ADMIN_PASS is not set; export it before running.")

# --- Local repository paths ---
DSBASE_REPO       <- "/Users/tcadman/github-repos/ds-core/dsBase"
DSBASECLIENT_REPO <- "/Users/tcadman/github-repos/ds-core/dsBaseClient"

# --- The two arms (keep run_compare.sh's list in sync) ---
ARMS <- list(
  v636 = list(label = "v636", pretty = "dsBase 6.3.6", profile = "v636dev",
              port = 6312, dsbase_branch = "v6.3.6-dev", client_branch = "v6.3.6-dev"),
  v70  = list(label = "v70",  pretty = "dsBase 7.0",   profile = "v70dev",
              port = 6313, dsbase_branch = "v7.0-dev",  client_branch = "v7.0-dev")
)

# --- Functions refactored in batches 1 and 2 (batch 1 is a subset of batch 2) ---
PERF_FUNCTIONS <- c("abs", "asCharacter", "asDataMatrix", "asInteger", "asList",
                    "asLogical", "asMatrix", "asNumeric", "assign", "class",
                    "colnames", "completeCases", "dim", "exists", "exp", "isNA",
                    "length", "levels", "log", "ls", "mean", "names", "numNA",
                    "unique", "sqrt")

# --- Measurement settings ---
PERF_DURATION_SEC <- 5     # seconds per test_that loop (read by perf.testduration())

# Relative to the directory you run from (the tooling repo root, or a worktree
# that has had perf-bench/ copied in). run_compare.sh collects per-arm results
# back into the tooling repo's perf-bench/results for plotting.
OUT_DIR <- file.path("perf-bench", "results")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
