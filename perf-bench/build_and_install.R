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

# If you've already installed dsBase into the profiles, set SKIP_INSTALL=1 to
# bypass building + install and go straight to measuring.
if (nzchar(Sys.getenv("SKIP_INSTALL"))) {
  message("SKIP_INSTALL set: assuming v636dev/v70dev already have the right dsBase. Skipping build + install.")
  quit(save = "no", status = 0)
}

# Build BOTH tarballs first (no auth needed).
tarballs <- setNames(lapply(ARMS, function(a) build_dsbase(a$dsbase_branch)), names(ARMS))

# Log in ONCE. armadillo.install_packages uses this session directly - no token,
# no profile start/poll here (create + start the profiles in the UI beforehand).
armadillo.login(ARMADILLO_URL)

manual_help <- function(arm, tarball)
  stop("\nCould not install into '", arm$profile, "'. Make sure the profile exists and is",
       " RUNNING in the Armadillo UI, then either re-run, or install this tarball",
       " interactively and re-run with SKIP_INSTALL=1:\n  ", tarball, "\n", call. = FALSE)

for (arm in ARMS) {
  message("=== ", arm$pretty, " (", arm$dsbase_branch, " -> ", arm$profile, ") ===")
  tarball <- tarballs[[arm$label]]
  ok <- tryCatch({ armadillo.install_packages(tarball, profile = arm$profile); TRUE },
                 error = function(e) { message("install failed: ", conditionMessage(e)); FALSE })
  if (!ok) manual_help(arm, tarball)
  message("installed dsBase into '", arm$profile, "'.")
}
message("build_and_install.R: both profiles ready.")
