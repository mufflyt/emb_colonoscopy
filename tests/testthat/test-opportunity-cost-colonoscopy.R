test_that("load_colonoscopy_hospital_rates_table returns 6 real hospitals", {
  rates_table <- test_colonoscopy_hospital_rates_table()

  expect_equal(nrow(rates_table), 6)
  expect_true(all(c("CO", "GA", "MS", "AR", "NY") %in% rates_table$state_abbr))
  expect_equal(sum(rates_table$state_abbr == "CO"), 2)
  expect_true(all(!is.na(rates_table$medicare_rate)))
  expect_true(all(!is.na(rates_table$commercial_mean_rate)))
})

test_that("compute_colonoscopy_opportunity_cost_bound matches an independent from-scratch recomputation", {
  model_parameters <- test_model_parameters()
  rates_table <- test_colonoscopy_hospital_rates_table()

  typical_duration <- 24.8
  added_minutes <- get_parameter_value(model_parameters, "combined_emb_added_minutes")

  result <- compute_colonoscopy_opportunity_cost_bound(model_parameters, rates_table)

  co_row <- result[result$hospital == "Denver Health Medical Center", ]
  expected_margin <- 3922.75 - 981.00
  expected_ceiling <- (expected_margin / typical_duration) * added_minutes

  expect_equal(co_row$commercial_margin, expected_margin, tolerance = 1e-2)
  expect_equal(co_row$opportunity_cost_ceiling, expected_ceiling, tolerance = 1e-2)
})

test_that("Mississippi's commercial margin is negative, unlike the other five hospitals", {
  # A real, checkable, and deliberately preserved finding: Mississippi's
  # own commercial rate is below its own Medicare rate at this hospital,
  # the opposite direction from both Colorado hospitals, Georgia,
  # Arkansas, and New York.
  model_parameters <- test_model_parameters()
  result <- compute_colonoscopy_opportunity_cost_bound(model_parameters, test_colonoscopy_hospital_rates_table())

  ms_row <- result[result$state_abbr == "MS", ]
  other_rows <- result[result$state_abbr != "MS", ]

  expect_lt(ms_row$commercial_margin, 0)
  expect_true(all(other_rows$commercial_margin > 0))
})

test_that("compute_colonoscopy_opportunity_cost_bound is not consumed by the base case", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  combined_cost_before <- compute_strategy_costs(model_parameters, price_index_table)
  perturbed_parameters <- override_model_parameters(
    model_parameters,
    list(colonoscopy_national_medicare_payment_aspe2015 = 999999)
  )
  combined_cost_after <- compute_strategy_costs(perturbed_parameters, price_index_table)

  expect_equal(
    combined_cost_before$strategy_costs$expected_total_cost,
    combined_cost_after$strategy_costs$expected_total_cost
  )
})
