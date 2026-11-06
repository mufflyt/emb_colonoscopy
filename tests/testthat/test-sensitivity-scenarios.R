#' Tests for the analysis layer that generates published tables
#'
#' `run_one_way_sensitivity()` (Table 4, Figure 2), `run_scenario_analysis()`
#' (the payer and structural scenarios), `build_summary_sentence()` (the
#' sentence quoted in the abstract and README), and the PSA helpers all
#' produce numbers that reach the manuscript, and none of them had a test
#' before this file. The checks here are properties and cross-table
#' agreement, not hard-coded dollar figures, except where the point is
#' precisely that a generated artifact still matches the live model.

# ---- Target metrics ------------------------------------------------------

test_that("metric_combined_vs_office_incremental is the signed combined-minus-office gap", {
  strategy_costs <- compute_strategy_costs(
    test_model_parameters(), test_price_index_table()
  )$strategy_costs
  combined <- strategy_costs$expected_total_cost[strategy_costs$strategy == "combined_emb"]
  office <- strategy_costs$expected_total_cost[strategy_costs$strategy == "office_emb"]
  expect_equal(metric_combined_vs_office_incremental(strategy_costs), combined - office)
  # Negative means combined is cheaper, which is the base-case finding.
  expect_lt(metric_combined_vs_office_incremental(strategy_costs), 0)
})

test_that("metric_expected_total_cost returns the named strategy's cost", {
  strategy_costs <- compute_strategy_costs(
    test_model_parameters(), test_price_index_table()
  )$strategy_costs
  for (strategy_name in c("office_emb", "combined_emb", "dnc")) {
    expect_equal(
      metric_expected_total_cost(strategy_name)(strategy_costs),
      strategy_costs$expected_total_cost[strategy_costs$strategy == strategy_name],
      info = strategy_name
    )
  }
})

test_that("metric_combined_vs_min_other compares against the cheapest rival, not the mean", {
  strategy_costs <- compute_strategy_costs(
    test_model_parameters(), test_price_index_table()
  )$strategy_costs
  combined <- strategy_costs$expected_total_cost[strategy_costs$strategy == "combined_emb"]
  cheapest_rival <- min(strategy_costs$expected_total_cost[strategy_costs$strategy != "combined_emb"])
  expect_equal(metric_combined_vs_min_other(strategy_costs), combined - cheapest_rival)
  # Must track office EMB (the cheaper rival), not D&C.
  office <- strategy_costs$expected_total_cost[strategy_costs$strategy == "office_emb"]
  expect_equal(metric_combined_vs_min_other(strategy_costs), combined - office)
})

test_that("metric_dnc_dominated compares D&C against the MORE expensive alternative", {
  strategy_costs <- compute_strategy_costs(
    test_model_parameters(), test_price_index_table()
  )$strategy_costs
  dnc <- strategy_costs$expected_total_cost[strategy_costs$strategy == "dnc"]
  dearest_rival <- max(strategy_costs$expected_total_cost[strategy_costs$strategy != "dnc"])
  expect_equal(metric_dnc_dominated(strategy_costs), dnc - dearest_rival)
  # Positive means D&C is dominated by both alternatives.
  expect_gt(metric_dnc_dominated(strategy_costs), 0)
})

# ---- One-way sensitivity -------------------------------------------------

test_that("run_one_way_sensitivity reports a non-negative spread and a constant base metric", {
  result <- suppressMessages(run_one_way_sensitivity(
    test_model_parameters(),
    parameter_names = c("combined_emb_added_minutes", "emb_failure_lynch", "emb_pathology_cost"),
    price_index_table = test_price_index_table()
  ))
  expect_true(all(result$spread >= 0))
  # The base metric does not depend on which parameter is being perturbed.
  expect_equal(length(unique(round(result$metric_at_base, 10))), 1L)
  expect_equal(
    result$spread,
    abs(result$metric_at_high - result$metric_at_low),
    tolerance = 1e-9
  )
})

test_that("pathology moves the combined-vs-office gap only through extra specimens", {
  # Pathology is billed per specimen, not per strategy, so it does NOT cancel
  # between the arms: office EMB pays it again on a repeat attempt and again
  # on D&C rescue, while combined pays it again only on its own rescue. The
  # gap's sensitivity to pathology must therefore equal the price range times
  # the difference in expected extra specimens. Anything else means pathology
  # is being charged somewhere it should not be.
  parameters <- test_model_parameters()
  value_of <- function(name) as.numeric(parameters$base_value[parameters$parameter == name])

  office_extra_specimens <-
    value_of("emb_failure_lynch") * value_of("office_repeat_attempt_fraction") +
    value_of("emb_failure_lynch") *
      (1 - value_of("office_repeat_attempt_fraction") * value_of("office_repeat_attempt_success_probability"))
  combined_extra_specimens <- value_of("combined_to_dnc_probability")

  result <- suppressMessages(run_one_way_sensitivity(
    parameters,
    parameter_names = c("emb_pathology_cost"),
    price_index_table = test_price_index_table()
  ))
  price_range <- result$high_value[[1]] - result$low_value[[1]]
  expect_equal(
    result$spread[[1]],
    price_range * abs(combined_extra_specimens - office_extra_specimens),
    tolerance = 1e-9
  )
})

test_that("equalizing the two arms' escalation rates collapses pathology's leverage", {
  # Same mechanism, approached from the other side. Set office EMB's effective
  # escalation equal to the combined arm's and pathology's pull on the gap
  # nearly vanishes, leaving only the repeat-attempt specimen.
  parameters <- test_model_parameters()
  value_of <- function(name) as.numeric(parameters$base_value[parameters$parameter == name])
  equalizing_failure_rate <- value_of("combined_to_dnc_probability") /
    (1 - value_of("office_repeat_attempt_fraction") * value_of("office_repeat_attempt_success_probability"))

  base_spread <- suppressMessages(run_one_way_sensitivity(
    parameters, parameter_names = "emb_pathology_cost",
    price_index_table = test_price_index_table()
  ))$spread[[1]]
  equalized_spread <- suppressMessages(run_one_way_sensitivity(
    override_model_parameters(parameters, list(emb_failure_lynch = equalizing_failure_rate)),
    parameter_names = "emb_pathology_cost",
    price_index_table = test_price_index_table()
  ))$spread[[1]]

  expect_lt(equalized_spread, base_spread / 100)
})

test_that("run_one_way_sensitivity still reproduces the committed Table 4 ordering", {
  table_path <- file.path(repo_root_path(), "tables/one_way_sensitivity.csv")
  testthat::skip_if_not(file.exists(table_path))
  committed <- utils::read.csv(table_path)
  result <- suppressMessages(run_one_way_sensitivity(
    test_model_parameters(),
    parameter_names = committed$parameter,
    price_index_table = test_price_index_table()
  ))
  result <- result[match(committed$parameter, result$parameter), ]
  expect_equal(result$spread, committed$spread, tolerance = 1e-6)
  # The tornado diagram's bar order is the finding readers see first.
  expect_equal(
    result$parameter[order(-result$spread)],
    committed$parameter[order(-committed$spread)]
  )
})

# ---- Scenario analysis ---------------------------------------------------

test_that("run_scenario_analysis puts commercial above base above Medicaid for every strategy", {
  scenarios <- suppressMessages(run_scenario_analysis(
    test_model_parameters(), test_price_index_table()
  ))
  cost_in <- function(scenario_name, strategy_name) {
    scenarios$expected_total_cost[
      scenarios$scenario == scenario_name & scenarios$strategy == strategy_name
    ]
  }
  for (strategy_name in c("office_emb", "combined_emb", "dnc")) {
    expect_lt(cost_in("medicaid", strategy_name), cost_in("base_case_medicare", strategy_name))
    expect_gt(cost_in("commercial", strategy_name), cost_in("base_case_medicare", strategy_name))
  }
})

test_that("run_scenario_analysis's base-case row equals the standalone base-case model", {
  scenarios <- suppressMessages(run_scenario_analysis(
    test_model_parameters(), test_price_index_table()
  ))
  strategy_costs <- compute_strategy_costs(
    test_model_parameters(), test_price_index_table()
  )$strategy_costs
  base_rows <- scenarios[scenarios$scenario == "base_case_medicare", ]
  base_rows <- base_rows[match(strategy_costs$strategy, base_rows$strategy), ]
  expect_equal(
    base_rows$expected_total_cost, strategy_costs$expected_total_cost,
    tolerance = 1e-9
  )
})

test_that("combined EMB is the cheapest strategy in every non-provisional scenario", {
  scenarios <- suppressMessages(run_scenario_analysis(
    test_model_parameters(), test_price_index_table()
  ))
  for (scenario_name in unique(scenarios$scenario)) {
    rows <- scenarios[scenarios$scenario == scenario_name, ]
    expect_equal(
      rows$strategy[which.min(rows$expected_total_cost)],
      "combined_emb",
      info = scenario_name
    )
  }
})

# ---- Summary sentence ----------------------------------------------------

test_that("build_summary_sentence reproduces the committed sentence exactly", {
  summary_path <- file.path(repo_root_path(), "tables/manuscript_summary_sentence.txt")
  testthat::skip_if_not(file.exists(summary_path))
  strategy_result <- compute_strategy_costs(test_model_parameters(), test_price_index_table())
  sentence <- build_summary_sentence(
    compare_strategies_to_cheapest(strategy_result$strategy_costs),
    compare_combined_vs_office(strategy_result$strategy_costs),
    suppressMessages(run_threshold_analyses(test_model_parameters(), test_price_index_table()))
  )
  expect_equal(sentence, trimws(paste(readLines(summary_path, warn = FALSE), collapse = " ")))
})

test_that("build_summary_sentence says 'more than' when combined is the costlier arm", {
  # Push added minutes past the breakpoint so the sign flips, and confirm the
  # prose follows the arithmetic instead of hard-coding the hoped-for finding.
  expensive_parameters <- override_model_parameters(
    test_model_parameters(), list(combined_emb_added_minutes = 40)
  )
  strategy_result <- compute_strategy_costs(expensive_parameters, test_price_index_table())
  sentence <- build_summary_sentence(
    compare_strategies_to_cheapest(strategy_result$strategy_costs),
    compare_combined_vs_office(strategy_result$strategy_costs),
    suppressMessages(run_threshold_analyses(expensive_parameters, test_price_index_table()))
  )
  expect_true(grepl("more than performing EMB separately", sentence, fixed = TRUE))
  expect_false(grepl("less than performing EMB separately", sentence, fixed = TRUE))
})

test_that("build_summary_sentence degrades gracefully when the minutes threshold is missing", {
  strategy_result <- compute_strategy_costs(test_model_parameters(), test_price_index_table())
  empty_thresholds <- tibble::tibble(
    question = character(), parameter = character(),
    threshold_value = numeric(), converged = logical()
  )
  sentence <- build_summary_sentence(
    compare_strategies_to_cheapest(strategy_result$strategy_costs),
    compare_combined_vs_office(strategy_result$strategy_costs),
    empty_thresholds
  )
  expect_true(grepl("across the tested range", sentence, fixed = TRUE))
  expect_false(grepl("NA minutes", sentence, fixed = TRUE))
})

# ---- Pairwise comparison -------------------------------------------------

test_that("compare_two_strategies is antisymmetric in its two arguments", {
  strategy_costs <- compute_strategy_costs(
    test_model_parameters(), test_price_index_table()
  )$strategy_costs
  forward <- compare_two_strategies(strategy_costs, "combined_emb", "office_emb")
  reverse <- compare_two_strategies(strategy_costs, "office_emb", "combined_emb")
  expect_equal(forward$incremental_cost, -reverse$incremental_cost, tolerance = 1e-9)
})

test_that("compare_two_strategies refuses a strategy that is missing or duplicated", {
  strategy_costs <- compute_strategy_costs(
    test_model_parameters(), test_price_index_table()
  )$strategy_costs
  expect_error(compare_two_strategies(strategy_costs, "combined_emb", "no_such_strategy"))
  doubled <- rbind(strategy_costs, strategy_costs[strategy_costs$strategy == "dnc", ])
  expect_error(compare_two_strategies(doubled, "dnc", "office_emb"))
})

# ---- Parameter plumbing --------------------------------------------------

test_that("model_parameters_as_list keeps the boolean toggle logical and the rest numeric", {
  values <- model_parameters_as_list(test_model_parameters())
  expect_true(is.logical(values$combined_requires_preop_office_visit))
  expect_true(is.numeric(values$emb_failure_lynch))
  expect_equal(values$emb_pathology_cost, 50.75)
})

test_that("draw_parameter_set never samples the structural boolean toggle", {
  parameters <- test_model_parameters()
  original <- parameters$base_value[parameters$parameter == "combined_requires_preop_office_visit"]
  withr::with_seed(42, {
    for (i in 1:5) {
      drawn <- draw_parameter_set(parameters)
      expect_equal(
        drawn$base_value[drawn$parameter == "combined_requires_preop_office_visit"],
        original
      )
    }
  })
})

test_that("draw_parameter_set keeps every probability inside 0-1", {
  parameters <- test_model_parameters()
  probability_rows <- parameters$parameter[parameters$unit == "probability"]
  withr::with_seed(7, {
    for (i in 1:20) {
      drawn <- draw_parameter_set(parameters)
      drawn_probabilities <- as.numeric(
        drawn$base_value[drawn$parameter %in% probability_rows]
      )
      drawn_probabilities <- drawn_probabilities[!is.na(drawn_probabilities)]
      expect_true(all(drawn_probabilities >= 0 & drawn_probabilities <= 1))
    }
  })
})

test_that("summarize_psa_cost_interval is reproducible for a fixed seed and varies without one", {
  first <- suppressMessages(summarize_psa_cost_interval(
    test_model_parameters(), test_price_index_table(), n_simulations = 40, seed = 123
  ))
  second <- suppressMessages(summarize_psa_cost_interval(
    test_model_parameters(), test_price_index_table(), n_simulations = 40, seed = 123
  ))
  expect_equal(first, second)
  different <- suppressMessages(summarize_psa_cost_interval(
    test_model_parameters(), test_price_index_table(), n_simulations = 40, seed = 999
  ))
  expect_false(isTRUE(all.equal(first$mean_cost, different$mean_cost)))
})

# ---- weighted_sd ---------------------------------------------------------

test_that("weighted_sd matches a hand-computed population weighted SD", {
  # Weights 1,1,2 on values 2,4,6: weighted mean = 4.5,
  # variance = (1*6.25 + 1*0.25 + 2*2.25) / 4 = 2.75.
  expect_equal(weighted_sd(c(2, 4, 6), c(1, 1, 2)), sqrt(2.75), tolerance = 1e-12)
})

test_that("weighted_sd equals the population SD when weights are equal", {
  x <- c(3, 7, 11, 19)
  population_sd <- sqrt(sum((x - mean(x))^2) / length(x))
  expect_equal(weighted_sd(x, rep(1, 4)), population_sd, tolerance = 1e-12)
})

test_that("weighted_sd drops zero-weight and non-finite points, and needs two of them", {
  expect_equal(weighted_sd(c(2, 4, 6, 1000), c(1, 1, 2, 0)), sqrt(2.75), tolerance = 1e-12)
  expect_equal(weighted_sd(c(2, 4, 6, NA), c(1, 1, 2, 5)), sqrt(2.75), tolerance = 1e-12)
  expect_true(is.na(weighted_sd(c(5), c(1))))
  expect_true(is.na(weighted_sd(c(5, 9), c(1, 0))))
})
