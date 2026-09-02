#' Shared test fixtures.
#'
#' testthat::test_dir() changes the working directory to tests/testthat/
#' while tests run, so these fixtures resolve paths against the repo
#' root captured in tests/testthat.R rather than assuming the working
#' directory is the repo root.

repo_root_path <- function() {
  base::getOption("emb_colonoscopy_repo_root", ".")
}

test_model_parameters <- function() {
  load_model_parameters(file.path(repo_root_path(), "config/model_parameters.csv"))
}

test_price_index_table <- function() {
  load_price_index_table(file.path(repo_root_path(), "data/cpi_medical_care.csv"))
}

test_all_items_price_index_table <- function() {
  load_price_index_table(file.path(repo_root_path(), "data/cpi_all_items.csv"))
}
