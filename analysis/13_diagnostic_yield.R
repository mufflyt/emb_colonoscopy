#!/usr/bin/env Rscript
#' Diagnostic-yield secondary analysis (Pipelle vs. D&C detection probability)
#'
#' Reports compute_diagnostic_yield(), a function that has existed in
#' R/diagnostic_yield.R and been unit-tested since before this script was
#' added, but was never previously called by any analysis driver or
#' reported in the manuscript. Answers a narrower question than the base
#' case's cost-minimization assumption of equivalent effectiveness: given
#' each strategy's own sampling-escalation logic, what fraction of a true
#' cancer/precancer case does each strategy detect, once an inadequate
#' Pipelle sample's own D&C-detection sensitivity is also accounted for?
#'
#' Deliberately not a full cost-effectiveness build-out -- see
#' R/diagnostic_yield.R's file-level docblock and docs/methods_notes.md
#' for why this extension stops at a point-estimate detection probability
#' rather than a full prevalence/PSA/equivalence-margin decision tree.
#'
#' Run from the repository root:
#'   Rscript analysis/13_diagnostic_yield.R

base::source("R/00_source_all.R")

base::message("=== Diagnostic-yield secondary analysis ===")

model_parameters <- load_model_parameters("config/model_parameters.csv")

diagnostic_yield <- dplyr::bind_rows(
  compute_diagnostic_yield(model_parameters, disease = "cancer"),
  compute_diagnostic_yield(model_parameters, disease = "precancer")
)

save_table(diagnostic_yield, "diagnostic_yield.csv")

base::message("=== Diagnostic-yield secondary analysis complete ===")
