#' Source every R/ function file in dependency order
#'
#' This project is a collection of sourced scripts rather than an
#' installed package (matching `colpocleisis_costeff`'s convention of
#' self-contained, documented `.R` files). `analysis/` scripts call
#' `source("R/00_source_all.R")` once at the top instead of repeating a
#' long list of individual `source()` calls.

required_packages <- c(
  "readr", "dplyr", "tibble", "tidyr", "purrr", "ggplot2", "scales",
  "forcats", "rlang",
  # evidence layer (CMS/HPT/MEPS) -- see docs/evidence_layers.md
  "duckplyr", "httr2", "readxl", "stringr", "openssl",
  # manuscript decision-tree figure only (analysis/10_decision_tree_figure.R)
  # -- see docs/data_sources.md
  "DiagrammeR", "DiagrammeRsvg", "rsvg"
)
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0) {
  stop(
    "Required packages not installed: ", paste(missing_packages, collapse = ", "),
    "\nInstall with: install.packages(c(",
    paste0('"', missing_packages, '"', collapse = ", "), "))"
  )
}

# Functions below still qualify individual calls (dplyr::mutate(), etc.)
# for clarity, but dplyr must be attached for the `%>%` pipe it re-exports
# from magrittr to resolve.
suppressPackageStartupMessages({
  library(dplyr)
})

r_directory <- base::dirname(
  tryCatch(base::sys.frame(1)$ofile, error = function(e) "R/00_source_all.R")
)
if (base::is.null(r_directory) || r_directory == "") {
  r_directory <- "R"
}

source_files <- c(
  "utils_validation.R",
  "parameters.R",
  "inflation.R",
  "strategy_costs.R",
  # societal_costs.R reuses the same escalation/repeat-attempt formulas as
  # strategy_costs.R (by design, so the two never silently diverge -- see
  # its own file-level docblock), so it must come after strategy_costs.R.
  "societal_costs.R",
  "comparison.R",
  "sensitivity_deterministic.R",
  "sensitivity_probabilistic.R",
  # diagnostic_yield.R reuses draw_parameter_set() from
  # sensitivity_probabilistic.R, so it must come after it.
  "diagnostic_yield.R",
  # cost_effectiveness.R calls both compute_strategy_costs() (strategy_costs.R)
  # and compute_diagnostic_yield() (diagnostic_yield.R), so it must come
  # after both.
  "cost_effectiveness.R",
  "threshold_analysis.R",
  "scenarios.R",
  # geographic_sensitivity.R calls override_model_parameters()/
  # compute_strategy_costs(), already sourced above.
  "geographic_sensitivity.R",
  "budget_impact.R",
  "literature_replication.R",
  "plotting.R",
  "tables.R",
  # evidence layer (CMS/HPT/MEPS) -- see docs/evidence_layers.md
  "evidence_codes.R",
  "cms_benchmarks.R",
  "hpt_prices.R",
  "meps_burden.R",
  "evidence_synthesis.R",
  "evidence_provenance.R",
  # public-input acquisition (reproducible download/discovery pipeline) --
  # see docs/evidence_layers.md. meps_download.R must precede
  # hpt_hospital_discovery.R, which reuses its download_public_file() and
  # sha256_file() helpers.
  "meps_download.R",
  "hpt_hospital_discovery.R",
  "public_input_config.R",
  # national colonoscopy-setting analysis -- see docs/evidence_layers.md.
  # Depends on cms_find_dataset_uuid()/cms_query_hcpcs() from cms_benchmarks.R.
  "colonoscopy_setting.R"
)

for (source_file in source_files) {
  base::source(file.path(r_directory, source_file), local = FALSE)
}

base::message("All R/ function files sourced (", length(source_files), " files).")
