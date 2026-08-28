test_that("validate_cms_filter_field errors when the CMS API silently returns an unfiltered dataset", {
  # Regression test for the bug documented in docs/evidence_layers.md: a
  # dataset organized by APC_Cd rather than HCPCS_Cd, queried with
  # hcpcs_field = "HCPCS_Cd", used to silently return every row instead of
  # erroring. This is the pure, offline-testable guard extracted from
  # cms_query_hcpcs().
  unfiltered_response <- tibble::tibble(
    APC_Cd = c("5072", "5073"), Avg_Mdcr_Alowd_Amt = c("1365.37", "2337.16")
  )
  expect_error(
    validate_cms_filter_field(unfiltered_response, "HCPCS_Cd"),
    "no 'HCPCS_Cd' field"
  )
})

test_that("validate_cms_filter_field passes when the filter field is present or the page is empty", {
  properly_filtered_response <- tibble::tibble(
    HCPCS_Cd = c("58100", "58100"), Avg_Mdcr_Alowd_Amt = c("98.20", "98.20")
  )
  expect_true(validate_cms_filter_field(properly_filtered_response, "HCPCS_Cd"))

  empty_response <- tibble::tibble(HCPCS_Cd = character(0))
  expect_true(validate_cms_filter_field(empty_response, "HCPCS_Cd"))
})

test_that("summarize_probability_cheapest sums to 100% and covers all three strategies", {
  probabilistic_estimates <- tibble::tibble(
    draw = 1:10,
    incremental_cost_combined_vs_office = rep(c(-10, 5), 5),
    cheapest_strategy = c(rep("combined_emb", 7), rep("office_emb", 2), "dnc")
  )

  summary_tbl <- summarize_probability_cheapest(probabilistic_estimates)

  expect_equal(sum(summary_tbl$n_draws_cheapest), 10)
  expect_equal(sum(summary_tbl$pct_draws_cheapest), 100)
  expect_equal(
    summary_tbl$pct_draws_cheapest[summary_tbl$strategy == "combined_emb"], 70
  )
})

test_that("run_probabilistic_sensitivity's cheapest_strategy matches the per-draw minimum cost", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  probabilistic_estimates <- run_probabilistic_sensitivity(
    model_parameters, price_index_table = price_index_table, n_simulations = 25
  )

  for (row_index in seq_len(nrow(probabilistic_estimates))) {
    row <- probabilistic_estimates[row_index, ]
    costs <- c(
      office_emb = row$office_emb_cost,
      combined_emb = row$combined_emb_cost,
      dnc = row$dnc_cost
    )
    expect_equal(row$cheapest_strategy, names(costs)[which.min(costs)])
  }
})

test_that("estimate_budget_impact scales linearly with cohort size", {
  budget_impact_tbl <- estimate_budget_impact(
    per_patient_incremental_cost = -200,
    cohort_sizes = c(10, 100),
    comparator_label = "office_emb"
  )

  expect_equal(budget_impact_tbl$per_patient_savings, c(200, 200))
  expect_equal(budget_impact_tbl$annual_savings, c(2000, 20000))
})

test_that("estimate_budget_impact_all_comparators returns rows for both comparators", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  strategy_result <- compute_strategy_costs(model_parameters, price_index_table)

  budget_impact_tbl <- estimate_budget_impact_all_comparators(
    strategy_result$strategy_costs
  )

  expect_setequal(unique(budget_impact_tbl$comparator), c("office_emb", "dnc"))
})

test_that("validate_against_published_model correctly flags within/outside tolerance", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  strategy_result <- compute_strategy_costs(model_parameters, price_index_table)

  actual_office_cost <- strategy_result$strategy_costs$expected_total_cost[
    strategy_result$strategy_costs$strategy == "office_emb"
  ]

  validation_tbl <- validate_against_published_model(
    model_parameters, price_index_table,
    targets = list(office_emb = actual_office_cost, dnc = 1),
    tolerance_pct = 5
  )

  expect_true(validation_tbl$within_tolerance[validation_tbl$strategy == "office_emb"])
  expect_false(validation_tbl$within_tolerance[validation_tbl$strategy == "dnc"])
})

test_that("literature_replication_status never claims Yi or Havrilesky are reproduced", {
  status_tbl <- literature_replication_status()
  yi_row <- status_tbl[grepl("Yi et al", status_tbl$study), ]
  havrilesky_row <- status_tbl[grepl("Havrilesky", status_tbl$study), ]

  expect_equal(yi_row$status, "pending_parameter_extraction")
  expect_equal(havrilesky_row$status, "pending_parameter_extraction")
})

test_that("summarize_evidence_tiers accounts for every parameter exactly once", {
  model_parameters <- test_model_parameters()
  tier_summary <- summarize_evidence_tiers(model_parameters)
  expect_equal(sum(tier_summary$n_parameters), nrow(model_parameters))
})

test_that("every parameter has a recognized evidence tier", {
  model_parameters <- test_model_parameters()
  expect_true(all(
    model_parameters$evidence_tier %in% c("A", "B", "C", "D", "structural")
  ))
})
