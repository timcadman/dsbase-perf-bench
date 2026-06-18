# ------------------------------------------------------------------------------
# Idempotent, branch-independent injection of remote-server support into the
# testthat connection helpers of the CURRENT working tree.
#
# Adds:
#   * ARMADILLO_URL    env override of the hardcoded http://<host>:8080 URL
#   * ARMADILLO_PROFILE env selection of the Armadillo profile for the cnsim login
#
# The target strings are identical on v6.3.6-dev and v7.0-dev, so this works in
# either worktree. Run from a dsBaseClient repo root:  Rscript perf-bench/inject_harness.R
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

login <- "tests/testthat/connection_to_datasets/login_details.R"
init  <- "tests/testthat/connection_to_datasets/init_studies_datasets.R"

# (1) URL override — replaces the http://host:8080 paste wherever it appears in
#     the Armadillo branch (ping_address + ip_address_1/2/3).
inject(
  login,
  old    = 'paste("http://", ds.test_env$server_ip_address, ":8080", sep="")',
  new    = 'Sys.getenv("ARMADILLO_URL", unset = paste("http://", ds.test_env$server_ip_address, ":8080", sep=""))',
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
