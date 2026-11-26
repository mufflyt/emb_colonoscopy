test_that("build_hospital_mrf_points joins coordinates on hospital AND state", {
  # A same-named hospital in a different state must not pick up the wrong
  # city's coordinates. Previously the join was on `hospital` alone.
  payer_rates <- tibble::tibble(
    hospital = c("General Hospital", "General Hospital"),
    state = c("CA", "TX"),
    medicare_confidence = c("high", "high"),
    commercial_confidence = c("not_found", "not_found")
  )
  colonoscopy_rates <- tibble::tibble(
    hospital = "Scoped Center",
    state_abbr = "CO",
    medicare_rate = 900, commercial_mean_rate = 2000,
    medicare_confidence = "high", commercial_confidence = "high",
    notes = "x", commercial_to_medicare_ratio = 2.2, source = "x"
  )
  cities <- tibble::tibble(
    hospital = c("General Hospital", "General Hospital", "Scoped Center"),
    state = c("CA", "TX", "CO"),
    city = c("Los Angeles", "Houston", "Denver"),
    lat = c(34.05, 29.76, 39.74),
    lon = c(-118.24, -95.37, -104.99),
    coordinate_source = c("place", "place", "place")
  )

  points <- suppressMessages(build_hospital_mrf_points(
    payer_rates, colonoscopy_rates, cities
  ))

  ca_point <- points[points$state == "CA", ]
  tx_point <- points[points$state == "TX", ]
  expect_equal(ca_point$lat, 34.05)
  expect_equal(ca_point$lon, -118.24)
  expect_equal(tx_point$lat, 29.76)
  expect_equal(tx_point$lon, -95.37)
  expect_equal(nrow(points), 3)
})

test_that("build_hospital_mrf_points warns when a usable hospital lacks coordinates", {
  payer_rates <- tibble::tibble(
    hospital = "Nowhere Hospital",
    state = "ZZ",
    medicare_confidence = "high",
    commercial_confidence = "not_found"
  )
  colonoscopy_rates <- tibble::tibble(
    hospital = "Scoped Center",
    state_abbr = "CO",
    medicare_rate = 900, commercial_mean_rate = 2000,
    medicare_confidence = "high", commercial_confidence = "high",
    notes = "x", commercial_to_medicare_ratio = 2.2, source = "x"
  )
  cities <- tibble::tibble(
    hospital = "Scoped Center", state = "CO", city = "Denver",
    lat = 39.74, lon = -104.99, coordinate_source = "place"
  )

  expect_message(
    points <- build_hospital_mrf_points(payer_rates, colonoscopy_rates, cities),
    "no row in"
  )
  expect_equal(nrow(points), 1)
  expect_equal(points$hospital, "Scoped Center")
})

test_that("classify_freida_hospitals treats NA confidence as not usable", {
  payer_rates <- tibble::tibble(
    hospital = c("Has Data", "Missing Confidence"),
    state = c("CA", "CA"),
    medicare_confidence = c("high", NA),
    commercial_confidence = c("not_found", NA)
  )
  classified <- classify_freida_hospitals(payer_rates)

  expect_true(classified$has_usable_data[classified$hospital == "Has Data"])
  expect_false(classified$has_usable_data[classified$hospital == "Missing Confidence"])
})
