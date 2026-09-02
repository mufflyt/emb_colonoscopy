#' Independent confirmation of study-frame-changing audit results
#'
#' Meta-rule (adopted 2026-08-28, see docs/testing_philosophy.md): an audit
#' result capable of changing the study's conclusions must itself require
#' independent confirmation, not just a passing test in the same code path
#' that produced it. The tests below re-derive specific numeric findings
#' using arithmetic written directly in the test file -- never calling
#' compute_dnc_strategy_cost(), compute_office_emb_strategy_cost(),
#' compute_combined_emb_strategy_cost(), or metric_dnc_dominated() -- so a
#' bug shared between the pipeline and its own test suite cannot silently
#' validate a wrong conclusion.

test_that("INDEPENDENT CONFIRMATION: D&C is dominated by both alternatives even at $0 facility fee", {
  # This is a study-frame-changing finding (see docs/methods_notes.md): if
  # true, it means the base-case D&C arm is not competitive at all, before
  # even accounting for its (still provisional) facility fee. Re-derived
  # here from raw parameter values via hand arithmetic, independent of the
  # pipeline that originally produced it.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  reference_year <- get_parameter_value(model_parameters, "reference_dollar_year")

  # -- D&C cost at zero facility fee, summed directly from raw parameters --
  # dnc_recovery_room_cost is deliberately excluded: it is packaged into
  # dnc_facility_or_asc_fee under OPPS/ASC payment methodology (MedPAC,
  # ASC payment basics), so compute_dnc_strategy_cost() no longer sums it
  # -- see R/strategy_costs.R and tests/testthat/test-strategy-costs.R.
  # adverse_event_cost_partial_perforation_only, re-derived independently
  # (see R/strategy_costs.R and docs/ae_cost_evidence_table.md): only the
  # two fully-costed perforation management states (observation, $0;
  # laparoscopy-only, professional + facility fee) are included.
  independent_ae_cost <-
    get_parameter_value(model_parameters, "dnc_perforation_probability") * (
      get_parameter_value(model_parameters, "dnc_perforation_management_observation_fraction") * 0 +
        get_parameter_value(model_parameters, "dnc_perforation_management_laparoscopy_only_fraction") * (
          get_parameter_value(model_parameters, "dnc_perforation_laparoscopy_professional_cost") +
            get_parameter_value(model_parameters, "dnc_perforation_laparoscopy_facility_cost")
        )
    )

  independent_dnc_cost_at_zero_fee <-
    get_parameter_value(model_parameters, "dc_professional_cost") +
    get_parameter_value(model_parameters, "emb_pathology_cost") +
    0 + # dnc_facility_or_asc_fee set to zero for this check
    get_parameter_value(model_parameters, "dnc_preop_clinic_visit_cost") +
    get_parameter_value(model_parameters, "dnc_anesthesia_cost") +
    independent_ae_cost

  # -- office EMB expected cost, summed directly from raw parameters --
  # emb_disposable_supply_cost is deliberately excluded: CMS's Direct PE
  # Inputs file (CMS-1832-F) shows these supplies (incl. the Pipelle) are
  # already priced into emb_office_professional_cost's nonfacility PE RVU
  # -- see R/strategy_costs.R and tests/testthat/test-strategy-costs.R.
  independent_office_initial_cost <-
    get_parameter_value(model_parameters, "office_visit_em_cost") +
    get_parameter_value(model_parameters, "emb_office_professional_cost") +
    get_parameter_value(model_parameters, "emb_pathology_cost")
  independent_office_escalation_probability <-
    get_parameter_value(model_parameters, "emb_failure_lynch") *
    get_parameter_value(model_parameters, "office_to_dnc_escalation_fraction")
  independent_office_cost <- independent_office_initial_cost +
    independent_office_escalation_probability * independent_dnc_cost_at_zero_fee

  # -- combined EMB expected cost, summed directly from raw parameters,
  #    doing the inflation adjustment by hand rather than via
  #    adjust_for_inflation() --
  cpi_2014 <- price_index_table$index_value[price_index_table$year == 2014]
  cpi_2026 <- price_index_table$index_value[price_index_table$year == reference_year]
  inflation_multiplier <- cpi_2026 / cpi_2014

  added_minutes <- get_parameter_value(model_parameters, "combined_emb_added_minutes")
  independent_room_cost <- added_minutes *
    get_parameter_value(model_parameters, "direct_room_cost_per_minute") * inflation_multiplier
  independent_anesthesia_time_cost <- added_minutes *
    get_parameter_value(model_parameters, "anesthesia_cost_per_minute") * inflation_multiplier

  independent_requires_preop_visit <- get_parameter_value(
    model_parameters, "combined_requires_preop_office_visit", as_numeric = FALSE
  )
  independent_preop_visit_cost <- if (isTRUE(independent_requires_preop_visit)) {
    get_parameter_value(model_parameters, "office_visit_em_cost")
  } else {
    0
  }

  independent_combined_initial_cost <-
    get_parameter_value(model_parameters, "emb_office_professional_cost_facility") +
    get_parameter_value(model_parameters, "emb_pathology_cost") +
    get_parameter_value(model_parameters, "emb_disposable_supply_cost") +
    independent_room_cost +
    independent_anesthesia_time_cost +
    get_parameter_value(model_parameters, "combined_emb_anesthesia_drug_increment_cost") +
    get_parameter_value(model_parameters, "coordination_cost") +
    independent_preop_visit_cost
  independent_combined_escalation_probability <-
    get_parameter_value(model_parameters, "combined_to_dnc_probability")
  independent_combined_cost <- independent_combined_initial_cost +
    independent_combined_escalation_probability * independent_dnc_cost_at_zero_fee

  # -- Cross-check against the actual pipeline, at the same fee value --
  pipeline_parameters <- override_model_parameters(
    model_parameters, list(dnc_facility_or_asc_fee = 0)
  )
  pipeline_result <- compute_strategy_costs(pipeline_parameters, price_index_table)
  pipeline_costs <- pipeline_result$strategy_costs

  expect_equal(
    independent_dnc_cost_at_zero_fee,
    pipeline_costs$expected_total_cost[pipeline_costs$strategy == "dnc"],
    tolerance = 1e-6
  )
  expect_equal(
    independent_office_cost,
    pipeline_costs$expected_total_cost[pipeline_costs$strategy == "office_emb"],
    tolerance = 1e-6
  )
  expect_equal(
    independent_combined_cost,
    pipeline_costs$expected_total_cost[pipeline_costs$strategy == "combined_emb"],
    tolerance = 1e-6
  )

  # -- The actual finding, re-derived independently: D&C > both alternatives --
  independent_max_alternative <- max(independent_office_cost, independent_combined_cost)
  expect_true(
    independent_dnc_cost_at_zero_fee > independent_max_alternative,
    label = sprintf(
      "Independently-derived D&C cost ($%.2f) exceeds max alternative ($%.2f)",
      independent_dnc_cost_at_zero_fee, independent_max_alternative
    )
  )
})
