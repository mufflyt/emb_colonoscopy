#!/usr/bin/env Rscript
#' Threshold analysis and threshold plots
#'
#' Run from the repository root:
#'   Rscript analysis/04_threshold_analysis.R

base::source("R/00_source_all.R")

base::message("=== Threshold analysis ===")

model_parameters <- load_model_parameters("config/model_parameters.csv")
price_index_table <- load_price_index_table("data/cpi_medical_care.csv")

threshold_estimates <- run_threshold_analyses(model_parameters, price_index_table)
save_table(threshold_estimates, "threshold_estimates.csv")

minutes_sweep_figure <- plot_threshold_sweep(
  model_parameters,
  parameter_name = "combined_emb_added_minutes",
  parameter_grid = seq(0, 60, length.out = 100),
  price_index_table = price_index_table,
  x_label = "Incremental colonoscopy-suite minutes for EMB"
)
ggplot2::ggsave(
  "figures/figure3a_threshold_minutes.jpeg",
  plot = minutes_sweep_figure, width = 8, height = 6, device = "jpeg", dpi = 300
)

failure_sweep_figure <- plot_threshold_sweep(
  model_parameters,
  parameter_name = "emb_failure_lynch",
  parameter_grid = seq(0.001, 0.6, length.out = 100),
  price_index_table = price_index_table,
  x_label = "Office EMB failure probability"
)
ggplot2::ggsave(
  "figures/figure3b_threshold_office_failure.jpeg",
  plot = failure_sweep_figure, width = 8, height = 6, device = "jpeg", dpi = 300
)

base::message("Saved threshold sweep figures to figures/figure3a_*.jpeg and figures/figure3b_*.jpeg")
base::message("=== Threshold analysis complete ===")
