test_that("strict dominance: a costlier, less-effective strategy is marked dominated", {
  cost_effect_table <- tibble::tibble(
    strategy = c("A", "B", "C"),
    cost = c(100, 150, 200),
    effect = c(0.5, 0.4, 0.7)
  )
  result <- compute_incremental_cost_effectiveness(cost_effect_table)

  expect_equal(result$status[result$strategy == "B"], "dominated")
  expect_true(is.na(result$icer[result$strategy == "B"]))
  expect_setequal(result$status[result$strategy %in% c("A", "C")], "on_frontier")
  expect_equal(result$icer[result$strategy == "C"], 500)
  expect_true(is.na(result$icer[result$strategy == "A"]))
})

test_that("extended dominance: a strategy whose ICER decreases the next step is excluded from the frontier", {
  # Classic textbook construction: B's own step-ICER from A (2000) is worse
  # than going straight from A to C (1000), so B is inefficient even though
  # nothing strictly dominates it on its own.
  cost_effect_table <- tibble::tibble(
    strategy = c("A", "B", "C"),
    cost = c(100, 200, 300),
    effect = c(0.10, 0.15, 0.30)
  )
  result <- compute_incremental_cost_effectiveness(cost_effect_table)

  expect_equal(result$status[result$strategy == "B"], "extendedly_dominated")
  expect_true(is.na(result$icer[result$strategy == "B"]))
  expect_equal(result$icer[result$strategy == "C"], 1000)
})

test_that("with only 2 strategies, extended dominance is vacuously satisfied (no crash, single ICER)", {
  cost_effect_table <- tibble::tibble(
    strategy = c("A", "B"), cost = c(100, 200), effect = c(0.1, 0.3)
  )
  result <- compute_incremental_cost_effectiveness(cost_effect_table)

  expect_equal(nrow(result), 2)
  expect_true(all(result$status == "on_frontier"))
  expect_equal(result$icer[result$strategy == "B"], 500)
})

test_that("with only 1 strategy, ICER is NA and status is on_frontier (no crash)", {
  cost_effect_table <- tibble::tibble(strategy = "A", cost = 100, effect = 0.1)
  result <- compute_incremental_cost_effectiveness(cost_effect_table)

  expect_equal(nrow(result), 1)
  expect_equal(result$status, "on_frontier")
  expect_true(is.na(result$icer))
})

test_that("compute_diagnostic_yield_cost_effectiveness returns one row per strategy with valid columns", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  result <- compute_diagnostic_yield_cost_effectiveness(
    model_parameters, price_index_table, disease = "cancer"
  )

  expect_equal(nrow(result), 3)
  expect_setequal(result$strategy, c("office_emb", "combined_emb", "dnc"))
  expect_true(all(result$disease == "cancer"))
  expect_true(all(result$cost > 0))
  expect_true(all(result$effect > 0 & result$effect <= 1))
  expect_true(all(result$status %in% c("on_frontier", "dominated", "extendedly_dominated")))
})

test_that("REAL-DATA: none of the three strategies are dominated in the current base case (cancer)", {
  # Documents the current model's actual finding: cost and detection
  # probability both rise from combined_emb -> office_emb -> dnc, so the
  # full frontier survives. If a future parameter change ever produces
  # dominance here, this test will fail and should be treated as a real
  # finding worth reporting, not silently updated away.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  result <- compute_diagnostic_yield_cost_effectiveness(
    model_parameters, price_index_table, disease = "cancer"
  )

  expect_true(all(result$status == "on_frontier"))
  expect_equal(sum(is.na(result$icer)), 1)
})

test_that("INDEPENDENT CONFIRMATION: office EMB's ICER vs combined EMB matches a directly re-derived ratio", {
  # Meta-rule (docs/testing_philosophy.md, Rule 2): re-derive via a path
  # that never calls compute_incremental_cost_effectiveness() or
  # compute_diagnostic_yield_cost_effectiveness().
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  cost_result <- compute_strategy_costs(model_parameters, price_index_table)
  yield_result <- compute_diagnostic_yield(model_parameters, disease = "cancer")

  combined_cost <- cost_result$strategy_costs$expected_total_cost[
    cost_result$strategy_costs$strategy == "combined_emb"
  ]
  office_cost <- cost_result$strategy_costs$expected_total_cost[
    cost_result$strategy_costs$strategy == "office_emb"
  ]
  combined_effect <- yield_result$detection_probability[yield_result$strategy == "combined_emb"]
  office_effect <- yield_result$detection_probability[yield_result$strategy == "office_emb"]

  independent_icer <- (office_cost - combined_cost) / (office_effect - combined_effect)

  pipeline_result <- compute_diagnostic_yield_cost_effectiveness(
    model_parameters, price_index_table, disease = "cancer"
  )
  pipeline_icer <- pipeline_result$icer[pipeline_result$strategy == "office_emb"]

  expect_equal(pipeline_icer, independent_icer, tolerance = 1e-9)
  # The actual finding, re-derived independently: office EMB detects more
  # true cases than combined EMB but costs more per additional case
  # detected than either of the two adjacent frontier comparisons alone
  # would suggest is "cheap" -- a five-figure dollar amount per patient,
  # not a trivial cost.
  expect_true(independent_icer > 1000)
})

test_that("compute_incremental_cost_effectiveness errors on a cost_effect_table missing required columns", {
  expect_error(
    compute_incremental_cost_effectiveness(
      tibble::tibble(strategy = "A", cost = 100)
    ),
    "effect"
  )
})
