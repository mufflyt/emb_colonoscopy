test_that("find_parameter_threshold recovers a known linear root", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  # coordination_cost enters combined_emb linearly with slope 1, so the
  # incremental-cost metric crosses zero at a value we can sanity-check
  # directly against a manual recomputation.
  threshold_result <- find_parameter_threshold(
    model_parameters, "coordination_cost",
    metric_combined_vs_office_incremental, price_index_table,
    search_lower = 0, search_upper = 5000
  )

  expect_true(threshold_result$converged)

  metric_at_threshold <- evaluate_metric_at(
    model_parameters, "coordination_cost", threshold_result$threshold_value,
    price_index_table, metric_combined_vs_office_incremental
  )
  expect_equal(metric_at_threshold, 0, tolerance = 1e-4)
})

test_that("find_parameter_threshold reports non-convergence without a sign change", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  # coordination_cost over a tiny interval that does not bracket the root.
  threshold_result <- find_parameter_threshold(
    model_parameters, "coordination_cost",
    metric_combined_vs_office_incremental, price_index_table,
    search_lower = 0, search_upper = 1
  )

  expect_false(threshold_result$converged)
  expect_true(is.na(threshold_result$threshold_value))
})

test_that("D&C is already dominated at base case even with zero facility fee, so the threshold search correctly reports non-convergence", {
  # Under current (partly provisional) parameters, D&C's non-facility
  # components alone (professional + pathology + preop visit + recovery +
  # anesthesia) already exceed both alternatives, so there is no
  # dnc_facility_or_asc_fee value in [0, search_upper] at which D&C
  # *becomes* dominated -- it already is. find_parameter_threshold should
  # report this as a non-converged search rather than a spurious root.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  dnc_threshold <- threshold_dnc_dominated_facility_fee(model_parameters, price_index_table)
  expect_false(dnc_threshold$converged)

  metric_at_zero_fee <- evaluate_metric_at(
    model_parameters, "dnc_facility_or_asc_fee", 0, price_index_table, metric_dnc_dominated
  )
  expect_true(metric_at_zero_fee > 0)
})

test_that("run_threshold_analyses returns one row per named question", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  threshold_estimates <- run_threshold_analyses(model_parameters, price_index_table)
  expect_equal(nrow(threshold_estimates), 4)
  expect_true(all(c("question", "parameter", "threshold_value") %in% names(threshold_estimates)))
})
