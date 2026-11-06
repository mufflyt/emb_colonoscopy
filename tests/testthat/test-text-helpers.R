#' Tests for the pure string, CSV, and classification helpers
#'
#' None of these had a test before this file. They are low-glamour
#' functions, but two of them rewrite `config/model_parameters.csv` in
#' place (`csv_line_fields()` / `csv_line_join()`, via
#' `refresh_payer_multipliers()`), and that file's `notes` and `source`
#' fields contain embedded commas, quotes, and parentheses. A round-trip
#' bug there would silently corrupt the parameter table that every
#' published number depends on, which is why the round-trip is checked
#' against the real file rather than a toy fixture.

# ---- CSV line round-trip -------------------------------------------------

test_that("csv_line_join and csv_line_fields round-trip adversarial fields", {
  cases <- list(
    c("plain", "fields", "here"),
    c("has,comma", "plain"),
    c('has"quote', "plain"),
    c('both,"kinds"', "plain"),
    c("", "empty first"),
    c("trailing space ", " leading space"),
    c("parens (like this)", "and -- dashes"),
    c("a very long note field with, several commas, and \"quoted phrases\" inside it", "x")
  )
  for (fields in cases) {
    expect_equal(
      csv_line_fields(csv_line_join(fields), n_fields = length(fields)),
      fields,
      info = paste(fields, collapse = " | ")
    )
  }
})

test_that("csv_line_join quotes only the fields that need it", {
  expect_equal(csv_line_join(c("a", "b")), "a,b")
  expect_equal(csv_line_join(c("a,b", "c")), '"a,b",c')
  expect_equal(csv_line_join(c('a"b', "c")), '"a""b",c')
})

test_that("every row of the real model_parameters.csv survives a parse/join round-trip", {
  params_path <- file.path(repo_root_path(), "config/model_parameters.csv")
  testthat::skip_if_not(file.exists(params_path))
  raw <- readChar(params_path, file.info(params_path)$size, useBytes = TRUE)
  lines <- strsplit(raw, "\n", fixed = TRUE)[[1]]
  lines <- lines[nzchar(lines)]
  n_fields <- length(csv_line_fields(lines[[1]]))

  # A row whose notes field contains a newline would span multiple physical
  # lines; those are skipped here because the helper is line-oriented by
  # design, and refresh_payer_multipliers() only rewrites single-line rows.
  single_line_rows <- 0L
  for (line in lines) {
    fields <- tryCatch(csv_line_fields(line, n_fields = n_fields), error = function(e) NULL)
    if (is.null(fields)) next
    single_line_rows <- single_line_rows + 1L
    expect_equal(csv_line_fields(csv_line_join(fields), n_fields = n_fields), fields)
  }
  # Guard the guard: if parsing silently started failing for every row, the
  # loop above would assert nothing at all.
  expect_gt(single_line_rows, 60L)
})

test_that("csv_line_fields rejects a row with the wrong field count", {
  expect_error(csv_line_fields("a,b,c", n_fields = 5))
})

# ---- quote_r_string ------------------------------------------------------

test_that("quote_r_string produces a string that R itself parses back", {
  for (value in c("plain", "has \"quotes\"", "has\\backslash", "tab\there", "")) {
    quoted <- quote_r_string(value)
    expect_equal(eval(parse(text = quoted)), value, info = value)
  }
})

# ---- Number formatting ---------------------------------------------------

test_that("format_cost renders whole dollars with a thousands separator", {
  expect_equal(format_cost(1234.56), "$1,235")
  expect_equal(format_cost(0), "$0")
  expect_equal(format_cost(-250), "-$250")
})

test_that("format_percent renders a 0-1 proportion to one decimal place", {
  expect_equal(format_percent(0.123), "12.3%")
  expect_equal(format_percent(1), "100.0%")
  expect_equal(format_percent(0), "0.0%")
})

# ---- Census region classification ---------------------------------------

test_that("census_region_from_state classifies all 50 states plus DC", {
  all_jurisdictions <- c(datasets::state.abb, "DC")
  expect_length(all_jurisdictions, 51L)
  regions <- census_region_from_state(all_jurisdictions)
  expect_false(any(is.na(regions)))
})

test_that("census_region_from_state matches the official Census region sizes", {
  # Census Bureau: Northeast 9, Midwest 12, South 17 (incl. DC), West 13.
  regions <- census_region_from_state(c(datasets::state.abb, "DC"))
  counts <- table(regions)
  expect_equal(as.integer(counts[["Northeast"]]), 9L)
  expect_equal(as.integer(counts[["Midwest"]]), 12L)
  expect_equal(as.integer(counts[["South"]]), 17L)
  expect_equal(as.integer(counts[["West"]]), 13L)
})

test_that("census_region_from_state returns NA for a non-state code", {
  expect_true(is.na(census_region_from_state("PR")))
  expect_true(is.na(census_region_from_state("ZZ")))
  # The repository's own four sensitivity localities must all resolve.
  expect_equal(census_region_from_state(c("CO", "AR", "NY", "MS")),
               c("West", "South", "Northeast", "South"))
})

# ---- Hospital name matching ---------------------------------------------

test_that("normalize_hospital_name upper-cases, strips punctuation, and squishes space", {
  expect_equal(normalize_hospital_name("St. Joseph's  Hospital-East"), "ST JOSEPH S HOSPITAL EAST")
  expect_equal(normalize_hospital_name("  UCHealth   "), "UCHEALTH")
})

test_that("hospital_name_tokens drops the generic words that would inflate similarity", {
  expect_equal(hospital_name_tokens("Denver Health Medical Center"), "DENVER")
  expect_equal(hospital_name_tokens("The Hospital of the University"), "UNIVERSITY")
})

test_that("hospital_name_score is a Jaccard index: 1 on self, 0 on disjoint, symmetric", {
  expect_equal(hospital_name_score("Denver Health Medical Center", "Denver Health Medical Center"), 1)
  expect_equal(hospital_name_score("Denver Health", "Emory University"), 0)
  expect_equal(
    hospital_name_score("Emory University Hospital", "Denver Health Medical Center"),
    hospital_name_score("Denver Health Medical Center", "Emory University Hospital")
  )
})

test_that("hospital_name_score sees through punctuation and generic-word differences", {
  # After stop-word removal the first name is {DENVER} and the second is
  # {DENVER, INC}, so the Jaccard index is 1/2 -- the corporate suffix is the
  # only thing keeping these from matching exactly.
  expect_equal(
    hospital_name_score("Denver Health Medical Center", "DENVER HEALTH MEDICAL CENTER, INC"),
    0.5
  )
  expect_gt(hospital_name_score("UCHealth University of Colorado Hospital",
                                "University of Colorado Hospital"), 0.5)
})

test_that("hospital_name_score returns 0 rather than NaN when both names are all stop words", {
  expect_equal(hospital_name_score("The Hospital", "Medical Center"), 0)
})

# ---- URL helpers ---------------------------------------------------------

test_that("extract_url_hostname lower-cases the host and ignores path, port, query, and fragment", {
  expect_equal(extract_url_hostname("https://Example.COM/a/b?c=d#e"), "example.com")
  expect_equal(extract_url_hostname("http://example.com:8080/x"), "example.com")
  expect_equal(extract_url_hostname("https://oria-data.trillianthealth.com/"), "oria-data.trillianthealth.com")
})

test_that("extract_url_hostname returns NA for blank, missing, or non-HTTP input", {
  expect_true(is.na(extract_url_hostname(NA_character_)))
  expect_true(is.na(extract_url_hostname("")))
  expect_true(is.na(extract_url_hostname("ftp://example.com/x")))
  expect_true(is.na(extract_url_hostname("example.com/no-scheme")))
})

test_that("infer_mrf_format reads the extension, not the query string", {
  expect_equal(infer_mrf_format("https://h.org/prices.csv"), "csv")
  expect_equal(infer_mrf_format("https://h.org/prices.JSON"), "json")
  # A query string or fragment after the extension must not hide it.
  expect_equal(infer_mrf_format("https://h.org/prices.csv?token=abc"), "csv")
  expect_equal(infer_mrf_format("https://h.org/prices.json#top"), "json")
  # And a bare extension-looking segment mid-path must not be mistaken for one.
  expect_equal(infer_mrf_format("https://h.org/csv/download"), "unknown")
  expect_equal(infer_mrf_format("https://h.org/prices.xlsx"), "unknown")
})
