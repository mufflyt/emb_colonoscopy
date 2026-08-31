test_that("build_psa_summary_table joins cheapest-strategy probabilities without NAs", {
  # Regression test for the 2026-08-31 bug found by running
  # analysis/07_manuscript_outputs.R and checking its output:
  # n_draws_cheapest/pct_draws_cheapest were NA for every row because the
  # inline pivot's "strategy" column carried a "_cost" suffix
  # ("office_emb_cost") that never matched
  # summarize_probability_cheapest()'s bare strategy names ("office_emb").
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  probabilistic_estimates <- run_probabilistic_sensitivity(
    model_parameters, price_index_table = price_index_table, n_simulations = 20
  )

  psa_summary <- build_psa_summary_table(probabilistic_estimates)

  expect_equal(nrow(psa_summary), 3)
  expect_setequal(psa_summary$strategy, c("office_emb", "combined_emb", "dnc"))
  expect_true(all(c(
    "mean_cost", "sd_cost", "p2_5", "p97_5",
    "n_draws_cheapest", "pct_draws_cheapest"
  ) %in% names(psa_summary)))

  expect_false(any(is.na(psa_summary$n_draws_cheapest)))
  expect_false(any(is.na(psa_summary$pct_draws_cheapest)))
  expect_equal(sum(psa_summary$n_draws_cheapest), 20)
  expect_equal(sum(psa_summary$pct_draws_cheapest), 100, tolerance = 1e-9)
})

test_that("build_psa_summary_table reports 0 (not NA) for a strategy that was never cheapest", {
  # D&C's cost is so much higher than the other two arms that a small PSA
  # sample can easily contain zero draws where it was cheapest --
  # summarize_probability_cheapest() then simply omits that row, and the
  # left_join in build_psa_summary_table() must turn the resulting NA into
  # a real 0, not leave it as missing data.
  fake_draws <- tibble::tibble(
    draw = 1:3,
    office_emb_cost = c(500, 550, 520),
    combined_emb_cost = c(400, 420, 410),
    dnc_cost = c(4000, 4100, 4050),
    incremental_cost_combined_vs_office = combined_emb_cost - office_emb_cost,
    cheapest_strategy = "combined_emb"
  )

  psa_summary <- build_psa_summary_table(fake_draws)
  dnc_row <- psa_summary[psa_summary$strategy == "dnc", ]

  expect_equal(nrow(dnc_row), 1)
  expect_equal(dnc_row$n_draws_cheapest, 0)
  expect_equal(dnc_row$pct_draws_cheapest, 0)
  expect_false(is.na(dnc_row$mean_cost))
})
