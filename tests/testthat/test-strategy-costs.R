test_that("compute_strategy_costs returns exactly three strategies", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  strategy_result <- compute_strategy_costs(model_parameters, price_index_table)

  expect_setequal(
    strategy_result$strategy_costs$strategy,
    c("office_emb", "dnc", "combined_emb")
  )
  expect_equal(nrow(strategy_result$strategy_costs), 3)
})

test_that("dnc strategy cost equals the sum of its resource components", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  dnc_result <- compute_dnc_strategy_cost(model_parameters, price_index_table, 2026)

  expect_equal(dnc_result$initial_cost, sum(dnc_result$components$amount))
  expect_equal(dnc_result$expected_total_cost, dnc_result$initial_cost)
  expect_equal(dnc_result$escalation_probability, 0)
})

test_that("office EMB expected cost equals initial cost plus escalation cost", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  dnc_result <- compute_dnc_strategy_cost(model_parameters, price_index_table, 2026)
  office_result <- compute_office_emb_strategy_cost(
    model_parameters, dnc_result$expected_total_cost, price_index_table, 2026
  )

  expected_escalation_probability <-
    get_parameter_value(model_parameters, "emb_failure_lynch") *
    get_parameter_value(model_parameters, "office_to_dnc_escalation_fraction")

  expect_equal(office_result$escalation_probability, expected_escalation_probability)
  expect_equal(
    office_result$expected_total_cost,
    office_result$initial_cost + office_result$escalation_probability * dnc_result$expected_total_cost
  )
})

test_that("combined EMB arm never includes the colonoscopy baseline anesthesia cost", {
  # Enforces the incremental-cost principle: colonoscopy_anesthesia_episode_cost
  # must never appear in the combined-arm cost, because the colonoscopy and its
  # baseline sedation occur regardless of whether EMB is added.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  dnc_result <- compute_dnc_strategy_cost(model_parameters, price_index_table, 2026)
  combined_result <- compute_combined_emb_strategy_cost(
    model_parameters, dnc_result$expected_total_cost, price_index_table, 2026
  )

  colonoscopy_anesthesia_episode_cost <- get_parameter_value(
    model_parameters, "colonoscopy_anesthesia_episode_cost"
  )

  expect_false(
    colonoscopy_anesthesia_episode_cost %in% combined_result$components$amount
  )
  expect_false(any(grepl("colonoscopy", combined_result$components$component)))
})

test_that("combined EMB initial cost scales with combined_emb_added_minutes", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  dnc_expected_cost <- 1000

  low_minutes_parameters <- override_model_parameters(
    model_parameters, list(combined_emb_added_minutes = 1)
  )
  high_minutes_parameters <- override_model_parameters(
    model_parameters, list(combined_emb_added_minutes = 12)
  )

  low_result <- compute_combined_emb_strategy_cost(
    low_minutes_parameters, dnc_expected_cost, price_index_table, 2026
  )
  high_result <- compute_combined_emb_strategy_cost(
    high_minutes_parameters, dnc_expected_cost, price_index_table, 2026
  )

  expect_true(high_result$initial_cost > low_result$initial_cost)
})

test_that("combined EMB adds the preop office visit cost only when the scenario toggle is TRUE", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  baseline_result <- compute_combined_emb_strategy_cost(
    model_parameters, 1000, price_index_table, 2026
  )
  toggled_parameters <- override_model_parameters(
    model_parameters, list(combined_requires_preop_office_visit = "TRUE")
  )
  toggled_result <- compute_combined_emb_strategy_cost(
    toggled_parameters, 1000, price_index_table, 2026
  )

  office_visit_cost <- get_parameter_value(model_parameters, "office_visit_em_cost")

  expect_equal(
    toggled_result$initial_cost,
    baseline_result$initial_cost + office_visit_cost
  )
})

test_that("compute_strategy_costs is deterministic given the same parameters", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  first_run <- compute_strategy_costs(model_parameters, price_index_table)
  second_run <- compute_strategy_costs(model_parameters, price_index_table)

  expect_equal(
    first_run$strategy_costs$expected_total_cost,
    second_run$strategy_costs$expected_total_cost
  )
})
