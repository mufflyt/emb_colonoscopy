#!/usr/bin/env Rscript
#' Base-case analysis
#'
#' Loads model parameters, computes expected cost per patient for each
#' of the three endometrial-sampling strategies, builds the primary
#' comparison table, and saves a table and a figure. Run from the
#' repository root:
#'   Rscript analysis/01_base_case.R

base::source("R/00_source_all.R")

base::message("=== EMB vs. colonoscopy-combined vs. D&C: base-case analysis ===")

model_parameters <- load_model_parameters("config/model_parameters.csv")
price_index_table <- load_price_index_table("data/cpi_medical_care.csv")

strategy_result <- compute_strategy_costs(model_parameters, price_index_table)
strategy_comparison <- compare_strategies_to_cheapest(strategy_result$strategy_costs)
combined_vs_office <- compare_combined_vs_office(strategy_result$strategy_costs)
pairwise_comparison <- build_pairwise_comparison_table(strategy_result$strategy_costs)

threshold_estimates <- run_threshold_analyses(model_parameters, price_index_table)
budget_impact <- estimate_budget_impact_all_comparators(strategy_result$strategy_costs)

summary_sentence <- build_summary_sentence(
  strategy_comparison, combined_vs_office, threshold_estimates
)

base::message("\n", summary_sentence, "\n")

strategy_comparison_table <- build_strategy_comparison_table(strategy_comparison)

save_table(strategy_comparison_table, "strategy_comparison.csv")
save_table(strategy_result$cost_components, "cost_components.csv")
save_table(pairwise_comparison, "pairwise_comparison.csv")
save_table(combined_vs_office, "combined_vs_office.csv")
save_table(threshold_estimates, "threshold_estimates_base_case.csv")
save_table(budget_impact, "budget_impact.csv")

readr::write_lines(summary_sentence, "tables/summary_sentence.txt")
base::message("Saved summary sentence to: tables/summary_sentence.txt")

if (!base::dir.exists("figures")) {
  base::dir.create("figures", recursive = TRUE)
}

cost_comparison_figure <- plot_strategy_cost_comparison(strategy_result$strategy_costs)
ggplot2::ggsave(
  "figures/figure1_strategy_cost_comparison.jpeg",
  plot = cost_comparison_figure, width = 8, height = 6, device = "jpeg", dpi = 300
)
base::message("Saved figure to: figures/figure1_strategy_cost_comparison.jpeg")

base::message("=== Base-case analysis complete ===")
