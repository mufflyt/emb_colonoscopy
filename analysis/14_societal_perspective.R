#!/usr/bin/env Rscript
#' Societal-perspective secondary analysis (patient time/travel opportunity cost)
#'
#' The base case takes a healthcare-sector perspective and explicitly
#' excludes patient time, transportation, and lost productivity (see
#' Methods). This script reports a separate, deterministic
#' societal-perspective add-on -- see R/societal_costs.R's file-level
#' docblock for the full methodology, sourcing, and disclosed limitations.
#'
#' Runs it twice: once under the base case (`combined_requires_preop_office_visit
#' = TRUE`, the model owner's stated clinical practice), and once under the
#' existing alternate scenario already used elsewhere in this repository's
#' scenario analysis (`combined_requires_preop_office_visit = FALSE`, consent/
#' risk assessment folded into the colonoscopy day instead of a separate
#' visit) -- the "purest" form of the combined-arm's avoid-a-visit thesis.
#'
#' Run from the repository root:
#'   Rscript analysis/14_societal_perspective.R

base::source("R/00_source_all.R")

base::message("=== Societal-perspective secondary analysis ===")

model_parameters <- load_model_parameters("config/model_parameters.csv")
price_index_table <- load_price_index_table("data/cpi_medical_care.csv")
all_items_price_index_table <- load_price_index_table("data/cpi_all_items.csv")
reference_year <- get_parameter_value(model_parameters, "reference_dollar_year")

base::message("-- Base case (combined_requires_preop_office_visit = TRUE) --")
base_case_costs <- compute_strategy_costs(model_parameters, price_index_table)
base_case_societal <- compute_strategy_societal_costs(
  model_parameters, base_case_costs$strategy_costs,
  all_items_price_index_table, reference_year
) %>%
  dplyr::mutate(scenario = "base_case_preop_visit_required")

base::message("-- Scenario: combined_requires_preop_office_visit = FALSE --")
no_preop_visit_parameters <- override_model_parameters(
  model_parameters, list(combined_requires_preop_office_visit = FALSE)
)
no_preop_visit_costs <- compute_strategy_costs(no_preop_visit_parameters, price_index_table)
no_preop_visit_societal <- compute_strategy_societal_costs(
  no_preop_visit_parameters, no_preop_visit_costs$strategy_costs,
  all_items_price_index_table, reference_year
) %>%
  dplyr::mutate(scenario = "no_separate_combined_preop_visit")

societal_perspective <- dplyr::bind_rows(base_case_societal, no_preop_visit_societal) %>%
  dplyr::select(
    "scenario", "strategy", "expected_encounters",
    "patient_time_cost_per_encounter", "societal_addon",
    "healthcare_sector_cost", "societal_total_cost"
  )

save_table(societal_perspective, "societal_perspective.csv")

base::message("=== Societal-perspective secondary analysis complete ===")
