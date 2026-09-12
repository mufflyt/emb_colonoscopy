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

# Per-scenario PSA error bars: re-runs run_probabilistic_sensitivity() under
# each scenario's own parameter overrides, so the interval reflects
# uncertainty in the underlying cost/probability evidence AS PRICED under
# that scenario, not uncertainty about which scenario is correct (see
# summarize_psa_cost_interval()'s docblock).
scenario_definitions <- build_scenario_definitions(model_parameters, price_index_table)
scenario_psa_intervals <- dplyr::bind_rows(purrr::imap(
  scenario_definitions,
  function(scenario_definition, scenario_name) {
    scenario_parameters <- override_model_parameters(
      model_parameters, scenario_definition$overrides
    )
    summarize_psa_cost_interval(scenario_parameters, price_index_table) %>%
      dplyr::mutate(scenario = scenario_name, .before = 1)
  }
))
save_table(scenario_psa_intervals, "scenario_psa_intervals.csv")

scenario_results_with_ci <- scenario_results %>%
  dplyr::left_join(scenario_psa_intervals, by = base::c("scenario", "strategy")) %>%
  dplyr::mutate(
    label = STRATEGY_LABELS[.data$strategy],
    scenario_label = dplyr::coalesce(
      unname(SCENARIO_LABELS[.data$scenario]), .data$scenario
    )
  )

dodge_position <- ggplot2::position_dodge(width = 0.9)

scenario_figure <- ggplot2::ggplot(
  scenario_results_with_ci,
  ggplot2::aes(x = .data$scenario_label, y = .data$expected_total_cost, fill = .data$label)
) +
  ggplot2::geom_col(position = dodge_position) +
  ggplot2::geom_errorbar(
    ggplot2::aes(ymin = .data$ci_low, ymax = .data$ci_high),
    position = dodge_position, width = 0.25, linewidth = 0.4, colour = "grey30"
  ) +
  ggplot2::geom_text(
    ggplot2::aes(y = .data$ci_high, label = scales::dollar(.data$ci_high, accuracy = 1)),
    position = dodge_position, vjust = -0.5, size = 2.2, colour = "grey35"
  ) +
  ggplot2::scale_y_continuous(
    labels = scales::dollar_format(), expand = ggplot2::expansion(mult = c(0, 0.12))
  ) +
  ggplot2::scale_fill_brewer(palette = "Set1", name = "Strategy") +
  ggplot2::labs(
    x = NULL, y = "Expected cost per patient ($)",
    caption = "Error bars: 95% probabilistic-sensitivity-analysis interval, re-run under each scenario's own cost assumptions."
  ) +
  theme_journal() +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 20, hjust = 1))

ggplot2::ggsave(
  "figures/figure5_scenario_comparison.jpeg",
  plot = scenario_figure, width = 9, height = 6.5, device = "jpeg", dpi = 300
)
base::message("Saved figure to: figures/figure5_scenario_comparison.jpeg")

base::message("=== Scenario analysis complete ===")
