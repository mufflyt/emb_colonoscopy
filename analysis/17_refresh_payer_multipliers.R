#!/usr/bin/env Rscript
#' Refresh the payer_multiplier_* rows from hpt_prices' payer ratios
#'
#' Copies hpt_prices' within-hospital payer-to-Medicare ratios
#' (payer_to_medicare_ratios.csv, from its analysis/14_emb_payer_ratios.R)
#' into the eight payer_multiplier_<payer>_<parameter> rows of
#' config/model_parameters.csv. See R/payer_multipliers.R for the method.
#' Run from the repository root:
#'
#'   HPT_PRICES_COMMIT=<hpt_prices commit> Rscript analysis/17_refresh_payer_multipliers.R [ratios.csv]
#'
#' The ratios file is the first argument, else HPT_PAYER_RATIOS, else the
#' hpt_prices output folder on the external drive. HPT_PRICES_COMMIT (the
#' hpt_prices commit that produced the file) is required and is cited in
#' each row's `source`. DRY_RUN=true reports the changes and writes nothing.
#' After a real change, rerun analysis/05_scenario_analysis.R,
#' 07_manuscript_outputs.R, and 11_manuscript_table10_summary.R.

base::source("R/00_source_all.R")

args <- base::commandArgs(trailingOnly = TRUE)
ratios_path <- if (base::length(args) >= 1L) {
  args[[1]]
} else {
  base::Sys.getenv("HPT_PAYER_RATIOS", unset = "/Volumes/MufflySamsung 1/hpt_prices/output/payer_to_medicare_ratios.csv")
}
hpt_commit <- base::Sys.getenv("HPT_PRICES_COMMIT", unset = "")
if (!base::nzchar(hpt_commit)) {
  base::stop("Set HPT_PRICES_COMMIT to the hpt_prices commit that produced ", ratios_path, ".", call. = FALSE)
}
dry_run <- base::tolower(base::Sys.getenv("DRY_RUN", unset = "false")) %in% base::c("1", "true", "yes")

base::message("=== Refreshing payer multipliers from ", ratios_path, " (hpt_prices @ ", hpt_commit, ")",
              if (dry_run) " [dry run]" else "", " ===")

report <- refresh_payer_multipliers("config/model_parameters.csv", ratios_path, hpt_commit, dry_run = dry_run)
base::print(base::as.data.frame(report), row.names = FALSE)

n_changed <- base::sum(report$changed)
if (n_changed == 0L) {
  base::message("\nNo changes: every multiplier already matches the ratios and commit.")
} else if (dry_run) {
  base::message("\n", n_changed, " row(s) would change. Rerun without DRY_RUN to write them.")
} else {
  base::message("\nUpdated ", n_changed, " row(s) in config/model_parameters.csv. Now rerun ",
                "analysis/05_scenario_analysis.R, 07_manuscript_outputs.R, and 11_manuscript_table10_summary.R.")
}
