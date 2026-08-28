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
  "duckplyr", "httr2", "readxl", "stringr", "openssl"
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
  "comparison.R",
  "sensitivity_deterministic.R",
  "sensitivity_probabilistic.R",
  "threshold_analysis.R",
  "scenarios.R",
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
  "public_input_config.R"
)

for (source_file in source_files) {
  base::source(file.path(r_directory, source_file), local = FALSE)
}

base::message("All R/ function files sourced (", length(source_files), " files).")
