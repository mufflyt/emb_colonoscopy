#!/usr/bin/env Rscript
#' Probabilistic sensitivity analysis (PSA)
#'
#' Run from the repository root:
#'   Rscript analysis/03_probabilistic_sensitivity.R

base::source("R/00_source_all.R")

base::message("=== Probabilistic sensitivity analysis ===")

model_parameters <- load_model_parameters("config/model_parameters.csv")
price_index_table <- load_price_index_table("data/cpi_medical_care.csv")

probabilistic_estimates <- run_probabilistic_sensitivity(
  model_parameters,
  price_index_table = price_index_table,
  n_simulations = 1000
)

save_table(probabilistic_estimates, "probabilistic_sensitivity_draws.csv")

psa_summary <- probabilistic_estimates %>%
  tidyr::pivot_longer(
    cols = c("office_emb_cost", "combined_emb_cost", "dnc_cost"),
    names_to = "strategy",
    values_to = "expected_total_cost"
  ) %>%
  dplyr::group_by(.data$strategy) %>%
  dplyr::summarise(
    mean_cost = base::mean(.data$expected_total_cost),
    sd_cost = stats::sd(.data$expected_total_cost),
    p2_5 = stats::quantile(.data$expected_total_cost, 0.025),
    p97_5 = stats::quantile(.data$expected_total_cost, 0.975),
    .groups = "drop"
  )

save_table(psa_summary, "probabilistic_sensitivity_summary.csv")

psa_histogram <- ggplot2::ggplot(
  probabilistic_estimates,
  ggplot2::aes(x = .data$incremental_cost_combined_vs_office)
) +
  ggplot2::geom_histogram(bins = 40, fill = "#4A90D9", colour = "white") +
  ggplot2::geom_vline(xintercept = 0, linetype = "dashed", colour = "grey30") +
  ggplot2::scale_x_continuous(labels = scales::dollar_format()) +
  ggplot2::labs(
    x = "Incremental cost, combined EMB vs. office EMB ($)",
    y = "Monte Carlo draws"
  ) +
  theme_journal()

ggplot2::ggsave(
  "figures/figure4_psa_incremental_cost.jpeg",
  plot = psa_histogram, width = 8, height = 6, device = "jpeg", dpi = 300
)
base::message("Saved figure to: figures/figure4_psa_incremental_cost.jpeg")

base::message("=== Probabilistic sensitivity analysis complete ===")
