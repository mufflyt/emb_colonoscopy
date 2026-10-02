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
#' The ratios file is the first argument, else HPT_PAYER_RATIOS (an explicit
#' full path), else discovered on the external drive via the mufflyt/researchpaths
#' package (remotes::install_github("mufflyt/researchpaths")) -- a glob over
#' the volume name rather than a hardcoded mount path, since macOS remounts
#' the same physical drive under a different name (e.g. "MufflySamsung 1")
#' after an unclean unmount, and a hardcoded path that silently stops
#' resolving is a correctness hazard, not just an inconvenience: it would
#' fail loudly here (no CSV to read), but the identical failure mode against
#' a DuckDB path elsewhere creates an empty database instead of erroring --
#' see researchpaths' own README. HPT_PRICES_COMMIT (the hpt_prices commit
#' that produced the file) is required and is cited in each row's `source`.
#' DRY_RUN=true reports the changes and writes nothing. After a real change,
#' rerun analysis/05_scenario_analysis.R, 07_manuscript_outputs.R, and
#' 11_manuscript_table10_summary.R.

base::source("R/00_source_all.R")

args <- base::commandArgs(trailingOnly = TRUE)
ratios_path <- if (base::length(args) >= 1L) {
  args[[1]]
} else if (base::nzchar(base::Sys.getenv("HPT_PAYER_RATIOS", unset = ""))) {
  base::Sys.getenv("HPT_PAYER_RATIOS")
} else {
  if (!base::requireNamespace("researchpaths", quietly = TRUE)) {
    base::stop(
      "No ratios path given and HPT_PAYER_RATIOS is unset. Either pass a path, ",
      "set HPT_PAYER_RATIOS, or install researchpaths to auto-discover it on ",
      "the external drive: remotes::install_github(\"mufflyt/researchpaths\")",
      call. = FALSE
    )
  }
  researchpaths::resolve_file_on_volume(
    "hpt_prices/output/payer_to_medicare_ratios.csv",
    volume_pattern = "MufflySamsung*",
    env_var = "HPT_PAYER_RATIOS",
    quiet = FALSE
  )
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
