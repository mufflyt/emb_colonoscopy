#!/usr/bin/env Rscript
#' Scenario analysis
#'
#' Compares the base case against named payer/structural scenarios
#' (illustrative Medicaid, illustrative commercial, combined-arm preop
#' visit required). Run from the repository root:
#'   Rscript analysis/05_scenario_analysis.R

base::source("R/00_source_all.R")

base::message("=== Scenario analysis ===")

model_parameters <- load_model_parameters("config/model_parameters.csv")
price_index_table <- load_price_index_table("data/cpi_medical_care.csv")

scenario_results <- run_scenario_analysis(model_parameters, price_index_table)
save_table(scenario_results, "scenario_analysis.csv")

scenario_figure <- ggplot2::ggplot(
  scenario_results %>% dplyr::mutate(label = STRATEGY_LABELS[.data$strategy]),
  ggplot2::aes(x = .data$scenario, y = .data$expected_total_cost, fill = .data$label)
) +
  ggplot2::geom_col(position = "dodge") +
  ggplot2::scale_y_continuous(labels = scales::dollar_format()) +
  ggplot2::scale_fill_brewer(palette = "Set1", name = "Strategy") +
  ggplot2::labs(x = NULL, y = "Expected cost per patient ($)") +
  theme_journal() +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 20, hjust = 1))

ggplot2::ggsave(
  "figures/figure5_scenario_comparison.jpeg",
  plot = scenario_figure, width = 9, height = 6.5, device = "jpeg", dpi = 300
)
base::message("Saved figure to: figures/figure5_scenario_comparison.jpeg")

base::message("=== Scenario analysis complete ===")
