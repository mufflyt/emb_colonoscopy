#!/usr/bin/env Rscript
#' Manuscript Table -- base-case cost and clinical-outcome summary
#'
#' Builds a single table combining deterministic base-case costs with
#' PSA-derived clinical-outcome means, for the manuscript's main-text
#' figure/table selection (5 combined, per Obstetrics & Gynecology's
#' Instructions for Authors).
#'
#' Deliberately reads the ALREADY-SAVED `tables/probabilistic_sensitivity_draws.csv`
#' rather than calling run_probabilistic_sensitivity() again:
#' run_probabilistic_sensitivity() is unseeded, so a fresh call here would
#' draw a different 1,000 simulations than the ones the manuscript's Results
#' text was written from, reintroducing the same same-document
#' internal-inconsistency bug already caught once (see CHANGELOG.md,
#' "Draft Methods and Results sections for the manuscript"). Re-run
#' analysis/03_probabilistic_sensitivity.R first if the draws file needs
#' refreshing, then re-run this script and re-check the manuscript prose
#' against the new numbers together, not separately.
#'
#' Run from the repository root:
#'   Rscript analysis/11_manuscript_table10_summary.R

base::source("R/00_source_all.R")

base::message("=== Manuscript Table: base-case + clinical-outcome summary ===")

model_parameters <- load_model_parameters("config/model_parameters.csv")
price_index_table <- load_price_index_table("data/cpi_medical_care.csv")

strategy_result <- compute_strategy_costs(model_parameters, price_index_table)
base_case <- strategy_result$strategy_costs

psa <- readr::read_csv("tables/probabilistic_sensitivity_draws.csv", show_col_types = FALSE)

clinical_outcome_means <- tibble::tibble(
  strategy = c("combined_emb", "office_emb", "dnc"),
  mean_major_ae_per_1000 = c(
    base::mean(psa$combined_emb_major_ae_per_1000),
    base::mean(psa$office_emb_major_ae_per_1000),
    base::mean(psa$dnc_major_ae_per_1000)
  ),
  mean_neoplasia_delayed_per_1000 = c(
    base::mean(psa$combined_emb_neoplasia_delayed_per_1000),
    base::mean(psa$office_emb_neoplasia_delayed_per_1000),
    NA_real_ # D&C has no delayed-neoplasia branch in this model (deterministic reference arm)
  )
)

table10 <- base_case %>%
  dplyr::mutate(strategy_label = STRATEGY_LABELS[.data$strategy]) %>%
  dplyr::left_join(clinical_outcome_means, by = "strategy") %>%
  dplyr::mutate(
    initial_cost = base::round(.data$initial_cost, 2),
    expected_total_cost = base::round(.data$expected_total_cost, 2),
    escalation_probability = scales::percent(.data$escalation_probability, accuracy = 0.1),
    mean_major_ae_per_1000 = base::round(.data$mean_major_ae_per_1000, 2),
    mean_neoplasia_delayed_per_1000 = base::round(.data$mean_neoplasia_delayed_per_1000, 2)
  ) %>%
  dplyr::select(
    "strategy_label", "initial_cost", "escalation_probability", "expected_total_cost",
    "mean_major_ae_per_1000", "mean_neoplasia_delayed_per_1000"
  ) %>%
  dplyr::rename(
    Strategy = "strategy_label",
    `Initial cost ($)` = "initial_cost",
    `Escalation probability` = "escalation_probability",
    `Expected total cost ($)` = "expected_total_cost",
    `Major adverse events per 1,000` = "mean_major_ae_per_1000",
    `Delayed neoplasia per 1,000*` = "mean_neoplasia_delayed_per_1000"
  )

base::print(table10)

save_table(table10, "manuscript_table10_summary.csv")

base::message(
  "\n* D&C: not applicable (no escalation/failure branch modeled). Combined ",
  "EMB: 0.00 by construction, not by evidence -- see manuscript Discussion. ",
  "Delayed-neoplasia and major-adverse-event means are computed from the ",
  "same 1,000 probabilistic-sensitivity draws saved in ",
  "tables/probabilistic_sensitivity_draws.csv."
)

base::message("=== Table complete ===")
