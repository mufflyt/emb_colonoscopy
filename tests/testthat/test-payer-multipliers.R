#' refresh_payer_multipliers() (R/payer_multipliers.R): copies hpt_prices'
#' payer ratios into the payer_multiplier_* rows without touching anything
#' else. Each test works on a temp copy of the real config file and a
#' synthetic ratios file.

synthetic_payer_ratios <- function(dir, bump = 0, drop_code = NULL) {
  codes <- payer_multiplier_codes()
  ratios <- tidyr::expand_grid(code = base::unname(codes), payer_type = payer_multiplier_payers()) |>
    dplyr::mutate(
      concept = "x", fee_type = "professional",
      n_hospitals = base::ifelse(.data$payer_type == "medicaid", 50L, 60L),
      median_ratio = base::ifelse(.data$payer_type == "medicaid", 0.8, 1.7) + bump + base::seq_along(.data$code) / 1000,
      p25_ratio = .data$median_ratio - 0.2,
      p75_ratio = .data$median_ratio + 0.3
    )
  # a facility row for the same code must be ignored
  ratios <- dplyr::bind_rows(ratios, dplyr::mutate(ratios[1, ], fee_type = "facility", median_ratio = 9))
  if (!base::is.null(drop_code)) {
    ratios <- ratios |> dplyr::filter(!(.data$code == drop_code & .data$payer_type == "commercial" & .data$fee_type == "professional"))
  }
  path <- base::file.path(dir, "payer_to_medicare_ratios.csv")
  readr::write_csv(ratios, path)
  path
}

temp_params <- function(dir, crlf = FALSE) {
  path <- base::file.path(dir, "model_parameters.csv")
  base::file.copy(base::file.path(repo_root_path(), "config/model_parameters.csv"), path)
  if (crlf) {
    raw <- base::readChar(path, base::file.info(path)$size, useBytes = TRUE)
    con <- base::file(path, open = "wb")
    base::writeChar(base::gsub("\n", "\r\n", raw, fixed = TRUE), con, eos = NULL, useBytes = TRUE)
    base::close(con)
  }
  path
}

read_lines_raw <- function(path) {
  raw <- base::readChar(path, base::file.info(path)$size, useBytes = TRUE)
  base::strsplit(raw, "\r?\n")[[1]]
}

test_that("refresh copies each ratio into its row and leaves every other line byte-identical", {
  dir <- base::tempfile("refresh")
  base::dir.create(dir)
  params <- temp_params(dir)
  before <- read_lines_raw(params)

  report <- refresh_payer_multipliers(params, synthetic_payer_ratios(dir), "abc1234")
  after <- read_lines_raw(params)

  expect_equal(base::nrow(report), 8)
  expect_true(base::all(report$changed))
  is_multiplier <- base::startsWith(before, "payer_multiplier_")
  expect_equal(base::sum(is_multiplier), 8)
  expect_identical(after[!is_multiplier], before[!is_multiplier])

  updated <- load_model_parameters(params)
  expected <- 0.8 + base::match("58120", base::unname(payer_multiplier_codes())) * 2 / 1000 - 1 / 1000
  row <- updated[updated$parameter == "payer_multiplier_medicaid_dc_professional_cost", ]
  expect_equal(base::as.numeric(row$base_value), base::round(expected, 3))
  expect_equal(base::as.numeric(row$low_value), base::round(expected - 0.2, 3))
  expect_equal(base::as.numeric(row$high_value), base::round(expected + 0.3, 3))
  expect_match(row$source, "hpt_prices @ abc1234")
  expect_match(row$notes, "Median across 50 hospitals")
  # the facility row for the same code was not used
  expect_false(base::any(base::as.numeric(updated$base_value[base::startsWith(updated$parameter, "payer_multiplier_")]) > 5))
})

test_that("dry run reports the changes and writes nothing", {
  dir <- base::tempfile("refresh")
  base::dir.create(dir)
  params <- temp_params(dir)
  bytes_before <- base::readBin(params, "raw", base::file.info(params)$size)

  report <- refresh_payer_multipliers(params, synthetic_payer_ratios(dir), "abc1234", dry_run = TRUE)

  expect_true(base::all(report$changed))
  expect_identical(base::readBin(params, "raw", base::file.info(params)$size), bytes_before)
})

test_that("unchanged ratios and commit leave the file byte-identical", {
  dir <- base::tempfile("refresh")
  base::dir.create(dir)
  params <- temp_params(dir)
  ratios <- synthetic_payer_ratios(dir)
  refresh_payer_multipliers(params, ratios, "abc1234")
  bytes_once <- base::readBin(params, "raw", base::file.info(params)$size)

  report <- refresh_payer_multipliers(params, ratios, "abc1234")

  expect_false(base::any(report$changed))
  expect_identical(base::readBin(params, "raw", base::file.info(params)$size), bytes_once)
})

test_that("CRLF line endings survive a refresh", {
  dir <- base::tempfile("refresh")
  base::dir.create(dir)
  params <- temp_params(dir, crlf = TRUE)

  refresh_payer_multipliers(params, synthetic_payer_ratios(dir), "abc1234")
  raw <- base::readChar(params, base::file.info(params)$size, useBytes = TRUE)

  expect_false(base::grepl("[^\r]\n", raw))
  expect_true(base::endsWith(raw, "\r\n"))
})

test_that("a missing ratio or a bad commit fails before anything is written", {
  dir <- base::tempfile("refresh")
  base::dir.create(dir)
  params <- temp_params(dir)
  bytes_before <- base::readBin(params, "raw", base::file.info(params)$size)

  expect_error(refresh_payer_multipliers(params, synthetic_payer_ratios(dir, drop_code = "88305"), "abc1234"),
               "No usable professional commercial ratio for CPT 88305")
  expect_error(refresh_payer_multipliers(params, synthetic_payer_ratios(dir), "not-a-commit"), "hpt_commit")
  expect_error(refresh_payer_multipliers(params, base::file.path(dir, "absent.csv"), "abc1234"), "not found")
  expect_identical(base::readBin(params, "raw", base::file.info(params)$size), bytes_before)
})
