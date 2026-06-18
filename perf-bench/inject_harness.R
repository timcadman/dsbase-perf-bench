# ------------------------------------------------------------------------------
# Idempotent, branch-independent injection of remote-server support into the
# testthat connection helpers of the CURRENT working tree.
#
# Adds:
#   * ARMADILLO_URL    env override of the hardcoded http://<host>:8080 URL
#   * ARMADILLO_PROFILE env selection of the Armadillo profile for the cnsim login
#
# The URL target diverged between branches (PR #682 rewrote v6.3.6-dev's
# connection helpers): v7.0-dev still builds the URL from server_ip_address,
# whereas v6.3.6-dev uses init.server.url() with an "http://localhost:8080/"
# fallback. inject_any() tries both, so this works in either worktree until the
# branches reconverge. The profile target (2) is still identical on both.
# Run from a dsBaseClient repo root:  Rscript perf-bench/inject_harness.R
# ------------------------------------------------------------------------------

inject <- function(path, old, new, marker) {
  txt <- paste(readLines(path, warn = FALSE), collapse = "\n")
  if (grepl(marker, txt, fixed = TRUE)) {
    message("  already injected: ", path); return(invisible(FALSE))
  }
  if (!grepl(old, txt, fixed = TRUE))
    stop("injection target not found in ", path, ":\n  ", old)
  txt <- gsub(old, new, txt, fixed = TRUE)
  writeLines(txt, path)
  message("  injected: ", path)
  invisible(TRUE)
}

# Like inject(), but tries several candidate targets and applies the first that
# is present — used where the target string differs between branches.
inject_any <- function(path, candidates, marker) {
  txt <- paste(readLines(path, warn = FALSE), collapse = "\n")
  if (grepl(marker, txt, fixed = TRUE)) {
    message("  already injected: ", path); return(invisible(FALSE))
  }
  for (c in candidates) if (grepl(c$old, txt, fixed = TRUE)) {
    writeLines(gsub(c$old, c$new, txt, fixed = TRUE), path)
    message("  injected: ", path)
    return(invisible(TRUE))
  }
  stop("no URL injection target found in ", path)
}

login <- "tests/testthat/connection_to_datasets/login_details.R"
init  <- "tests/testthat/connection_to_datasets/init_studies_datasets.R"

# (1) URL override — make the Armadillo server URL honour $ARMADILLO_URL.
#     The target differs by branch, so try each in turn (see header note).
inject_any(
  login,
  list(
    # v7.0-dev: URL built from server_ip_address (paste appears 4x; all replaced)
    list(old = 'paste("http://", ds.test_env$server_ip_address, ":8080", sep="")',
         new = 'Sys.getenv("ARMADILLO_URL", unset = paste("http://", ds.test_env$server_ip_address, ":8080", sep=""))'),
    # v6.3.6-dev (post-#682): init.server.url() with localhost fallback
    list(old = 'armadillo.url <- "http://localhost:8080/"',
         new = 'armadillo.url <- Sys.getenv("ARMADILLO_URL", unset = "http://localhost:8080/")')
  ),
  marker = "ARMADILLO_URL")

# (2) Profile selection — append profile= to the three cnsim Armadillo appends.
for (n in 1:3) {
  inject(
    init,
    old    = sprintf('table = "datashield/cnsim/CNSIM%d", driver = ds.test_env$driver)', n),
    new    = sprintf('table = "datashield/cnsim/CNSIM%d", driver = ds.test_env$driver, profile = Sys.getenv("ARMADILLO_PROFILE", "default"))', n),
    marker = sprintf('CNSIM%d", driver = ds.test_env$driver, profile', n))
}
message("inject_harness.R: done.")
