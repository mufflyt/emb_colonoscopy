#!/usr/bin/env Rscript
#' Opportunity cost of a displaced colonoscopy-suite case: real hospital data
#'
#' Computes the commercial-margin-based opportunity-cost ceiling at six
#' real hospitals (see R/opportunity_cost_colonoscopy.R's file-level
#' docblock and docs/data_sources.md for the full method and citations).
#' Nothing here feeds the base-case cost engine; this is a standalone
#' sensitivity exercise. Run from the repository root:
#'   Rscript analysis/16_opportunity_cost_colonoscopy.R

base::source("R/00_source_all.R")

base::message("=== Opportunity cost of a displaced colonoscopy-suite case ===")

model_parameters <- load_model_parameters("config/model_parameters.csv")
rates_table <- load_colonoscopy_hospital_rates_table()

opportunity_cost_bound <- compute_colonoscopy_opportunity_cost_bound(
  model_parameters, rates_table
)

base::print(base::as.data.frame(opportunity_cost_bound))

save_table(opportunity_cost_bound, "colonoscopy_opportunity_cost_bound.csv")

base::message(
  "\nAcross ", base::nrow(opportunity_cost_bound), " real hospitals, the ",
  "commercial-margin-based opportunity-cost ceiling for displacing a ",
  "colonoscopy-suite slot ranges from ",
  scales::dollar(base::min(opportunity_cost_bound$opportunity_cost_ceiling)), " (",
  opportunity_cost_bound$hospital[base::which.min(opportunity_cost_bound$opportunity_cost_ceiling)],
  ") to ",
  scales::dollar(base::max(opportunity_cost_bound$opportunity_cost_ceiling)), " (",
  opportunity_cost_bound$hospital[base::which.max(opportunity_cost_bound$opportunity_cost_ceiling)],
  "). The floor is $0 by construction at every hospital (see file docblock). ",
  "Mississippi is the only hospital with a negative commercial margin, ",
  "so its ceiling is below $0 as well -- a real, hospital-specific finding, ",
  "not an error.\n"
)

base::message("=== Opportunity cost of a displaced colonoscopy-suite case complete ===")
