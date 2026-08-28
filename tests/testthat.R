#!/usr/bin/env Rscript
#' Test runner
#'
#' Run from the repository root:
#'   Rscript tests/testthat.R

if (!base::file.exists("R/00_source_all.R")) {
  base::stop(
    "Run tests from the repository root, e.g. `Rscript tests/testthat.R`, ",
    "not from inside tests/."
  )
}

base::source("R/00_source_all.R")

# testthat::test_dir() changes the working directory to tests/testthat/
# while tests run, so anchor an absolute repo-root path for fixtures
# that need to read config/model_parameters.csv and data/*.csv.
base::options(emb_colonoscopy_repo_root = base::normalizePath("."))

if (!base::requireNamespace("testthat", quietly = TRUE)) {
  base::stop("Package 'testthat' is required to run tests. Install with install.packages(\"testthat\").")
}

test_results <- testthat::test_dir(
  "tests/testthat",
  stop_on_failure = TRUE,
  reporter = "summary"
)
