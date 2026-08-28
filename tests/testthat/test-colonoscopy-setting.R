testthat::test_that("colonoscopy codes include screening HCPCS", {

  codes <- colonoscopy_setting_codes()

  testthat::expect_true("45378" %in% codes)
  testthat::expect_true("45380" %in% codes)
  testthat::expect_true("45385" %in% codes)
  testthat::expect_true("G0105" %in% codes)
  testthat::expect_true("G0121" %in% codes)
})

testthat::test_that("RUCA codes classify into four groups", {

  groups <- classify_ruca_group(
    base::c(1, 4, 7, 10, NA_real_)
  )

  testthat::expect_equal(
    groups,
    base::c(
      "Metropolitan",
      "Micropolitan",
      "Small town",
      "Rural",
      "Unknown"
    )
  )
})

testthat::test_that("ASC suppliers are separated from professionals", {

  physician_tbl <- tibble::tribble(
    ~Rndrng_NPI, ~Rndrng_Prvdr_Type, ~HCPCS_Cd,
    ~Place_Of_Srvc, ~Tot_Srvcs, ~Tot_Benes,
    ~Tot_Bene_Day_Srvcs,
    ~Avg_Mdcr_Alowd_Amt, ~Avg_Mdcr_Pymt_Amt,
    ~Rndrng_Prvdr_State_Abrvtn, ~Rndrng_Prvdr_Zip5,
    ~Rndrng_Prvdr_RUCA, ~Rndrng_Prvdr_RUCA_Desc,
    "1", "Gastroenterology", "45378",
    "F", 100, 90, 90, 200, 150, "CO", "80204", 1,
    "Metropolitan area core: primary flow within an urbanized area",
    "2", "Ambulatory Surgical Center", "45378",
    "F", 100, 90, 90, 450, 360, "CO", "80204", 1,
    "Metropolitan area core: primary flow within an urbanized area"
  )

  standardized_tbl <- standardize_physician_colonoscopy(
    physician_tbl,
    data_year = 2023L
  )

  testthat::expect_equal(
    standardized_tbl$claim_role,
    base::c("professional", "asc_facility")
  )
})

testthat::test_that("facility share excludes ASC facility rows", {

  standardized_tbl <- tibble::tribble(
    ~year, ~claim_role, ~place_group, ~services,
    ~allowed_amount, ~provider_npi, ~state,
    2023L, "professional", "Facility", 75, 200, "1", "CO",
    2023L, "professional", "Nonfacility", 25, 150, "2", "CO",
    2023L, "asc_facility", "Facility", 75, 400, "3", "CO"
  )

  setting_tbl <- summarize_colonoscopy_place(
    standardized_tbl
  )

  facility_share <- setting_tbl |>
    dplyr::filter(.data$place_group == "Facility") |>
    dplyr::pull(.data$service_share)

  testthat::expect_equal(facility_share, 0.75)
})

testthat::test_that("setting decomposition avoids claiming HOPD", {

  physician_tbl <- tibble::tribble(
    ~year, ~claim_role, ~place_group, ~services,
    ~provider_npi, ~state,
    2023L, "professional", "Nonfacility", 20, "1", "CO",
    2023L, "professional", "Facility", 80, "2", "CO",
    2023L, "asc_facility", "Facility", 50, "3", "CO"
  )

  setting_tbl <- decompose_colonoscopy_observed_settings(
    physician_tbl,
    data_year = 2023L
  )

  testthat::expect_equal(
    setting_tbl$observed_services,
    base::c(20, 50, 30)
  )

  testthat::expect_equal(
    setting_tbl$setting,
    base::c(
      "Office/nonfacility",
      "ASC",
      "Other facility residual"
    )
  )
})

testthat::test_that("weighted cost summary reports mean SD median quartiles", {

  standardized_tbl <- tibble::tribble(
    ~year, ~claim_role, ~place_group, ~services,
    ~allowed_amount, ~provider_npi, ~state,
    2023L, "professional", "Facility", 10, 100, "1", "CO",
    2023L, "professional", "Facility", 30, 200, "2", "CO"
  )

  cost_tbl <- summarize_colonoscopy_allowed(
    standardized_tbl
  )

  testthat::expect_equal(
    cost_tbl$weighted_mean_allowed[[1]],
    175
  )

  testthat::expect_true(
    base::all(
      base::c(
        "weighted_sd_allowed",
        "median_allowed",
        "p25_allowed",
        "p75_allowed"
      ) %in% base::names(cost_tbl)
    )
  )
})

testthat::test_that("trend sentence reports years direction and p-value", {

  trend_tbl <- tibble::tibble(
    first_year = 2019L,
    last_year = 2024L,
    first_share = 0.70,
    last_share = 0.80,
    annual_change_pp = 2,
    p_value = 0.002
  )

  sentence <- format_colonoscopy_trend_sentence(trend_tbl)

  testthat::expect_match(sentence, "2019")
  testthat::expect_match(sentence, "2024")
  testthat::expect_match(sentence, "increased")
  testthat::expect_match(sentence, "p = 0.002")
})

testthat::test_that("latest cache path selects newest timestamp", {

  cache_dir <- base::tempfile("cms_cache_")
  base::dir.create(cache_dir)
  old_path <- base::file.path(
    cache_dir,
    "cms_colonoscopy_2024_20260101_010101.csv"
  )
  new_path <- base::file.path(
    cache_dir,
    "cms_colonoscopy_2024_20260201_010101.csv"
  )
  base::writeLines("x", old_path)
  base::writeLines("x", new_path)

  selected <- latest_colonoscopy_cache_path(
    cache_dir,
    data_year = 2024L
  )

  testthat::expect_equal(selected, new_path)
})
