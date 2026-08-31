test_that("PFS geographic multiplier applies work PE and MP GPCIs", {
  multiplier <- compute_pfs_geographic_multiplier(
    work_rvu = 2,
    pe_rvu = 3,
    mp_rvu = 1,
    gpci_work = 1.10,
    gpci_pe = 1.20,
    gpci_mp = 0.90
  )
  expected_multiplier <- (2 * 1.10 + 3 * 1.20 + 1 * 0.90) / (2 + 3 + 1)
  expect_equal(multiplier, expected_multiplier)
})

test_that("national GPCI values preserve the national PFS payment", {
  multiplier <- compute_pfs_geographic_multiplier(
    work_rvu = 2, pe_rvu = 3, mp_rvu = 1,
    gpci_work = 1, gpci_pe = 1, gpci_mp = 1
  )
  expect_equal(multiplier, 1)
})

test_that("compute_pfs_geographic_multiplier rejects negative or non-finite inputs", {
  expect_error(
    compute_pfs_geographic_multiplier(
      work_rvu = -1, pe_rvu = 3, mp_rvu = 1,
      gpci_work = 1, gpci_pe = 1, gpci_mp = 1
    ),
    "cannot be negative"
  )
  expect_error(
    compute_pfs_geographic_multiplier(
      work_rvu = NA_real_, pe_rvu = 3, mp_rvu = 1,
      gpci_work = 1, gpci_pe = 1, gpci_mp = 1
    ),
    "finite"
  )
})

test_that("facility wage index adjusts only the labor share", {
  multiplier <- compute_facility_geographic_multiplier(
    wage_index = 1.20,
    labor_share = 0.60
  )
  expect_equal(multiplier, 1.12)
})

test_that("national facility wage index preserves national payment", {
  multiplier <- compute_facility_geographic_multiplier(
    wage_index = 1,
    labor_share = 0.60
  )
  expect_equal(multiplier, 1)
})

test_that("geographic inputs cannot adjust the same parameter twice", {
  locality_indices <- tibble::tibble(
    locality_id = "national",
    locality_label = "National",
    gpci_work = 1, gpci_pe = 1, gpci_mp = 1,
    opps_wage_index = 1
  )
  pfs_rvus <- tibble::tibble(
    cpt = "58120", setting = "facility",
    work_rvu = 2, pe_rvu = 2, mp_rvu = 1
  )
  professional_mapping <- tibble::tibble(
    parameter = "dc_professional_cost", cpt = "58120", setting = "facility"
  )
  facility_mapping <- tibble::tibble(
    parameter = "dc_professional_cost", index_column = "opps_wage_index", labor_share = 0.60
  )

  expect_error(
    validate_geographic_inputs(
      locality_indices = locality_indices,
      pfs_rvus = pfs_rvus,
      professional_mapping = professional_mapping,
      facility_mapping = facility_mapping
    ),
    "more than one geographic adjustment"
  )
})

test_that("validate_geographic_inputs rejects duplicate locality_id and unknown wage-index columns", {
  duplicated_localities <- tibble::tibble(
    locality_id = c("national", "national"),
    locality_label = c("National", "National (dup)"),
    gpci_work = 1, gpci_pe = 1, gpci_mp = 1
  )
  empty_pfs_rvus <- tibble::tibble(
    cpt = character(), setting = character(),
    work_rvu = double(), pe_rvu = double(), mp_rvu = double()
  )
  empty_professional_mapping <- tibble::tibble(
    parameter = character(), cpt = character(), setting = character()
  )
  empty_facility_mapping <- tibble::tibble(
    parameter = character(), index_column = character(), labor_share = double()
  )

  expect_error(
    validate_geographic_inputs(
      locality_indices = duplicated_localities,
      pfs_rvus = empty_pfs_rvus,
      professional_mapping = empty_professional_mapping,
      facility_mapping = empty_facility_mapping
    ),
    "locality_id must be unique"
  )

  locality_indices <- tibble::tibble(
    locality_id = "national", locality_label = "National",
    gpci_work = 1, gpci_pe = 1, gpci_mp = 1
  )
  facility_mapping_bad_column <- tibble::tibble(
    parameter = "dc_professional_cost",
    index_column = "not_a_real_column",
    labor_share = 0.60
  )
  expect_error(
    validate_geographic_inputs(
      locality_indices = locality_indices,
      pfs_rvus = empty_pfs_rvus,
      professional_mapping = empty_professional_mapping,
      facility_mapping = facility_mapping_bad_column
    ),
    "Unknown facility wage-index"
  )
})

test_that("national locality produces identity overrides", {
  model_parameters <- test_model_parameters()

  locality_indices <- tibble::tibble(
    locality_id = "national",
    locality_label = "National",
    gpci_work = 1, gpci_pe = 1, gpci_mp = 1,
    opps_wage_index = 1
  )
  pfs_rvus <- tibble::tibble(
    cpt = "58100", setting = "nonfacility",
    work_rvu = 1, pe_rvu = 2, mp_rvu = 0.1
  )
  professional_mapping <- tibble::tibble(
    parameter = "emb_office_professional_cost", cpt = "58100", setting = "nonfacility"
  )
  facility_mapping <- tibble::tibble(
    parameter = character(), index_column = character(), labor_share = double()
  )

  geographic_bundle <- build_geographic_overrides(
    model_parameters = model_parameters,
    locality_id = "national",
    locality_indices = locality_indices,
    pfs_rvus = pfs_rvus,
    professional_mapping = professional_mapping,
    facility_mapping = facility_mapping
  )

  national_value <- get_parameter_value(model_parameters, "emb_office_professional_cost")
  expect_equal(geographic_bundle$overrides$emb_office_professional_cost, national_value)
})

test_that("run_geographic_sensitivity with the real CMS locality/RVU tables reproduces the base case at the national row", {
  # INDEPENDENT-CONFIRMATION-flavored check on the real, shipped geographic
  # inputs (data/cms_geographic_indices_2026.csv, data/cms_pfs_rvus_2026.csv):
  # the national row's GPCIs and wage index are all 1.0 by construction, so
  # this run must reproduce compute_strategy_costs()'s own base-case output
  # exactly -- see R/geographic_sensitivity.R's docblock and this project's
  # meta-rule that any new finding capable of changing the study's frame gets
  # checked against an independent path before being trusted.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  locality_indices <- readr::read_csv(
    file.path(repo_root_path(), "data/cms_geographic_indices_2026.csv"),
    show_col_types = FALSE
  )
  pfs_rvus <- readr::read_csv(
    file.path(repo_root_path(), "data/cms_pfs_rvus_2026.csv"),
    show_col_types = FALSE
  )
  professional_mapping <- tibble::tribble(
    ~parameter, ~cpt, ~setting,
    "emb_office_professional_cost", "58100", "nonfacility",
    "emb_office_professional_cost_facility", "58100", "facility",
    "dc_professional_cost", "58120", "facility"
  )
  facility_mapping <- tibble::tribble(
    ~parameter, ~index_column, ~labor_share,
    "dnc_facility_or_asc_fee", "opps_wage_index", 0.60
  )

  geographic_analysis <- run_geographic_sensitivity(
    model_parameters = model_parameters,
    locality_indices = locality_indices,
    pfs_rvus = pfs_rvus,
    professional_mapping = professional_mapping,
    facility_mapping = facility_mapping,
    price_index_table = price_index_table
  )

  national_costs <- geographic_analysis$strategy_costs %>%
    dplyr::filter(.data$locality_id == "national")
  base_case_costs <- compute_strategy_costs(model_parameters, price_index_table)$strategy_costs

  merged <- dplyr::inner_join(
    national_costs, base_case_costs,
    by = "strategy", suffix = c("_geo", "_base")
  )
  expect_equal(nrow(merged), 3)
  expect_equal(merged$expected_total_cost_geo, merged$expected_total_cost_base, tolerance = 1e-6)

  # And a real, non-trivial check: the high-cost locality must cost more
  # than the low-cost locality for every strategy.
  high_cost <- geographic_analysis$strategy_costs %>% dplyr::filter(.data$locality_id == "high_cost")
  low_cost <- geographic_analysis$strategy_costs %>% dplyr::filter(.data$locality_id == "low_cost")
  merged_extremes <- dplyr::inner_join(
    high_cost, low_cost, by = "strategy", suffix = c("_high", "_low")
  )
  expect_true(all(merged_extremes$expected_total_cost_high > merged_extremes$expected_total_cost_low))
})
