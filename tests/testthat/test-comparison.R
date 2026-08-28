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
