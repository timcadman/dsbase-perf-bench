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

# Mirrors scripts/release/lib/setup-profiles.R in molgenis-service-armadillo:
# a non-empty options map with a datashield.seed is required (an empty map
# serialises to [] and is rejected with 400), resourcer must be whitelisted,
# success is HTTP 204, and a freshly created profile must then be started.
profile_exists <- function(name)
  status_code(GET(ARMADILLO_URL, path = paste0("ds-profiles/", name), auth)) == 200

free_port <- function(preferred) {
  used <- vapply(content(GET(ARMADILLO_URL, path = "ds-profiles", auth)),
                 function(p) as.integer(p$port %||% NA), integer(1))
  port <- preferred
  while (port %in% used) port <- port + 1
  port
}
`%||%` <- function(a, b) if (is.null(a)) b else a

start_profile <- function(name) {
  r <- POST(paste0(ARMADILLO_URL, "/ds-profiles/", name, "/start"), auth)
  if (!status_code(r) %in% c(204L, 409L))   # 409 = already running
    stop("starting profile '", name, "' failed (", status_code(r), ")")
  message("profile '", name, "' running.")
}

create_profile <- function(arm) {
  whitelist <- as.list(unique(c("dsBase", "resourcer", unlist(def$packageWhitelist))))
  body <- list(
    name              = arm$profile,
    image             = def$image,                       # clone default's base image
    host              = "localhost",
    port              = free_port(arm$port),
    packageWhitelist  = whitelist,
    functionBlacklist = as.list(unlist(def$functionBlacklist)),
    options           = list(datashield.seed = round(runif(1, 1e8, 9.99e8))))
  r <- PUT(ARMADILLO_URL, path = "ds-profiles",
           body = toJSON(body, auto_unbox = TRUE), content_type_json(), auth)
  if (status_code(r) != 204L)
    stop("creating profile '", arm$profile, "' failed (", status_code(r), "): ",
         content(r, "text", encoding = "UTF-8"))
  message("profile '", arm$profile, "' created.")
}

for (arm in ARMS) {
  message("=== ", arm$pretty, " (", arm$dsbase_branch, " -> ", arm$profile, ") ===")
  tarball <- build_dsbase(arm$dsbase_branch)
  if (profile_exists(arm$profile)) message("profile '", arm$profile, "' exists; reusing.")
  else create_profile(arm)
  start_profile(arm$profile)                                   # must be running to install
  armadillo.install_packages(tarball, profile = arm$profile)
  message("installed dsBase into '", arm$profile, "'.")
}
message("build_and_install.R: both profiles ready.")
