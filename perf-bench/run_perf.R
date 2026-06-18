# ------------------------------------------------------------------------------
# Run the batch 1-2 performance tests against the demo server with devtools::test
# and capture the per-function call rate (calls/second) each test prints.
#
# Run from inside the worktree for the client version under test:
#   source("perf-bench/run_perf.R")
#   run_arm("v636")   # or run_arm("v70")
# (run_compare.sh orchestrates the worktrees and calls this.)
# ------------------------------------------------------------------------------

source("perf-bench/config.R")

# Match ONLY the batch 1-2 perf test files. testthat applies the filter to the
# file name stripped of "test-" and ".R", e.g. "perf-ds.mean".
perf_filter <- paste0("^perf-ds\\.(", paste(PERF_FUNCTIONS, collapse = "|"), ")$")

# Parse "ds.X::perf::<id>  <rate> ..." lines emitted by the perf tests. Works for
# both print formats (with/without an existing reference): the first number after
# the perf key is always the measured rate.
parse_rates <- function(lines, arm) {
  hit <- grep("::perf::", lines, value = TRUE)
  m <- regmatches(hit, regexec(
    "(ds\\.[A-Za-z0-9.]+)::perf::([A-Za-z0-9:]*)\\s*,?\\s*([0-9.eE+-]+)", hit))
  ok <- vapply(m, length, integer(1)) == 4
  if (!any(ok)) return(NULL)
  do.call(rbind, lapply(m[ok], function(x)
    data.frame(arm = arm, fn = x[2], type = ifelse(x[3] == "", "0", x[3]),
               rate = as.numeric(x[4]), stringsAsFactors = FALSE)))
}

# label: one of names(ARMS); the matching Armadillo profile is looked up there.
run_arm <- function(label) {
  arm <- ARMS[[label]]
  if (is.null(arm)) stop("unknown arm '", label, "'; expected one of: ",
                         paste(names(ARMS), collapse = ", "))

  Sys.setenv(ARMADILLO_URL     = ARMADILLO_URL,
             ARMADILLO_PROFILE = arm$profile,
             PERF_DURATION_SEC = PERF_DURATION_SEC)
  # Unset PERF_PROFILE so the (empty) default reference profile loads and every
  # test prints its raw measured rate instead of a percentage-of-reference.
  Sys.unsetenv("PERF_PROFILE")

  # v7.0-dev reads opal.*, v6.3.6-dev (post-#682) reads armadillo.* — set both
  options(opal.user          = ADMIN_USER,
          opal.password      = ADMIN_PASS,
          armadillo.user     = ADMIN_USER,
          armadillo.password = ADMIN_PASS,
          default_driver     = "ArmadilloDriver")

  message(sprintf("[%s] %s: %d functions vs profile '%s' (%ds each)...",
                  label, arm$pretty, length(PERF_FUNCTIONS), arm$profile, PERF_DURATION_SEC))

  out <- capture.output(
    suppressWarnings(devtools::test(filter = perf_filter, reporter = "summary")),
    type = "output")

  df <- parse_rates(out, label)
  if (is.null(df) || !nrow(df)) {
    writeLines(out, file.path(OUT_DIR, paste0("rawlog_", label, ".txt")))
    stop("No rate lines captured. The reporter may have swallowed print() output; ",
         "see rawlog_", label, ".txt and the tempfile path perf.reference.save() reported.")
  }

  f <- file.path(OUT_DIR, paste0("rates_", label, ".csv"))
  write.csv(df, f, row.names = FALSE)
  message(sprintf("[%s] captured %d rates -> %s", label, nrow(df), f))
  invisible(df)
}
