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

# Authenticate once (interactive OAuth) and prepare the admin auth header.
armadillo.login(ARMADILLO_URL)
token <- armadillo.get_token(ARMADILLO_URL)
auth  <- add_headers(Authorization = paste("Bearer", token))
def   <- content(GET(ARMADILLO_URL, path = "ds-profiles/default", auth))

create_profile <- function(arm) {
  body <- list(
    name              = arm$profile,
    image             = def$image,                 # clone default's base image
    host              = "localhost",
    port              = arm$port,                   # distinct port per profile
    packageWhitelist  = unique(c(unlist(def$packageWhitelist), "dsBase")),
    functionBlacklist = unlist(def$functionBlacklist),
    options           = def$options)
  stop_for_status(PUT(ARMADILLO_URL, path = "ds-profiles",
                      body = toJSON(body, auto_unbox = TRUE),
                      content_type_json(), auth))
  message("profile '", arm$profile, "' created/updated (port ", arm$port, ").")
}

for (arm in ARMS) {
  message("=== ", arm$pretty, " (", arm$dsbase_branch, " -> ", arm$profile, ") ===")
  tarball <- build_dsbase(arm$dsbase_branch)
  create_profile(arm)
  armadillo.install_packages(tarball, profile = arm$profile)  # no manual start needed
  message("installed dsBase into '", arm$profile, "'.")
}
message("build_and_install.R: both profiles ready.")
