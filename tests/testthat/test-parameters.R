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
  expect_equal(get_parameter_value(model_parameters, "emb_failure_lynch"), 0.137)
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
