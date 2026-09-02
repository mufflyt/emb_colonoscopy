test_that("load_model_parameters reads and validates the shipped parameter file", {
  model_parameters <- test_model_parameters()
  expect_s3_class(model_parameters, "data.frame")
  expect_true(nrow(model_parameters) > 20)
  expect_true("provisional" %in% names(model_parameters))
})

test_that("load_model_parameters errors on a missing file", {
  expect_error(load_model_parameters("does/not/exist.csv"), "not found")
})

test_that("get_parameter_value returns the correct numeric base value", {
  model_parameters <- test_model_parameters()
  expect_equal(
    get_parameter_value(model_parameters, "emb_pathology_cost"),
    70.14
  )
})

test_that("get_parameter_value errors for an unknown parameter", {
  model_parameters <- test_model_parameters()
  expect_error(
    get_parameter_value(model_parameters, "not_a_real_parameter"),
    "Expected exactly one row"
  )
})

test_that("get_parameter_value parses the boolean structural parameter", {
  model_parameters <- test_model_parameters()
  requires_visit <- get_parameter_value(
    model_parameters, "combined_requires_preop_office_visit", as_numeric = FALSE
  )
  expect_type(requires_visit, "logical")
  expect_true(requires_visit)
})

test_that("override_model_parameters replaces a base value without mutating the source", {
  model_parameters <- test_model_parameters()
  overridden <- override_model_parameters(
    model_parameters, list(emb_failure_lynch = 0.5)
  )
  expect_equal(get_parameter_value(overridden, "emb_failure_lynch"), 0.5)
  expect_equal(get_parameter_value(model_parameters, "emb_failure_lynch"), 0.133)
})

test_that("override_model_parameters errors on an unknown parameter name", {
  model_parameters <- test_model_parameters()
  expect_error(
    override_model_parameters(model_parameters, list(not_a_real_parameter = 1)),
    "unknown parameter name"
  )
})

test_that("every provisional parameter is clearly flagged in notes", {
  model_parameters <- test_model_parameters()
  provisional_rows <- model_parameters[model_parameters$provisional, ]
  expect_true(all(grepl("PROVISIONAL|UNVERIFIED|DATA QUALITY FLAG", provisional_rows$notes)))
})

test_that("office_to_dnc_escalation_fraction's boundary structural uncertainty is not degenerate in PSA", {
  # Regression test for the 2026-08-31 fix: this parameter's base_value
  # sits at 1.0, a distribution boundary. It was originally "beta", which
  # draw_parameter_sample() cannot meaningfully vary around a mean of 1.0
  # (it clamps to ~0.999999, so the parameter never actually moved across
  # 1,000 PSA draws -- see R/utils_validation.R's boundary-beta guard).
  # Now "triangular", which sample_triangular() handles correctly as
  # min/mode/max.
  model_parameters <- test_model_parameters()
  row_index <- which(model_parameters$parameter == "office_to_dnc_escalation_fraction")

  expect_equal(model_parameters$distribution[[row_index]], "triangular")

  set.seed(20260831)
  sampled_values <- purrr::map_dbl(
    seq_len(1000),
    ~ draw_parameter_sample(model_parameters[row_index, ])
  )

  expect_true(all(sampled_values >= 0.5))
  expect_true(all(sampled_values <= 1))
  expect_lt(min(sampled_values), 0.9)
  expect_gt(stats::sd(sampled_values), 0.01)
})

test_that("sample_triangular falls back to the mode instead of dividing by zero when min == max", {
  # A degenerate triangular range (low_value == high_value) is allowed by
  # validate_model_parameters() -- same design as a degenerate beta/gamma
  # range (see test-validation.R's "allows a beta row ... when low_value ==
  # high_value"). Before this guard, min_value == max_value made
  # (mode_value - min_value)/(max_value - min_value) = 0/0 = NaN inside
  # sample_triangular(), and `if (uniform_draw < NaN)` throws "missing value
  # where TRUE/FALSE needed" instead of gracefully returning the fixed value.
  expect_equal(sample_triangular(5, 5, 5), 5)
  expect_equal(sample_triangular(1, 1, 1), 1)

  degenerate_row <- tibble::tibble(
    distribution = "triangular",
    base_value = "7.5",
    low_value = 7.5,
    high_value = 7.5
  )
  expect_equal(draw_parameter_sample(degenerate_row), 7.5)
})

test_that("run_probabilistic_sensitivity is reproducible under its default seed", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  first_run <- run_probabilistic_sensitivity(
    model_parameters, price_index_table, n_simulations = 25
  )
  second_run <- run_probabilistic_sensitivity(
    model_parameters, price_index_table, n_simulations = 25
  )

  expect_identical(first_run$combined_emb_cost, second_run$combined_emb_cost)
  expect_identical(first_run$office_emb_neoplasia_delayed_per_1000, second_run$office_emb_neoplasia_delayed_per_1000)
})

test_that("run_probabilistic_sensitivity does not leak its seed into the caller's RNG state", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  set.seed(4242)
  before_draw <- runif(1)

  set.seed(4242)
  invisible(run_probabilistic_sensitivity(model_parameters, price_index_table, n_simulations = 10))
  after_draw <- runif(1)

  expect_identical(before_draw, after_draw)
})

test_that("run_probabilistic_sensitivity gives identical draws for identical seeds and different draws for different seeds", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  seed1_first <- run_probabilistic_sensitivity(
    model_parameters, price_index_table, n_simulations = 25, seed = 111
  )
  seed1_second <- run_probabilistic_sensitivity(
    model_parameters, price_index_table, n_simulations = 25, seed = 111
  )
  seed2 <- run_probabilistic_sensitivity(
    model_parameters, price_index_table, n_simulations = 25, seed = 222
  )

  expect_identical(seed1_first$combined_emb_cost, seed1_second$combined_emb_cost)
  expect_false(identical(seed1_first$combined_emb_cost, seed2$combined_emb_cost))
})

test_that("run_probabilistic_sensitivity(seed = NULL) produces genuinely different draws each call", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  unseeded_first <- run_probabilistic_sensitivity(
    model_parameters, price_index_table, n_simulations = 25, seed = NULL
  )
  unseeded_second <- run_probabilistic_sensitivity(
    model_parameters, price_index_table, n_simulations = 25, seed = NULL
  )

  expect_false(identical(unseeded_first$combined_emb_cost, unseeded_second$combined_emb_cost))
})
