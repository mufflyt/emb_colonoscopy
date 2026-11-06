#!/usr/bin/env Rscript
#' Run the test suite without installing the package
#'
#' `tests/testthat.R` is the canonical runner and the one CI uses: it
#' requires `samevisit` to be installed (`R CMD INSTALL .`), which is the
#' right thing to check before a release. This script is the development
#' shortcut for the common case of iterating on a test or a function
#' while the installed copy is absent or stale. It sources `R/*.R`
#' directly instead, so what runs is the working tree, not the library.
#'
#' Run from the repository root:
#'   Rscript tests/run_without_install.R                     # whole suite
#'   Rscript tests/run_without_install.R test-saboteurs.R    # one file
#'
#' Two caveats, both deliberate:
#'
#'   1. Sourcing is not installing. Namespace collisions, missing
#'      `@importFrom` declarations, and `R CMD check` problems are
#'      invisible here by construction. A green run from this script is
#'      not a substitute for `Rscript tests/testthat.R`, and is not what
#'      the CI badge reports.
#'   2. It attaches the Imports it needs itself. If `DESCRIPTION` gains a
#'      dependency that a sourced file needs at load time, add it to
#'      `required_packages` below or the source step will fail quietly
#'      (each file is sourced inside `try()`, matching how the package
#'      would tolerate an optional dependency).
#'
#' Written while adding tests/testthat/test-saboteurs.R, where the
#' install-then-test loop was the slowest part of the iteration.

if (!base::file.exists("config/model_parameters.csv")) {
  base::stop(
    "Run from the repository root, e.g. `Rscript tests/run_without_install.R`."
  )
}

required_packages <- base::c(
  "dplyr", "tibble", "tidyr", "purrr", "readr", "rlang",
  "stringr", "magrittr", "scales", "withr", "testthat"
)
missing_packages <- required_packages[
  !base::vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (base::length(missing_packages) > 0) {
  base::stop(
    "Missing package(s): ", base::paste(missing_packages, collapse = ", "),
    ". Install them, or use `Rscript tests/testthat.R` against an installed ",
    "copy of samevisit instead."
  )
}

base::suppressMessages({
  library(dplyr)
  library(tibble)
  library(tidyr)
  library(purrr)
  library(readr)
  library(rlang)
  library(stringr)
  library(testthat)
})
`%>%` <- magrittr::`%>%`

model_files <- base::list.files("R", pattern = "[.]R$", full.names = TRUE)
base::invisible(base::lapply(model_files, function(path) {
  base::try(base::source(path), silent = TRUE)
}))

# tests/testthat/helper-fixtures.R resolves config/ and data/ paths against
# this option, because testthat::test_dir() changes the working directory.
base::options(emb_colonoscopy_repo_root = base::normalizePath("."))
base::source("tests/testthat/helper-fixtures.R")

requested_file <- base::commandArgs(trailingOnly = TRUE)

test_results <- if (base::length(requested_file) == 0) {
  base::suppressMessages(
    testthat::test_dir("tests/testthat", reporter = "summary", stop_on_failure = TRUE)
  )
} else {
  target_path <- base::file.path("tests/testthat", base::basename(requested_file[[1]]))
  if (!base::file.exists(target_path)) {
    base::stop("No such test file: ", target_path)
  }
  base::suppressMessages(
    testthat::test_file(target_path, reporter = "summary", stop_on_failure = TRUE)
  )
}

base::invisible(test_results)
