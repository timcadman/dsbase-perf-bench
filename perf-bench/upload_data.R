# ------------------------------------------------------------------------------
# Upload the cnsim tables the batch 1-2 perf tests need:
#   datashield/cnsim/CNSIM1, CNSIM2, CNSIM3
#
# Armadillo storage is shared across profiles, so uploading once makes the data
# available to the default, v636dev and v70dev profiles alike. The batch 1-2
# tests only use cnsim, so that's all this uploads (not the full test suite).
#
# Idempotent: tables that already exist are skipped (set FORCE_UPLOAD=1 to
# overwrite). NB: this writes to the SHARED 'datashield' project on the server.
# Most demo servers already have cnsim, so usually you won't need this — run it
# only if smoke.sh Stage 1 reports the table is missing.
#
# Run via the wrapper:  bash perf-bench/upload_data.sh
# ------------------------------------------------------------------------------

library(MolgenisArmadillo)
source("perf-bench/config.R")
if (nchar(ADMIN_PASS) == 0) stop("set ARMADILLO_ADMIN_PASS (perf-bench/secrets.env)")

force    <- nzchar(Sys.getenv("FORCE_UPLOAD"))
data_dir <- file.path(DSBASECLIENT_REPO, "tests", "testthat", "data_files", "CNSIM")
if (!dir.exists(data_dir)) stop("CNSIM data not found at ", data_dir)

armadillo.login_basic(armadillo = ARMADILLO_URL, username = ADMIN_USER, password = ADMIN_PASS)

if (!"datashield" %in% armadillo.list_projects())
  armadillo.create_project("datashield")

existing <- tryCatch(armadillo.list_tables("datashield"), error = function(e) character(0))

upload_one <- function(n) {
  tbl <- sprintf("CNSIM%d", n)
  if (!force && any(grepl(paste0("cnsim/", tbl, "$"), existing))) {
    message("skip (already present): datashield/cnsim/", tbl); return(invisible())
  }
  obj_name <- load(file.path(data_dir, paste0(tbl, ".rda")))   # loads the object, returns its name
  dataset  <- get(obj_name)
  armadillo.upload_table("datashield", "cnsim", dataset, tbl)
  message("uploaded: datashield/cnsim/", tbl)
  gc(verbose = FALSE)
}
invisible(lapply(1:3, upload_one))

message("\nTables now in 'datashield':")
print(armadillo.list_tables("datashield"))
