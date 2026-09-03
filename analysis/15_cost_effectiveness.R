#!/usr/bin/env Rscript
#' Cost-consequence secondary analysis (cost per additional true case detected)
#'
#' A lighter alternative to a full cost-utility analysis: no QALYs, no
#' stage-shift/survival model. See R/cost_effectiveness.R's file-level
#' docblock for the full methodology, and docs/methods_notes.md for why a
#' full cost-utility extension is a much larger undertaking this repository
#' does not attempt.
#'
#' Run from the repository root:
#'   Rscript analysis/15_cost_effectiveness.R

base::source("R/00_source_all.R")

base::message("=== Cost-consequence secondary analysis ===")

model_parameters <- load_model_parameters("config/model_parameters.csv")
price_index_table <- load_price_index_table("data/cpi_medical_care.csv")

cost_effectiveness <- dplyr::bind_rows(
  compute_diagnostic_yield_cost_effectiveness(model_parameters, price_index_table, "cancer"),
  compute_diagnostic_yield_cost_effectiveness(model_parameters, price_index_table, "precancer")
)

save_table(cost_effectiveness, "cost_effectiveness.csv")

base::message("=== Cost-consequence secondary analysis complete ===")
