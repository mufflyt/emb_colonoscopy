test_that("adjust_for_inflation returns cost unchanged when years match", {
  price_index_table <- test_price_index_table()
  expect_equal(
    adjust_for_inflation(100, 2026, 2026, price_index_table),
    100
  )
})

test_that("adjust_for_inflation scales cost by the index ratio", {
  price_index_table <- tibble::tibble(
    year = c(2010, 2020),
    index_value = c(100, 150)
  )
  expect_equal(
    adjust_for_inflation(200, 2010, 2020, price_index_table),
    300
  )
})

test_that("adjust_for_inflation errors on an unmatched year", {
  price_index_table <- test_price_index_table()
  expect_error(
    adjust_for_inflation(100, 1999, 2026, price_index_table),
    "no unique index_value"
  )
})

test_that("load_price_index_table flags placeholder rows", {
  price_index_table <- test_price_index_table()
  expect_true("is_placeholder" %in% names(price_index_table))
  expect_true(any(price_index_table$is_placeholder))
  expect_true(any(!price_index_table$is_placeholder))
})

test_that("no adjacent pair of index years implies an implausible multi-year inflation multiplier", {
  # Regression guard: an earlier version of data/cpi_medical_care.csv mixed a
  # disconnected synthetic 2014 value (100) with real 2010/2026 BLS anchors
  # (~390-590), silently producing a ~5.9x inflation multiplier for any cost
  # adjusted from 2014 dollars. Catches that class of bug: over any interval
  # in the shipped table, medical-care inflation should not exceed ~15%/year
  # compounded, which is far above any real historical rate.
  price_index_table <- test_price_index_table() %>% dplyr::arrange(.data$year)
  for (i in seq_len(nrow(price_index_table) - 1)) {
    year_gap <- price_index_table$year[[i + 1]] - price_index_table$year[[i]]
    ratio <- price_index_table$index_value[[i + 1]] / price_index_table$index_value[[i]]
    max_plausible_ratio <- 1.15^year_gap
    expect_true(
      ratio < max_plausible_ratio,
      info = base::sprintf(
        "Index ratio %s -> %s implies > 15%%/year medical inflation (ratio = %.3f over %d years)",
        price_index_table$year[[i]], price_index_table$year[[i + 1]], ratio, year_gap
      )
    )
  }
})

test_that("the real BLS CPI anchors reproduce the ~1.529x multiplier used to cross-check the Ladabaum EMB cost", {
  price_index_table <- test_price_index_table()
  index_2010 <- price_index_table$index_value[price_index_table$year == 2010]
  index_2026 <- price_index_table$index_value[price_index_table$year == 2026]
  expect_equal(base::round(index_2026 / index_2010, 3), 1.529)
})
