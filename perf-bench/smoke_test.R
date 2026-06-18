# ------------------------------------------------------------------------------
# Quick validation of the pipeline WITHOUT building or installing anything.
# Uses the EXISTING Armadillo profile (default = "default", current dsBase) and a
# short duration, so it finishes in ~1-2 min.
#
# Must be run from a dsBaseClient checkout that has perf-bench/ copied in
# (smoke.sh does the copy + cleanup for you):
#   ARMADILLO_ADMIN_PASS=... Rscript -e 'source("perf-bench/smoke_test.R")'
#
# Env knobs: ARMADILLO_PROFILE (default "default"), SMOKE_FN (default "mean"),
#            PERF_DURATION_SEC (default 5).
# ------------------------------------------------------------------------------
library(dsBaseClient)
source("perf-bench/config.R")
profile <- Sys.getenv("ARMADILLO_PROFILE", "default")
fn      <- Sys.getenv("SMOKE_FN", "mean")
dur     <- as.integer(Sys.getenv("PERF_DURATION_SEC", "5"))
if (nchar(ADMIN_PASS) == 0) stop("export ARMADILLO_ADMIN_PASS first")

suppressMessages({ library(DSI); library(DSMolgenisArmadillo) })
devtools::load_all(".", quiet = TRUE)   # load this checkout's dsBaseClient

## ---- Stage 1: connection + auth (the biggest unknown) ----
message("== Stage 1: connection + basic auth (profile '", profile, "') ==")
b <- DSI::newDSLoginBuilder(.silent = TRUE)
b$append(server = "sim1", url = ARMADILLO_URL, table = "datashield/cnsim/CNSIM1",
         user = ADMIN_USER, password = ADMIN_PASS,
         driver = "ArmadilloDriver", profile = profile)
conns <- DSI::datashield.login(b$build(), assign = TRUE)
print(datashield.tables(conns))
print(ds.ls())
print(ds.length("D"))
print(ds.dim("D"))
print(ds.colnames("D"))
res <- tryCatch(ds.mean("D$LAB_TSC", datasources = conns), error = function(e) {
  message("\nds.mean failed: ", conditionMessage(e))
  message("---- datashield.errors() ----")
  print(DSI::datashield.errors())
  DSI::datashield.logout(conns)
  stop("Stage 1 FAILED — see the server-side DataSHIELD error above. ",
       "If it's a meanDS signature/version error, it's a client/server mismatch ",
       "on the 'default' profile; the matched per-arm builds avoid it.")
})
print(res)
DSI::datashield.logout(conns)
message("Stage 1 OK: server reachable, basic auth works, cnsim readable.\n")

## ---- Stage 2: capture pipeline via devtools::test ----
message("== Stage 2: devtools::test capture (perf-ds.", fn, ", ", dur, "s) ==")
source("perf-bench/inject_harness.R")   # add URL/profile support to this checkout
source("perf-bench/run_perf.R")         # for parse_rates()
Sys.setenv(ARMADILLO_URL = ARMADILLO_URL, ARMADILLO_PROFILE = profile,
           PERF_DURATION_SEC = dur)
Sys.unsetenv("PERF_PROFILE")
options(opal.user = ADMIN_USER, opal.password = ADMIN_PASS, default_driver = "ArmadilloDriver")

out <- capture.output(
  suppressWarnings(devtools::test(filter = paste0("^perf-ds\\.", fn, "$"), reporter = "summary")),
  type = "output")
df <- parse_rates(out, "smoke")
if (is.null(df) || !nrow(df)) {
  writeLines(out, file.path(OUT_DIR, "rawlog_smoke.txt"))
  stop("Stage 2 FAILED: no rate captured; see ", file.path(OUT_DIR, "rawlog_smoke.txt"))
}
print(df)
message("Stage 2 OK: devtools::test capture works. Pipeline is good to run in full.")
