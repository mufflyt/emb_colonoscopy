test_that("compute_strategy_costs returns exactly three strategies", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  strategy_result <- compute_strategy_costs(model_parameters, price_index_table)

  expect_setequal(
    strategy_result$strategy_costs$strategy,
    c("office_emb", "dnc", "combined_emb")
  )
  expect_equal(nrow(strategy_result$strategy_costs), 3)
})

test_that("dnc strategy cost equals the sum of its resource components", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  dnc_result <- compute_dnc_strategy_cost(model_parameters, price_index_table, 2026)

  expect_equal(dnc_result$initial_cost, sum(dnc_result$components$amount))
  expect_equal(dnc_result$expected_total_cost, dnc_result$initial_cost)
  expect_equal(dnc_result$escalation_probability, 0)
})

test_that("office EMB expected cost equals initial cost plus escalation cost", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  dnc_result <- compute_dnc_strategy_cost(model_parameters, price_index_table, 2026)
  office_result <- compute_office_emb_strategy_cost(
    model_parameters, dnc_result$expected_total_cost, price_index_table, 2026
  )

  expected_escalation_probability <-
    get_parameter_value(model_parameters, "emb_failure_lynch") *
    get_parameter_value(model_parameters, "office_to_dnc_escalation_fraction")

  expect_equal(office_result$escalation_probability, expected_escalation_probability)
  expect_equal(
    office_result$expected_total_cost,
    office_result$initial_cost + office_result$escalation_probability * dnc_result$expected_total_cost
  )
})

test_that("combined EMB arm never includes the colonoscopy baseline anesthesia cost", {
  # Enforces the incremental-cost principle: colonoscopy_anesthesia_episode_cost
  # must never appear in the combined-arm cost, because the colonoscopy and its
  # baseline sedation occur regardless of whether EMB is added.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  dnc_result <- compute_dnc_strategy_cost(model_parameters, price_index_table, 2026)
  combined_result <- compute_combined_emb_strategy_cost(
    model_parameters, dnc_result$expected_total_cost, price_index_table, 2026
  )

  colonoscopy_anesthesia_episode_cost <- get_parameter_value(
    model_parameters, "colonoscopy_anesthesia_episode_cost"
  )

  expect_false(
    colonoscopy_anesthesia_episode_cost %in% combined_result$components$amount
  )
  expect_false(any(grepl("colonoscopy", combined_result$components$component)))
})

test_that("D&C arm never includes a separate recovery-room component (already packaged into the facility fee)", {
  # Per MedPAC's ASC payment-basics documentation, recovery-room/PACU time
  # is packaged into the ASC/OPPS facility payment already captured in
  # dnc_facility_or_asc_fee. dnc_recovery_room_cost is kept in
  # config/model_parameters.csv only as a documented, excluded reference
  # value -- summing it separately would double-count.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  dnc_result <- compute_dnc_strategy_cost(model_parameters, price_index_table, 2026)

  dnc_recovery_room_cost <- get_parameter_value(
    model_parameters, "dnc_recovery_room_cost"
  )

  expect_false("recovery_room" %in% dnc_result$components$component)
  expect_false(dnc_recovery_room_cost %in% dnc_result$components$amount)
})

test_that("D&C arm includes a partial adverse-event cost matching the sourced perforation-management formula", {
  # Per docs/ae_cost_evidence_table.md: only observation ($0) and
  # laparoscopy-only (professional + facility fee, both CMS-sourced) are
  # included. Immediate laparotomy, laparoscopy-converted-to-laparotomy, and
  # unspecified management are deliberately excluded -- see
  # R/strategy_costs.R's docblock comment for why (CPT 49000 has no
  # OPPS/ASC facility rate).
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  dnc_result <- compute_dnc_strategy_cost(model_parameters, price_index_table, 2026)

  expect_true(
    "adverse_event_cost_partial_perforation_only" %in% dnc_result$components$component
  )

  ae_amount <- dnc_result$components$amount[
    dnc_result$components$component == "adverse_event_cost_partial_perforation_only"
  ]

  expected_ae_amount <-
    get_parameter_value(model_parameters, "dnc_perforation_probability") * (
      get_parameter_value(model_parameters, "dnc_perforation_management_observation_fraction") * 0 +
        get_parameter_value(model_parameters, "dnc_perforation_management_laparoscopy_only_fraction") * (
          get_parameter_value(model_parameters, "dnc_perforation_laparoscopy_professional_cost") +
            get_parameter_value(model_parameters, "dnc_perforation_laparoscopy_facility_cost")
        )
    )

  expect_equal(ae_amount, expected_ae_amount, tolerance = 1e-9)
  expect_gt(ae_amount, 0)
  # Sanity bound: this is a small partial addition, not a large one -- if a
  # future edit accidentally summed in the unsourced laparotomy states too,
  # this would catch the resulting jump.
  expect_lt(ae_amount, 50)
})

test_that("office EMB arm never includes a separate supplies component (already packaged into the nonfacility professional fee)", {
  # Per CMS's CY2026 Direct PE Inputs file (CMS-1832-F), CPT 58100's
  # disposable supplies (Pipelle curette, pelvic exam pack, tenaculum,
  # etc.) are priced into the code's nonfacility PE RVU
  # (nf_quantity = 1 for every supply item), which is exactly what
  # emb_office_professional_cost prices for the office_emb arm. Summing
  # emb_disposable_supply_cost separately here would double-count.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  dnc_result <- compute_dnc_strategy_cost(model_parameters, price_index_table, 2026)
  office_result <- compute_office_emb_strategy_cost(
    model_parameters, dnc_result$expected_total_cost, price_index_table, 2026
  )

  emb_disposable_supply_cost <- get_parameter_value(
    model_parameters, "emb_disposable_supply_cost"
  )

  expect_false("supplies" %in% office_result$components$component)
  expect_false(emb_disposable_supply_cost %in% office_result$components$amount)
})

test_that("combined EMB arm uses the facility-setting professional fee, not the nonfacility office rate", {
  # The EMB portion of the combined arm is performed in the facility/
  # endoscopy-suite setting where the colonoscopy itself takes place, not
  # the physician's own office. CMS's live PUF data show a real ~38% gap
  # between facility ($60.05) and nonfacility ($97.03) allowed amounts for
  # CPT 58100, so the combined arm must use
  # emb_office_professional_cost_facility, not emb_office_professional_cost.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  dnc_result <- compute_dnc_strategy_cost(model_parameters, price_index_table, 2026)
  combined_result <- compute_combined_emb_strategy_cost(
    model_parameters, dnc_result$expected_total_cost, price_index_table, 2026
  )

  emb_office_professional_cost_facility <- get_parameter_value(
    model_parameters, "emb_office_professional_cost_facility"
  )
  emb_office_professional_cost <- get_parameter_value(
    model_parameters, "emb_office_professional_cost"
  )

  expect_true(
    emb_office_professional_cost_facility %in% combined_result$components$amount
  )
  expect_false(
    emb_office_professional_cost %in% combined_result$components$amount
  )
})

test_that("combined EMB initial cost scales with combined_emb_added_minutes", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  dnc_expected_cost <- 1000

  low_minutes_parameters <- override_model_parameters(
    model_parameters, list(combined_emb_added_minutes = 1)
  )
  high_minutes_parameters <- override_model_parameters(
    model_parameters, list(combined_emb_added_minutes = 12)
  )

  low_result <- compute_combined_emb_strategy_cost(
    low_minutes_parameters, dnc_expected_cost, price_index_table, 2026
  )
  high_result <- compute_combined_emb_strategy_cost(
    high_minutes_parameters, dnc_expected_cost, price_index_table, 2026
  )

  expect_true(high_result$initial_cost > low_result$initial_cost)
})

test_that("combined EMB adds the preop office visit cost only when the scenario toggle is TRUE", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  off_parameters <- override_model_parameters(
    model_parameters, list(combined_requires_preop_office_visit = "FALSE")
  )
  off_result <- compute_combined_emb_strategy_cost(
    off_parameters, 1000, price_index_table, 2026
  )
  on_parameters <- override_model_parameters(
    model_parameters, list(combined_requires_preop_office_visit = "TRUE")
  )
  on_result <- compute_combined_emb_strategy_cost(
    on_parameters, 1000, price_index_table, 2026
  )

  office_visit_cost <- get_parameter_value(model_parameters, "office_visit_em_cost")

  expect_false("preop_office_visit" %in% off_result$components$component)
  expect_true("preop_office_visit" %in% on_result$components$component)
  expect_equal(
    on_result$initial_cost,
    off_result$initial_cost + office_visit_cost
  )
})

test_that("compute_strategy_costs is deterministic given the same parameters", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()

  first_run <- compute_strategy_costs(model_parameters, price_index_table)
  second_run <- compute_strategy_costs(model_parameters, price_index_table)

  expect_equal(
    first_run$strategy_costs$expected_total_cost,
    second_run$strategy_costs$expected_total_cost
  )
})
