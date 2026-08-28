#!/usr/bin/env Rscript
#' Deterministic (one-way) sensitivity analysis and tornado plot
#'
#' Run from the repository root:
#'   Rscript analysis/02_deterministic_sensitivity.R

base::source("R/00_source_all.R")

base::message("=== Deterministic one-way sensitivity analysis ===")

model_parameters <- load_model_parameters("config/model_parameters.csv")
price_index_table <- load_price_index_table("data/cpi_medical_care.csv")

key_parameters <- c(
  "emb_office_professional_cost",
  "emb_failure_lynch",
  "combined_to_dnc_probability",
  "combined_emb_added_minutes",
  "direct_room_cost_per_minute",
  "anesthesia_cost_per_minute",
  "emb_pathology_cost",
  "dnc_facility_or_asc_fee",
  "coordination_cost",
  "emb_disposable_supply_cost"
)

sensitivity_estimates <- run_one_way_sensitivity(
  model_parameters,
  parameter_names = key_parameters,
  price_index_table = price_index_table
)

save_table(sensitivity_estimates, "one_way_sensitivity.csv")

tornado_figure <- plot_tornado(sensitivity_estimates)
ggplot2::ggsave(
  "figures/figure2_tornado.jpeg",
  plot = tornado_figure, width = 9, height = 6.5, device = "jpeg", dpi = 300
)
base::message("Saved figure to: figures/figure2_tornado.jpeg")

base::message("=== Deterministic sensitivity analysis complete ===")
