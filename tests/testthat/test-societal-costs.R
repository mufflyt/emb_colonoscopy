test_that("compute_strategy_expected_encounters returns one row per strategy with dnc fixed at 2", {
  model_parameters <- test_model_parameters()
  encounters <- compute_strategy_expected_encounters(model_parameters)

  expect_equal(nrow(encounters), 3)
  expect_setequal(encounters$strategy, c("office_emb", "combined_emb", "dnc"))
  expect_equal(encounters$expected_encounters[encounters$strategy == "dnc"], 2)
  expect_true(all(encounters$expected_encounters > 0))
})

test_that("INDEPENDENT CONFIRMATION: office/combined expected encounters match a directly re-derived formula", {
  # Meta-rule (docs/testing_philosophy.md, Rule 2): re-derive via a path
  # that never calls compute_strategy_expected_encounters() itself.
  model_parameters <- test_model_parameters()

  failure_probability <- get_parameter_value(model_parameters, "emb_failure_lynch")
  repeat_attempt_fraction <- get_parameter_value(model_parameters, "office_repeat_attempt_fraction")
  repeat_attempt_success_probability <- get_parameter_value(
    model_parameters, "office_repeat_attempt_success_probability"
  )
  combined_escalation_probability <- get_parameter_value(model_parameters, "combined_to_dnc_probability")
  requires_preop_visit <- get_parameter_value(
    model_parameters, "combined_requires_preop_office_visit", as_numeric = FALSE
  )

  independent_repeat_attempt_probability <- failure_probability * repeat_attempt_fraction
  independent_office_escalation <- failure_probability *
    (1 - repeat_attempt_fraction * repeat_attempt_success_probability)
  independent_office_encounters <- 1 + independent_repeat_attempt_probability * 1 +
    independent_office_escalation * 2
  independent_combined_encounters <- as.numeric(isTRUE(requires_preop_visit)) * 1 +
    combined_escalation_probability * 2

  pipeline_encounters <- compute_strategy_expected_encounters(model_parameters)

  expect_equal(
    pipeline_encounters$expected_encounters[pipeline_encounters$strategy == "office_emb"],
    independent_office_encounters,
    tolerance = 1e-9
  )
  expect_equal(
    pipeline_encounters$expected_encounters[pipeline_encounters$strategy == "combined_emb"],
    independent_combined_encounters,
    tolerance = 1e-9
  )
})

test_that("compute_strategy_expected_encounters' escalation-driven terms match compute_strategy_costs() exactly", {
  # Consistency guard, not a re-derivation: the societal-cost model and the
  # cost model must never silently diverge on how often a failed sample is
  # rescued to D&C -- same pattern as R/diagnostic_yield.R's equivalent test.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  cost_result <- compute_strategy_costs(model_parameters, price_index_table)
  encounters <- compute_strategy_expected_encounters(model_parameters)

  office_escalation_cost <- cost_result$strategy_costs$escalation_probability[
    cost_result$strategy_costs$strategy == "office_emb"
  ]
  office_encounters_expected <- 1 +
    get_parameter_value(model_parameters, "emb_failure_lynch") *
      get_parameter_value(model_parameters, "office_repeat_attempt_fraction") +
    office_escalation_cost * 2

  expect_equal(
    encounters$expected_encounters[encounters$strategy == "office_emb"],
    office_encounters_expected,
    tolerance = 1e-9
  )
})

test_that("MONOTONICITY: office EMB requires more expected patient encounters than combined EMB in the base case", {
  model_parameters <- test_model_parameters()
  encounters <- compute_strategy_expected_encounters(model_parameters)

  office_encounters <- encounters$expected_encounters[encounters$strategy == "office_emb"]
  combined_encounters <- encounters$expected_encounters[encounters$strategy == "combined_emb"]

  expect_true(office_encounters > combined_encounters)
})

test_that("SCENARIO: combined_requires_preop_office_visit = FALSE reduces combined EMB's expected encounters", {
  model_parameters <- test_model_parameters()
  scenario_parameters <- override_model_parameters(
    model_parameters, list(combined_requires_preop_office_visit = FALSE)
  )

  base_encounters <- compute_strategy_expected_encounters(model_parameters)
  scenario_encounters <- compute_strategy_expected_encounters(scenario_parameters)

  base_combined <- base_encounters$expected_encounters[base_encounters$strategy == "combined_emb"]
  scenario_combined <- scenario_encounters$expected_encounters[
    scenario_encounters$strategy == "combined_emb"
  ]

  expect_true(scenario_combined < base_combined)
  # Office EMB's encounters are untouched by this combined-arm-only toggle.
  expect_equal(
    base_encounters$expected_encounters[base_encounters$strategy == "office_emb"],
    scenario_encounters$expected_encounters[scenario_encounters$strategy == "office_emb"]
  )
})

test_that("compute_strategy_societal_costs returns valid, internally consistent columns", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  reference_year <- get_parameter_value(model_parameters, "reference_dollar_year")

  cost_result <- compute_strategy_costs(model_parameters, price_index_table)
  societal <- compute_strategy_societal_costs(
    model_parameters, cost_result$strategy_costs, all_items_price_index_table, reference_year
  )

  expect_equal(nrow(societal), 3)
  expect_setequal(societal$strategy, c("office_emb", "combined_emb", "dnc"))
  expect_true(all(societal$societal_addon > 0))
  expect_true(all(societal$patient_time_cost_per_encounter > 0))
  expect_equal(
    societal$societal_total_cost,
    societal$healthcare_sector_cost + societal$societal_addon,
    tolerance = 1e-9
  )
})

test_that("patient_time_cost_per_encounter is actually inflation-adjusted from 2010 to the reference year, not left at its raw base value", {
  # Guards against get_adjusted_cost_parameter() silently no-op'ing (e.g. a
  # dollar_year/reference_year mismatch, or a missing row in
  # data/cpi_all_items.csv for one of the two years) and quietly returning
  # the raw 2010 base_value ($43) instead of an inflated 2026 figure.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  reference_year <- get_parameter_value(model_parameters, "reference_dollar_year")

  cost_result <- compute_strategy_costs(model_parameters, price_index_table)
  societal <- compute_strategy_societal_costs(
    model_parameters, cost_result$strategy_costs, all_items_price_index_table, reference_year
  )

  raw_base_value <- get_parameter_value(
    model_parameters, "patient_time_opportunity_cost_per_visit"
  )
  adjusted_rate <- societal$patient_time_cost_per_encounter[[1]]

  expect_true(all(societal$patient_time_cost_per_encounter == adjusted_rate))
  expect_false(isTRUE(all.equal(adjusted_rate, raw_base_value)))
})

test_that("INDEPENDENT CONFIRMATION: patient_time_cost_per_encounter matches adjust_for_inflation() called directly", {
  # Meta-rule (docs/testing_philosophy.md, Rule 2): re-derive via a path
  # that never calls compute_strategy_societal_costs()/get_adjusted_cost_parameter().
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  reference_year <- get_parameter_value(model_parameters, "reference_dollar_year")

  raw_base_value <- get_parameter_value(
    model_parameters, "patient_time_opportunity_cost_per_visit"
  )
  parameter_row <- model_parameters[
    model_parameters$parameter == "patient_time_opportunity_cost_per_visit",
  ]
  independent_adjusted_rate <- adjust_for_inflation(
    cost_value = raw_base_value,
    source_year = parameter_row$dollar_year[[1]],
    reference_year = reference_year,
    price_index_table = all_items_price_index_table
  )

  cost_result <- compute_strategy_costs(model_parameters, price_index_table)
  societal <- compute_strategy_societal_costs(
    model_parameters, cost_result$strategy_costs, all_items_price_index_table, reference_year
  )

  expect_equal(
    societal$patient_time_cost_per_encounter[[1]], independent_adjusted_rate,
    tolerance = 1e-9
  )
  # And that independently-derived rate really is 2026 dollars, not 2010 --
  # the CPI-U ratio (332.813/218.056) is > 1, so the adjustment must raise
  # the value, not leave it unchanged or lower it.
  expect_true(independent_adjusted_rate > raw_base_value)
})

test_that("dnc's societal_addon equals exactly 2x the per-encounter opportunity cost", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  reference_year <- get_parameter_value(model_parameters, "reference_dollar_year")

  cost_result <- compute_strategy_costs(model_parameters, price_index_table)
  societal <- compute_strategy_societal_costs(
    model_parameters, cost_result$strategy_costs, all_items_price_index_table, reference_year
  )

  dnc_row <- societal[societal$strategy == "dnc", ]
  expect_equal(dnc_row$societal_addon, dnc_row$patient_time_cost_per_encounter * 2, tolerance = 1e-9)
})

test_that("MUTATION GUARD: zeroing patient_time_opportunity_cost_per_visit collapses every societal_addon to 0", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  reference_year <- get_parameter_value(model_parameters, "reference_dollar_year")

  zeroed_parameters <- override_model_parameters(
    model_parameters, list(patient_time_opportunity_cost_per_visit = 0)
  )
  cost_result <- compute_strategy_costs(zeroed_parameters, price_index_table)
  societal <- compute_strategy_societal_costs(
    zeroed_parameters, cost_result$strategy_costs, all_items_price_index_table, reference_year
  )

  expect_true(all(societal$societal_addon == 0))
  expect_equal(societal$societal_total_cost, societal$healthcare_sector_cost)
})
