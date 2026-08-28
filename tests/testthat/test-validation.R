test_that("validate_probability accepts and rejects correctly", {
  expect_true(validate_probability(0.5, "x"))
  expect_true(validate_probability(0, "x"))
  expect_true(validate_probability(1, "x"))
  expect_error(validate_probability(-0.1, "x"), "between 0 and 1")
  expect_error(validate_probability(1.1, "x"), "between 0 and 1")
  expect_error(validate_probability(NA_real_, "x"), "between 0 and 1")
  expect_error(validate_probability("a", "x"), "between 0 and 1")
})

test_that("validate_non_negative accepts and rejects correctly", {
  expect_true(validate_non_negative(0, "x"))
  expect_true(validate_non_negative(100, "x"))
  expect_error(validate_non_negative(-1, "x"), "non-negative")
})

test_that("validate_positive accepts and rejects correctly", {
  expect_true(validate_positive(0.01, "x"))
  expect_error(validate_positive(0, "x"), "positive")
  expect_error(validate_positive(-5, "x"), "positive")
})

test_that("validate_boolean accepts and rejects correctly", {
  expect_true(validate_boolean(TRUE, "x"))
  expect_true(validate_boolean(FALSE, "x"))
  expect_error(validate_boolean(NA, "x"), "logical")
  expect_error(validate_boolean("TRUE", "x"), "logical")
})

test_that("validate_model_parameters catches missing columns", {
  bad_parameters <- tibble::tibble(parameter = "x", base_value = "1")
  expect_error(validate_model_parameters(bad_parameters), "missing required column")
})

test_that("validate_model_parameters catches duplicate parameter names", {
  model_parameters <- test_model_parameters()
  duplicated_parameters <- dplyr::bind_rows(
    model_parameters[1, ], model_parameters[1, ]
  )
  expect_error(validate_model_parameters(duplicated_parameters), "duplicate parameter")
})

test_that("validate_model_parameters catches low_value > high_value", {
  model_parameters <- test_model_parameters()
  model_parameters$low_value[[1]] <- 999
  model_parameters$high_value[[1]] <- 1
  expect_error(validate_model_parameters(model_parameters), "low_value > high_value")
})
