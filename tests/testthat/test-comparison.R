test_that("compare_strategies_to_cheapest flags exactly one cheapest strategy", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  strategy_result <- compute_strategy_costs(model_parameters, price_index_table)
  strategy_comparison <- compare_strategies_to_cheapest(strategy_result$strategy_costs)

  expect_equal(sum(strategy_comparison$is_cheapest), 1)
  expect_equal(min(strategy_comparison$incremental_cost_vs_cheapest), 0)
})

test_that("compare_combined_vs_office matches the direct cost difference", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  strategy_result <- compute_strategy_costs(model_parameters, price_index_table)
  combined_vs_office <- compare_combined_vs_office(strategy_result$strategy_costs)

  expect_equal(
    combined_vs_office$incremental_cost_combined_vs_office,
    combined_vs_office$combined_emb_cost - combined_vs_office$office_emb_cost
  )
  expect_equal(
    combined_vs_office$combined_is_cost_saving,
    combined_vs_office$incremental_cost_combined_vs_office < 0
  )
})

test_that("build_pairwise_comparison_table has 6 rows for 3 strategies", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  strategy_result <- compute_strategy_costs(model_parameters, price_index_table)
  pairwise_table <- build_pairwise_comparison_table(strategy_result$strategy_costs)

  expect_equal(nrow(pairwise_table), 6)
})

test_that("compare_combined_vs_office returns NA percent difference rather than Inf/NaN when office_cost is 0", {
  # Regression guard: pct_difference used to divide by office_cost with no
  # zero check, unlike the equivalent guard already in
  # compare_strategies_to_cheapest() (cheapest_cost == 0 -> NA_real_, above).
  # Not reachable with real strategy costs today, but this makes the two
  # comparison functions consistent instead of one being silently unsafe.
  # Uses a nonzero numerator (combined_cost = 50, not 0) deliberately: a
  # 0/0 case is NaN either way (is.na(NaN) is TRUE in R even without the
  # guard), which would not actually catch a missing guard -- a nonzero
  # numerator over a zero denominator is Inf, which only the guard catches.
  zero_cost_strategies <- tibble::tibble(
    strategy = c("combined_emb", "office_emb", "dnc"),
    expected_total_cost = c(50, 0, 100)
  )
  combined_vs_office <- compare_combined_vs_office(zero_cost_strategies)

  expect_equal(combined_vs_office$incremental_cost_combined_vs_office, 50)
  expect_true(is.na(combined_vs_office$pct_difference_combined_vs_office))
})

test_that("build_pairwise_comparison_table returns NA percent difference rather than Inf/NaN when cost_b is 0", {
  zero_cost_strategies <- tibble::tibble(
    strategy = c("combined_emb", "office_emb", "dnc"),
    expected_total_cost = c(50, 0, 100)
  )
  pairwise_table <- build_pairwise_comparison_table(zero_cost_strategies)

  zero_denominator_rows <- pairwise_table[pairwise_table$strategy_b == "office_emb", ]
  expect_true(all(is.na(zero_denominator_rows$pct_difference)))
  expect_true(all(is.finite(zero_denominator_rows$absolute_difference)))
})

test_that("pairwise absolute_difference is antisymmetric", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  strategy_result <- compute_strategy_costs(model_parameters, price_index_table)
  pairwise_table <- build_pairwise_comparison_table(strategy_result$strategy_costs)

  office_vs_dnc <- pairwise_table$absolute_difference[
    pairwise_table$strategy_a == "office_emb" & pairwise_table$strategy_b == "dnc"
  ]
  dnc_vs_office <- pairwise_table$absolute_difference[
    pairwise_table$strategy_a == "dnc" & pairwise_table$strategy_b == "office_emb"
  ]

  expect_equal(office_vs_dnc, -dnc_vs_office)
})
