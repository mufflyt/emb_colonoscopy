#' Model identity / arithmetic sanity tests
#'
#' These tests check that the model behaves the way its documented
#' economic logic says it should -- not that it reproduces any specific
#' published dollar figure. This repository does NOT attempt to
#' reproduce Yi et al. 2018's $1,897.80 (Pipelle) / $2,999.11 (D&C)
#' result numerically, because doing so would require importing that
#' paper's actual internal parameters (test sensitivity/specificity,
#' failure and repeat-sampling probabilities, era-specific costs), which
#' have not yet been extracted. Fabricating internal parameters to hit
#' that target would violate this project's "do not invent
#' probabilities" rule. See docs/validation_notes.md for what a real
#' replication would require.

test_that("D&C is at least as expensive as its own component costs (no negative components)", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  dnc_result <- compute_dnc_strategy_cost(model_parameters, price_index_table, 2026)
  expect_true(all(dnc_result$components$amount >= 0))
})

test_that("every strategy's expected total cost is positive under base-case parameters", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  strategy_result <- compute_strategy_costs(model_parameters, price_index_table)
  expect_true(all(strategy_result$strategy_costs$expected_total_cost > 0))
})

test_that("raising the office EMB failure probability strictly increases office EMB cost", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  low_failure_parameters <- override_model_parameters(
    model_parameters, list(emb_failure_lynch = 0.05)
  )
  high_failure_parameters <- override_model_parameters(
    model_parameters, list(emb_failure_lynch = 0.40)
  )

  low_failure_cost <- compute_strategy_costs(low_failure_parameters, price_index_table)$
    strategy_costs$expected_total_cost[
      compute_strategy_costs(low_failure_parameters, price_index_table)$strategy_costs$strategy == "office_emb"
    ]
  high_failure_cost <- compute_strategy_costs(high_failure_parameters, price_index_table)$
    strategy_costs$expected_total_cost[
      compute_strategy_costs(high_failure_parameters, price_index_table)$strategy_costs$strategy == "office_emb"
    ]

  expect_true(high_failure_cost > low_failure_cost)
})

test_that("raising dnc_facility_or_asc_fee increases all three strategies' costs (via the rescue branch)", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  low_fee_parameters <- override_model_parameters(
    model_parameters, list(dnc_facility_or_asc_fee = 500)
  )
  high_fee_parameters <- override_model_parameters(
    model_parameters, list(dnc_facility_or_asc_fee = 5000)
  )

  low_fee_costs <- compute_strategy_costs(low_fee_parameters, price_index_table)$strategy_costs
  high_fee_costs <- compute_strategy_costs(high_fee_parameters, price_index_table)$strategy_costs

  for (strategy_name in c("office_emb", "dnc", "combined_emb")) {
    expect_true(
      high_fee_costs$expected_total_cost[high_fee_costs$strategy == strategy_name] >
        low_fee_costs$expected_total_cost[low_fee_costs$strategy == strategy_name]
    )
  }
})

test_that("combined_emb cost rises less than dnc cost as dnc_facility_or_asc_fee rises (lower escalation probability)", {
  # combined_to_dnc_probability (0.036) < emb_failure_lynch * escalation_fraction (~0.137),
  # so a $1 increase in the D&C facility fee should pass through less to the
  # combined arm than to the office arm.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  low_fee_parameters <- override_model_parameters(
    model_parameters, list(dnc_facility_or_asc_fee = 500)
  )
  high_fee_parameters <- override_model_parameters(
    model_parameters, list(dnc_facility_or_asc_fee = 5000)
  )

  low_fee_costs <- compute_strategy_costs(low_fee_parameters, price_index_table)$strategy_costs
  high_fee_costs <- compute_strategy_costs(high_fee_parameters, price_index_table)$strategy_costs

  combined_delta <- high_fee_costs$expected_total_cost[high_fee_costs$strategy == "combined_emb"] -
    low_fee_costs$expected_total_cost[low_fee_costs$strategy == "combined_emb"]
  office_delta <- high_fee_costs$expected_total_cost[high_fee_costs$strategy == "office_emb"] -
    low_fee_costs$expected_total_cost[low_fee_costs$strategy == "office_emb"]

  expect_true(combined_delta < office_delta)
})

test_that("the Ladabaum-historical scenario reproduces the documented ~1.529x inflation multiplier", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  scenario_definitions <- build_scenario_definitions(model_parameters, price_index_table)
  ladabaum_scenario_cost <- scenario_definitions$office_cost_ladabaum_historical$
    overrides$emb_office_professional_cost

  expect_equal(base::round(ladabaum_scenario_cost / 224, 3), 1.529)
})
