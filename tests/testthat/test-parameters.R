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
