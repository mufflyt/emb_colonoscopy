#!/usr/bin/env Rscript
#' Manuscript-ready output tables
#'
#' Assembles the numbered tables a manuscript would actually cite,
#' recomputed directly from the model rather than copied from other
#' analysis/ scripts' output (so this script is self-contained and always
#' reflects the current parameter table). Run from the repository root,
#' after installing dependencies:
#'   Rscript analysis/07_manuscript_outputs.R
#'
#' Produces, all under tables/manuscript_*.csv:
#'   Table 1  model parameters, with evidence tier and provisional flag
#'   Table 2  cost components by strategy
#'   Table 3  base-case strategy comparison
#'   Table 4  one-way sensitivity analysis
#'   Table 5  probabilistic sensitivity summary + probability cheapest
#'   Table 6  threshold analyses
#'   Table 7  budget impact
#'   Table 8  evidence-tier summary
#'   Table 9  external-validation (literature-replication) status

base::source("R/00_source_all.R")

base::message("=== Manuscript output tables ===")

model_parameters <- load_model_parameters("config/model_parameters.csv")
price_index_table <- load_price_index_table("data/cpi_medical_care.csv")

strategy_result <- compute_strategy_costs(model_parameters, price_index_table)
strategy_comparison <- compare_strategies_to_cheapest(strategy_result$strategy_costs)
combined_vs_office <- compare_combined_vs_office(strategy_result$strategy_costs)
threshold_estimates <- run_threshold_analyses(model_parameters, price_index_table)
budget_impact <- estimate_budget_impact_all_comparators(strategy_result$strategy_costs)

table1_parameters <- model_parameters %>%
  dplyr::select(
    "parameter", "category", "strategy", "description", "base_value", "unit",
    "low_value", "high_value", "distribution", "dollar_year", "source",
    "evidence_tier", "provisional", "notes"
  ) %>%
  dplyr::arrange(.data$evidence_tier, .data$category, .data$parameter)

table2_cost_components <- strategy_result$cost_components

table3_strategy_comparison <- build_strategy_comparison_table(strategy_comparison)

table4_one_way_sensitivity <- run_one_way_sensitivity(
  model_parameters,
  parameter_names = c(
    "emb_office_professional_cost", "emb_failure_lynch",
    "combined_to_dnc_probability", "combined_emb_added_minutes",
    "direct_room_cost_per_minute", "anesthesia_cost_per_minute",
    "emb_pathology_cost", "dnc_facility_or_asc_fee", "coordination_cost",
    "emb_disposable_supply_cost"
  ),
  price_index_table = price_index_table
)

base::message("Running probabilistic sensitivity analysis for Table 5 (1000 draws).")
probabilistic_estimates <- run_probabilistic_sensitivity(
  model_parameters, price_index_table = price_index_table, n_simulations = 1000
)
table5_psa_summary <- build_psa_summary_table(probabilistic_estimates)

table6_thresholds <- threshold_estimates
table7_budget_impact <- budget_impact
table8_evidence_tiers <- summarize_evidence_tiers(model_parameters)
table9_validation_status <- literature_replication_status()

save_table(table1_parameters, "manuscript_table1_parameters.csv")
save_table(table2_cost_components, "manuscript_table2_cost_components.csv")
save_table(table3_strategy_comparison, "manuscript_table3_strategy_comparison.csv")
save_table(table4_one_way_sensitivity, "manuscript_table4_one_way_sensitivity.csv")
save_table(table5_psa_summary, "manuscript_table5_psa_summary.csv")
save_table(table6_thresholds, "manuscript_table6_thresholds.csv")
save_table(table7_budget_impact, "manuscript_table7_budget_impact.csv")
save_table(table8_evidence_tiers, "manuscript_table8_evidence_tiers.csv")
save_table(table9_validation_status, "manuscript_table9_validation_status.csv")

summary_sentence <- build_summary_sentence(
  strategy_comparison, combined_vs_office, threshold_estimates
)
base::message("\n", summary_sentence, "\n")
readr::write_lines(summary_sentence, "tables/manuscript_summary_sentence.txt")

base::message("=== Manuscript output tables complete ===")
