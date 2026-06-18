# ------------------------------------------------------------------------------
# Build both dsBase versions from source (remote branch tips) and install each
# into its own isolated Armadillo profile. The live demo "default" profile is
# left untouched.
#
#   v6.3.6-dev -> profile "v636dev"
#   v7.0-dev   -> profile "v70dev"
#
# Run interactively (armadillo.login opens a browser for OAuth):
#   Rscript -e 'source("perf-bench/build_and_install.R")'
# ------------------------------------------------------------------------------

library(MolgenisArmadillo)
library(httr)
library(jsonlite)
source("perf-bench/config.R")

# Absolute path so the dsBase worktree (created via `git -C <dsBase>`) and the
# subsequent `R CMD build` agree regardless of each process's working directory.
BUILD_DIR <- file.path(normalizePath("."), "perf-bench", "build")
dir.create(BUILD_DIR, showWarnings = FALSE, recursive = TRUE)

# Build a dsBase source tarball from a remote branch, using a throwaway git
# worktree so the user's dsBase checkout is never disturbed. Returns the path.
build_dsbase <- function(branch) {
  wt <- file.path(BUILD_DIR, paste0("dsBase-", gsub("[^A-Za-z0-9]", "_", branch)))
  unlink(wt, recursive = TRUE, force = TRUE)
  run <- function(...) if (system(paste(...)) != 0L) stop("command failed: ", paste(...))
  run("git", "-C", shQuote(DSBASE_REPO), "fetch --quiet origin")
  run("git", "-C", shQuote(DSBASE_REPO), "worktree add --quiet --force",
      shQuote(wt), paste0("origin/", branch))
  on.exit(system(paste("git -C", shQuote(DSBASE_REPO), "worktree remove --force", shQuote(wt))),
          add = TRUE)
  run("R CMD build --no-build-vignettes --no-manual --no-resave-data", shQuote(wt))
  tarball <- list.files(getwd(), pattern = "^dsBase_.*\\.tar\\.gz$", full.names = TRUE)
  stopifnot("expected a freshly built dsBase tarball" = length(tarball) >= 1)
  tarball <- tarball[which.max(file.info(tarball)$mtime)]
  dest <- file.path(BUILD_DIR, basename(tarball))
  file.rename(tarball, dest)
  message("built ", branch, " -> ", dest)
  dest
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# Build BOTH tarballs first (no auth needed) so the admin token stays fresh for
# the install calls, and so they're ready for a manual UI install if needed.
tarballs <- setNames(lapply(ARMS, function(a) build_dsbase(a$dsbase_branch)), names(ARMS))

# If you've already created the profiles AND installed dsBase via the UI, set
# SKIP_INSTALL=1 to bypass all server interaction and go straight to measuring.
if (nzchar(Sys.getenv("SKIP_INSTALL"))) {
  message("SKIP_INSTALL set: assuming profiles already have the right dsBase. ",
          "Tarballs are at:\n  ", paste(unlist(tarballs), collapse = "\n  "))
  quit(save = "no", status = 0)
}

# Authenticate (interactive OAuth). Fetch the token fresh per call so long waits
# between build and install don't expire it.
armadillo.login(ARMADILLO_URL)
auth <- function() add_headers(Authorization = paste("Bearer", armadillo.get_token(ARMADILLO_URL)))

profile_exists <- function(name)
  status_code(GET(ARMADILLO_URL, path = paste0("ds-profiles/", name), auth())) == 200

start_profile <- function(name) {
  r <- POST(paste0(ARMADILLO_URL, "/ds-profiles/", name, "/start"), auth())
  if (!status_code(r) %in% c(204L, 409L))   # 409 = already running
    stop("starting profile '", name, "' failed (", status_code(r), ")")
}

# `start` returns before the RServe accepts connections (install otherwise 503s).
wait_ready <- function(name, tries = 24, wait = 5) {
  for (i in seq_len(tries)) {
    st <- content(GET(ARMADILLO_URL, path = paste0("ds-profiles/", name), auth()))$container$status
    if (!is.null(st) && st == "RUNNING") { message("profile '", name, "' RUNNING."); return(invisible()) }
    Sys.sleep(wait)
  }
  message("warning: '", name, "' not reported RUNNING after wait; trying install anyway.")
}

install_with_retry <- function(tarball, profile, tries = 6, wait = 8) {
  for (i in seq_len(tries)) {
    ok <- tryCatch({ armadillo.get_token(ARMADILLO_URL)               # refresh session
                     armadillo.install_packages(tarball, profile = profile); TRUE },
                   error = function(e) { message("install attempt ", i, "/", tries,
                                                  " failed: ", conditionMessage(e)); FALSE })
    if (ok) return(invisible(TRUE))
    Sys.sleep(wait)
  }
  FALSE
}

manual_help <- function(arm, tarball)
  stop("\nCould not auto-install into '", arm$profile, "'.\n",
       "Do it via the Armadillo UI, then re-run with SKIP_INSTALL=1:\n",
       "  1. Profiles -> ", arm$profile, " (create if missing: same image as 'default',\n",
       "     whitelist must include dsBase + resourcer, set a datashield seed)\n",
       "  2. install this package tarball:\n     ", tarball, "\n",
       "  3. SKIP_INSTALL=1 bash perf-bench/run_compare.sh\n", call. = FALSE)

for (arm in ARMS) {
  message("=== ", arm$pretty, " (", arm$dsbase_branch, " -> ", arm$profile, ") ===")
  tarball <- tarballs[[arm$label]]
  if (!profile_exists(arm$profile))
    stop("profile '", arm$profile, "' not found. Create it in the Armadillo UI ",
         "(same image as 'default'; whitelist must include dsBase + resourcer; set a ",
         "datashield seed), then re-run.", call. = FALSE)
  start_profile(arm$profile)
  wait_ready(arm$profile)
  if (!install_with_retry(tarball, arm$profile)) manual_help(arm, tarball)
  message("installed dsBase into '", arm$profile, "'.")
}
message("build_and_install.R: both profiles ready.")
