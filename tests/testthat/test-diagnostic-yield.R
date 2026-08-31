test_that("compute_diagnostic_yield returns one row per strategy with valid probabilities", {
  model_parameters <- test_model_parameters()
  yield_result <- compute_diagnostic_yield(model_parameters, disease = "cancer")

  expect_equal(nrow(yield_result), 3)
  expect_setequal(yield_result$strategy, c("office_emb", "combined_emb", "dnc"))
  expect_true(all(yield_result$detection_probability >= 0))
  expect_true(all(yield_result$detection_probability <= 1))
})

test_that("compute_diagnostic_yield errors on an unrecognized disease argument", {
  model_parameters <- test_model_parameters()
  expect_error(compute_diagnostic_yield(model_parameters, disease = "not_a_disease"))
})

test_that("dnc's detection probability equals its own sensitivity exactly (no escalation branch)", {
  model_parameters <- test_model_parameters()
  yield_result <- compute_diagnostic_yield(model_parameters, disease = "cancer")

  dnc_detection <- yield_result$detection_probability[yield_result$strategy == "dnc"]
  expect_equal(dnc_detection, get_parameter_value(model_parameters, "dnc_cancer_sensitivity"))

  dnc_escalation <- yield_result$escalation_probability[yield_result$strategy == "dnc"]
  expect_equal(dnc_escalation, 0)
})

test_that("compute_diagnostic_yield's escalation probabilities match compute_strategy_costs() exactly", {
  # Consistency guard, not a re-derivation: enforces that the diagnostic-
  # yield model and the cost model never silently diverge on how often a
  # failed sample is rescued to D&C, since both are supposed to use the
  # identical escalation parameters by design (see R/diagnostic_yield.R's
  # file-level docblock).
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  cost_result <- compute_strategy_costs(model_parameters, price_index_table)
  yield_result <- compute_diagnostic_yield(model_parameters, disease = "cancer")

  merged <- dplyr::inner_join(
    cost_result$strategy_costs, yield_result,
    by = "strategy", suffix = c("_cost", "_yield")
  )

  expect_equal(nrow(merged), 3)
  expect_equal(merged$escalation_probability_cost, merged$escalation_probability_yield)
})

test_that("compute_diagnostic_yield uses precancer-specific sensitivities when disease = 'precancer'", {
  model_parameters <- test_model_parameters()
  yield_result <- compute_diagnostic_yield(model_parameters, disease = "precancer")

  dnc_detection <- yield_result$detection_probability[yield_result$strategy == "dnc"]
  expect_equal(dnc_detection, get_parameter_value(model_parameters, "dnc_precancer_sensitivity"))
  expect_false(
    isTRUE(all.equal(
      dnc_detection, get_parameter_value(model_parameters, "dnc_cancer_sensitivity")
    ))
  )
})

test_that("compute_strategy_clinical_outcomes returns one row per strategy with valid probabilities", {
  model_parameters <- test_model_parameters()
  outcomes <- compute_strategy_clinical_outcomes(model_parameters)

  expect_equal(nrow(outcomes), 3)
  expect_setequal(outcomes$strategy, c("office_emb", "combined_emb", "dnc"))

  probability_columns <- c(
    "rescue_dnc_probability", "unresolved_sampling_probability",
    "neoplasia_delayed_probability", "major_ae_probability"
  )
  for (column_name in probability_columns) {
    expect_true(all(outcomes[[column_name]] >= 0), info = column_name)
    expect_true(all(outcomes[[column_name]] <= 1), info = column_name)
  }
})

test_that("compute_strategy_clinical_outcomes has no unresolved-failure/delayed-neoplasia risk for combined_emb or dnc", {
  # Neither arm has an observed "failed and not rescued" sub-population in
  # this repository's evidence base -- see the function's docblock.
  model_parameters <- test_model_parameters()
  outcomes <- compute_strategy_clinical_outcomes(model_parameters)

  non_office <- outcomes[outcomes$strategy != "office_emb", ]
  expect_true(all(non_office$unresolved_sampling_probability == 0))
  expect_true(all(non_office$neoplasia_delayed_probability == 0))
})

test_that("compute_strategy_clinical_outcomes: dnc's own major-AE probability equals dnc_overall_complication_probability", {
  model_parameters <- test_model_parameters()
  outcomes <- compute_strategy_clinical_outcomes(model_parameters)

  dnc_ae <- outcomes$major_ae_probability[outcomes$strategy == "dnc"]
  expect_equal(dnc_ae, get_parameter_value(model_parameters, "dnc_overall_complication_probability"))
})

test_that("MONOTONICITY: lowering office_to_dnc_escalation_fraction increases office EMB's delayed-neoplasia risk", {
  model_parameters <- test_model_parameters()

  full_escalation <- override_model_parameters(
    model_parameters, list(office_to_dnc_escalation_fraction = 1.0)
  )
  partial_escalation <- override_model_parameters(
    model_parameters, list(office_to_dnc_escalation_fraction = 0.5)
  )

  full_outcomes <- compute_strategy_clinical_outcomes(full_escalation)
  partial_outcomes <- compute_strategy_clinical_outcomes(partial_escalation)

  full_delayed <- full_outcomes$neoplasia_delayed_probability[full_outcomes$strategy == "office_emb"]
  partial_delayed <- partial_outcomes$neoplasia_delayed_probability[
    partial_outcomes$strategy == "office_emb"
  ]

  expect_equal(full_delayed, 0)
  expect_true(partial_delayed > full_delayed)
})

test_that("MONOTONICITY: a higher office EMB failure rate increases D&C adverse-event exposure via the rescue pathway", {
  model_parameters <- test_model_parameters()

  low_failure <- override_model_parameters(model_parameters, list(emb_failure_lynch = 0.05))
  high_failure <- override_model_parameters(model_parameters, list(emb_failure_lynch = 0.30))

  low_outcomes <- compute_strategy_clinical_outcomes(low_failure)
  high_outcomes <- compute_strategy_clinical_outcomes(high_failure)

  low_ae <- low_outcomes$major_ae_probability[low_outcomes$strategy == "office_emb"]
  high_ae <- high_outcomes$major_ae_probability[high_outcomes$strategy == "office_emb"]

  expect_true(high_ae > low_ae)
})

test_that("INDEPENDENT CONFIRMATION: office EMB's delayed-neoplasia-per-1000 at a sensitivity-scenario escalation fraction", {
  # Meta-rule (docs/testing_philosophy.md, Rule 2): a finding capable of
  # changing the study's frame -- here, "under a lower D&C-escalation
  # assumption, office EMB leaves some patients with a delayed cancer/
  # precancer diagnosis" -- must be re-derived via a path that never calls
  # compute_strategy_clinical_outcomes(), the function that originally
  # produced it.
  model_parameters <- test_model_parameters()
  scenario_parameters <- override_model_parameters(
    model_parameters, list(office_to_dnc_escalation_fraction = 0.7)
  )

  independent_failure <- get_parameter_value(scenario_parameters, "emb_failure_lynch")
  independent_escalation_fraction <- get_parameter_value(
    scenario_parameters, "office_to_dnc_escalation_fraction"
  )
  independent_neoplasia_after_failed_sample <- get_parameter_value(
    scenario_parameters, "cancer_or_precancer_after_failed_sample"
  )

  independent_unresolved <- independent_failure * (1 - independent_escalation_fraction)
  independent_delayed_probability <- independent_unresolved * independent_neoplasia_after_failed_sample
  independent_delayed_per_1000 <- 1000 * independent_delayed_probability

  pipeline_outcomes <- compute_strategy_clinical_outcomes(scenario_parameters)
  pipeline_delayed_per_1000 <- pipeline_outcomes$neoplasia_delayed_per_1000[
    pipeline_outcomes$strategy == "office_emb"
  ]

  expect_equal(independent_delayed_per_1000, pipeline_delayed_per_1000, tolerance = 1e-9)

  # The actual finding, re-derived independently: under this sensitivity
  # scenario, office EMB's delayed-neoplasia risk is strictly positive.
  expect_true(
    independent_delayed_per_1000 > 0,
    label = sprintf(
      "Independently-derived office EMB delayed-neoplasia rate (%.3f per 1,000) is positive under a 70%% escalation-fraction scenario",
      independent_delayed_per_1000
    )
  )
})

test_that("run_probabilistic_sensitivity carries clinical-outcome columns computed from the same per-draw parameters as cost", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  psa_result <- run_probabilistic_sensitivity(
    model_parameters, price_index_table, n_simulations = 5
  )

  outcome_columns <- c(
    "office_emb_neoplasia_delayed_per_1000", "combined_emb_neoplasia_delayed_per_1000",
    "dnc_neoplasia_delayed_per_1000", "office_emb_major_ae_per_1000",
    "combined_emb_major_ae_per_1000", "dnc_major_ae_per_1000"
  )
  expect_true(all(outcome_columns %in% names(psa_result)))
  expect_equal(nrow(psa_result), 5)
  expect_true(all(psa_result$dnc_neoplasia_delayed_per_1000 == 0))
})
