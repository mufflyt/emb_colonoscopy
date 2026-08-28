testthat::test_that("normalize_cms_hospital_frame_names renames the real 'City/Town' -> 'city_town' collision to 'citytown'", {
  # Regression test for a bug caught only by running against a live CMS
  # download (2026-08-28): the real "City/Town" header normalizes to
  # "city_town", not "citytown" as every downstream function and this
  # file's own synthetic test fixtures assumed. See
  # normalize_cms_hospital_frame_names()'s docstring.
  raw_tbl <- tibble::tibble(
    `Facility ID` = "010001",
    `Facility Name` = "Test Hospital",
    `City/Town` = "Dothan",
    `State` = "AL",
    `Hospital Type` = "Acute Care Hospitals",
    `Hospital Ownership` = "Voluntary non-profit - Private"
  )

  normalized_tbl <- normalize_cms_hospital_frame_names(raw_tbl)

  expect_true("citytown" %in% names(normalized_tbl))
  expect_false("city_town" %in% names(normalized_tbl))
  expect_equal(normalized_tbl$citytown, "Dothan")
})

testthat::test_that("normalize_cms_hospital_frame_names is a no-op when 'citytown' is already correct", {
  already_correct_tbl <- tibble::tibble(citytown = "Dothan", state = "AL")
  expect_equal(
    normalize_cms_hospital_frame_names(already_correct_tbl),
    already_correct_tbl
  )
})

testthat::test_that("MEPS column validation accepts required fields", {

  office_tbl <- tibble::tibble(
    DUPERSID = "1",
    OBXP24X = 100,
    OBSF24X = 10,
    PERWT24F = 1,
    VARSTR = 1,
    VARPSU = 1
  )

  jobs_tbl <- tibble::tibble(
    DUPERSID = "1",
    HRLYWAGE = 25,
    PERWT24F = 1,
    VARSTR = 1,
    VARPSU = 1
  )

  testthat::expect_true(
    validate_meps_columns(office_tbl, "office")
  )

  testthat::expect_true(
    validate_meps_columns(jobs_tbl, "jobs")
  )
})

testthat::test_that("MEPS validation rejects missing fields", {

  office_tbl <- tibble::tibble(
    DUPERSID = "1",
    OBXP24X = 100
  )

  testthat::expect_error(
    validate_meps_columns(office_tbl, "office"),
    "missing required columns"
  )
})

testthat::test_that("HPT text parser handles multiple locations", {

  hpt_text <- base::paste(
    "location-name: Alpha Hospital",
    "source-page-url: https://alpha.org/prices",
    "mrf-url: https://alpha.org/a.csv",
    "contact-name: Test One",
    "contact-email: one@example.org",
    "location-name: Beta Hospital",
    "source-page-url: https://alpha.org/beta-prices",
    "mrf-url: https://alpha.org/b.json",
    "contact-name: Test Two",
    "contact-email: two@example.org",
    sep = "\n"
  )

  parsed_tbl <- parse_cms_hpt_text(hpt_text)

  testthat::expect_equal(base::nrow(parsed_tbl), 2L)
  testthat::expect_equal(
    parsed_tbl$location_name,
    base::c("Alpha Hospital", "Beta Hospital")
  )
  testthat::expect_equal(
    parsed_tbl$mrf_url,
    base::c("https://alpha.org/a.csv", "https://alpha.org/b.json")
  )
})

testthat::test_that("domain normalization strips scheme and path", {

  testthat::expect_equal(
    normalize_hpt_domain("https://www.alpha.org/prices/"),
    "www.alpha.org"
  )

  testthat::expect_equal(
    normalize_hpt_domain("beta.org"),
    "beta.org"
  )
})

testthat::test_that("hospital strata use Census region and ownership", {

  hospital_tbl <- tibble::tribble(
    ~facility_id, ~facility_name, ~state,
    ~hospital_type, ~hospital_ownership,
    "1", "A", "MA", "Acute Care Hospitals",
    "Voluntary non-profit - Private",
    "2", "B", "IL", "Acute Care Hospitals",
    "Proprietary",
    "3", "C", "TX", "Acute Care Hospitals",
    "Government - Local",
    "4", "D", "CA", "Acute Care Hospitals",
    "Proprietary"
  )

  stratified_tbl <- classify_hpt_hospitals(hospital_tbl)

  testthat::expect_equal(
    stratified_tbl$census_region,
    base::c("Northeast", "Midwest", "South", "West")
  )

  testthat::expect_equal(
    stratified_tbl$ownership_group,
    base::c("nonprofit", "for_profit", "government", "for_profit")
  )
})

testthat::test_that("hospital sampling is deterministic and balanced", {

  regions <- base::c("Northeast", "Midwest", "South", "West")
  owners <- base::c("government", "nonprofit", "for_profit")

  hospital_tbl <- tidyr::crossing(
    census_region = regions,
    ownership_group = owners,
    row_id = base::seq_len(4L)
  ) |>
    dplyr::mutate(
      facility_id = base::sprintf("%06d", dplyr::row_number()),
      facility_name = base::paste0("Hospital ", .data$facility_id),
      citytown = "Test City",
      state = dplyr::case_when(
        .data$census_region == "Northeast" ~ "MA",
        .data$census_region == "Midwest" ~ "IL",
        .data$census_region == "South" ~ "TX",
        TRUE ~ "CA"
      ),
      hospital_type = "Acute Care Hospitals",
      hospital_ownership = dplyr::case_when(
        .data$ownership_group == "government" ~
          "Government - Local",
        .data$ownership_group == "nonprofit" ~
          "Voluntary non-profit - Private",
        TRUE ~ "Proprietary"
      )
    )

  sample_a <- sample_hpt_hospitals(
    hospital_tbl,
    per_stratum = 2L,
    seed = 20260828L
  )

  sample_b <- sample_hpt_hospitals(
    hospital_tbl,
    per_stratum = 2L,
    seed = 20260828L
  )

  testthat::expect_equal(sample_a, sample_b)
  testthat::expect_equal(base::nrow(sample_a), 24L)

  counts_tbl <- sample_a |>
    dplyr::count(
      .data$census_region,
      .data$ownership_group
    )

  testthat::expect_true(base::all(counts_tbl$n == 2L))
})

testthat::test_that("public-input config writes expected variables", {

  config_path <- base::tempfile(fileext = ".R")

  write_public_input_config(
    office_xlsx = "/tmp/office.xlsx",
    jobs_xlsx = "/tmp/jobs.xlsx",
    hpt_manifest = "/tmp/hpt.csv",
    path = config_path
  )

  config_text <- base::paste(base::readLines(config_path), collapse = "\n")

  testthat::expect_match(config_text, "MEPS_OFFICE_XLSX")
  testthat::expect_match(config_text, "MEPS_JOBS_XLSX")
  testthat::expect_match(config_text, "HPT_MRF_MANIFEST")
})


testthat::test_that("historical HPT index yields domain hints", {

  link_tbl <- tibble::tibble(
    ccn = base::c("010001", "010002"),
    machine_readable_page = base::c(
      "https://alpha.org/prices",
      NA_character_
    ),
    supplemental_url = base::c(
      NA_character_,
      "https://www.beta.org/billing"
    ),
    machine_readable_url = base::c(
      "https://vendor.example/a.csv",
      "https://vendor.example/b.csv"
    )
  )

  hint_tbl <- build_hpt_domain_hints(link_tbl)

  testthat::expect_equal(
    hint_tbl$website_domain,
    base::c("alpha.org", "www.beta.org")
  )
})

testthat::test_that("HPT header detection finds charge table", {

  lines <- base::c(
    "hospital_name,last_updated_on,version",
    "Example,2026-01-01,3.0.0",
    "description,code|1,code|1|type,code|2,code|2|type"
  )

  testthat::expect_equal(
    detect_hpt_charge_header(lines),
    3L
  )
})

testthat::test_that("tall HPT parser finds CPT in second code slot", {

  hpt_tbl <- tibble::tibble(
    description = "Endometrial biopsy",
    `code | 1` = "999",
    `code | 1 | type` = "RC",
    `code | 2` = "58100",
    `code | 2 | type` = "CPT",
    payer_name = "Example Payer",
    plan_name = "PPO",
    `standard_charge | negotiated_dollar` = "125",
    median_amount = NA_character_,
    `10th_percentile` = NA_character_,
    `90th_percentile` = NA_character_
  )

  price_tbl <- extract_hpt_sampling_prices(
    hpt_tbl,
    codes = "58100"
  )

  testthat::expect_equal(price_tbl$code, "58100")
  testthat::expect_equal(price_tbl$negotiated_dollar, 125)
})

testthat::test_that("wide HPT parser pivots payer columns", {

  hpt_tbl <- tibble::tibble(
    description = "Endometrial biopsy",
    `code|1` = "58100",
    `code|1|type` = "CPT",
    `standard_charge|Alpha|PPO|negotiated_dollar` = "140",
    `median_amount|Alpha|PPO` = NA_character_,
    `10th_percentile|Alpha|PPO` = NA_character_,
    `90th_percentile|Alpha|PPO` = NA_character_,
    `standard_charge|Beta|HMO|negotiated_dollar` = "110",
    `median_amount|Beta|HMO` = NA_character_,
    `10th_percentile|Beta|HMO` = NA_character_,
    `90th_percentile|Beta|HMO` = NA_character_
  )

  price_tbl <- extract_hpt_sampling_prices(
    hpt_tbl,
    codes = "58100"
  )

  testthat::expect_equal(base::nrow(price_tbl), 2L)
  testthat::expect_setequal(
    price_tbl$negotiated_dollar,
    base::c(140, 110)
  )
})

testthat::test_that("CMS resolver selects latest requested year", {

  catalog_payload <- base::list(
    dataset = base::list(
      base::list(
        title = base::paste(
          "Medicare Physician & Other Practitioners -",
          "by Provider and Service"
        ),
        distribution = base::list(
          base::list(
            title = "Provider and Service : 2024-12-01",
            format = "API",
            description = "latest",
            accessURL = base::paste0(
              "https://data.cms.gov/data-api/v1/dataset/",
              "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/data"
            )
          ),
          base::list(
            title = "Provider and Service : 2023-12-31",
            format = "API",
            accessURL = base::paste0(
              "https://data.cms.gov/data-api/v1/dataset/",
              "11111111-2222-3333-4444-555555555555/data"
            )
          )
        )
      )
    )
  )

  version_uuid <- cms_resolve_version_uuid(
    catalog_payload,
    title_pattern = "Physician.*Provider and Service",
    data_year = 2024L
  )

  testthat::expect_equal(
    version_uuid,
    "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  )
})
