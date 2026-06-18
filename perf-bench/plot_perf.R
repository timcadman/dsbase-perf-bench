# ------------------------------------------------------------------------------
# Produce the comparison figures from the per-arm rate files written by
# run_perf.R:  results/rates_v636.csv  and  results/rates_v70.csv
#
#   Rscript perf-bench/plot_perf.R
# ------------------------------------------------------------------------------

library(ggplot2)
library(dplyr)
library(tidyr)
source("perf-bench/config.R")

# Read each arm's captured rates; pretty label comes from ARMS in config.R.
read_arm <- function(arm) {
  f <- file.path(OUT_DIR, paste0("rates_", arm$label, ".csv"))
  if (!file.exists(f)) stop("missing results file: ", f, " (run run_arm('", arm$label, "') first)")
  transform(read.csv(f, stringsAsFactors = FALSE), arm = arm$pretty)
}
all <- bind_rows(lapply(ARMS, read_arm)) |>
  mutate(label = paste0(fn, ifelse(type %in% c("0", ""), "", paste0(" (", type, ")"))))

baseline_pretty <- ARMS$v636$pretty   # denominator for the speed-up
new_pretty      <- ARMS$v70$pretty

# (a) Side-by-side absolute rates.
p1 <- ggplot(all, aes(x = reorder(label, rate), y = rate, fill = arm)) +
  geom_col(position = position_dodge(width = 0.8)) +
  coord_flip() +
  labs(x = NULL, y = "Calls / second", fill = "Build",
       title = "Batch 1-2 functions: 6.3.6 vs 7.0",
       subtitle = "Higher is faster (demo server, calls/sec)") +
  theme_minimal(base_size = 11)

# (b) Speed-up ratio (7.0 / 6.3.6).
ratio <- all |>
  select(label, arm, rate) |>
  pivot_wider(names_from = arm, values_from = rate) |>
  filter(!is.na(.data[[baseline_pretty]]) & !is.na(.data[[new_pretty]])) |>
  mutate(speedup = .data[[new_pretty]] / .data[[baseline_pretty]])

p2 <- ggplot(ratio, aes(x = reorder(label, speedup), y = speedup, fill = speedup > 1)) +
  geom_col() +
  geom_hline(yintercept = 1, linetype = 2) +
  coord_flip() +
  scale_fill_manual(values = c(`TRUE` = "#2c7fb8", `FALSE` = "#d95f0e"), guide = "none") +
  labs(x = NULL, y = sprintf("Speed-up (%s / %s)", new_pretty, baseline_pretty),
       title = "Relative performance change",
       subtitle = "> 1 means 7.0 is faster") +
  theme_minimal(base_size = 11)

ggsave(file.path(OUT_DIR, "perf_rates.png"),   p1, width = 8, height = 9, dpi = 150)
ggsave(file.path(OUT_DIR, "perf_speedup.png"), p2, width = 8, height = 9, dpi = 150)
write.csv(ratio, file.path(OUT_DIR, "perf_comparison.csv"), row.names = FALSE)
message("Wrote perf_rates.png, perf_speedup.png and perf_comparison.csv to ", OUT_DIR)
