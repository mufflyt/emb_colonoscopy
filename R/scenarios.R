#' Scenario analysis
#'
#' Distinguishes the base-case analysis (Medicare-anchored CPT allowed
#' amounts, no preop office visit required for the combined arm) from
#' named scenario analyses that substitute alternative payer assumptions
#' or structural choices. Every scenario is expressed as a named list of
#' parameter overrides applied via [override_model_parameters()], so
#' scenario definitions stay declarative and auditable.
#'
#' Medicaid and commercial reimbursement multipliers below are
#' PROVISIONAL and not drawn from a specific published fee schedule --
#' they exist so the scenario machinery can be exercised end to end. See
#' docs/data_sources.md for what would be needed to replace them with
#' real payer-specific rates.

#' Parameter names treated as "reimbursement" costs for payer-mix scenarios
REIMBURSEMENT_PARAMETER_NAMES <- c(
  "emb_office_professional_cost",
  "emb_pathology_cost",
  "dc_professional_cost",
  "office_visit_em_cost"
)

#' Build a reimbursement-multiplier scenario override list
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param multiplier Numeric scalar applied to every parameter in
#'   `REIMBURSEMENT_PARAMETER_NAMES`.
#' @return A named list suitable for [override_model_parameters()].
build_reimbursement_multiplier_overrides <- function(model_parameters, multiplier) {
  overrides <- purrr::map(
    REIMBURSEMENT_PARAMETER_NAMES,
    ~ get_parameter_value(model_parameters, .x) * multiplier
  )
  stats::setNames(overrides, REIMBURSEMENT_PARAMETER_NAMES)
}

#' Named scenario definitions
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param price_index_table Tibble from [load_price_index_table()], used
#'   to inflation-adjust the historical Ladabaum et al. 2011 office-EMB
#'   cost anchor for the `office_cost_ladabaum_historical` scenario.
#' @param reference_year Numeric scalar target year for that adjustment.
#' @return A named list of override lists, one per scenario.
build_scenario_definitions <- function(
  model_parameters,
  price_index_table = load_price_index_table(),
  reference_year = get_parameter_value(model_parameters, "reference_dollar_year")
) {
  ladabaum_row <- model_parameters %>%
    dplyr::filter(.data$parameter == "cost_emb_ladabaum_2010")
  ladabaum_inflated_cost <- adjust_for_inflation(
    cost_value = base::as.numeric(ladabaum_row$base_value[[1]]),
    source_year = ladabaum_row$dollar_year[[1]],
    reference_year = reference_year,
    price_index_table = price_index_table
  )

  list(
    base_case_medicare = list(
      overrides = list(),
      description = "Base case: CPT-based Medicare national allowed amounts, no separate preop visit for the combined arm.",
      provisional = FALSE
    ),
    medicaid_illustrative = list(
      overrides = build_reimbursement_multiplier_overrides(model_parameters, 0.70),
      description = "PROVISIONAL: illustrative Medicaid reimbursement at 70% of the Medicare rates used in this repository. Not a state-specific Medicaid fee schedule.",
      provisional = TRUE
    ),
    commercial_illustrative = list(
      overrides = build_reimbursement_multiplier_overrides(model_parameters, 1.75),
      description = "PROVISIONAL: illustrative commercial reimbursement at 175% of the Medicare rates used in this repository. Not drawn from a specific payer contract.",
      provisional = TRUE
    ),
    combined_requires_preop_visit = list(
      overrides = list(combined_requires_preop_office_visit = "TRUE"),
      description = "Structural scenario: the combined strategy requires a separate preliminary office visit before the day of colonoscopy.",
      provisional = FALSE
    ),
    office_cost_ladabaum_historical = list(
      overrides = list(emb_office_professional_cost = ladabaum_inflated_cost),
      description = base::paste0(
        "Cross-validation scenario: substitutes the office-EMB professional fee with the ",
        "Ladabaum et al. 2011 $224 (2010 dollars) literature anchor, inflated to ",
        reference_year, " dollars via the real BLS CPI-U Medical Care series (~$",
        base::round(ladabaum_inflated_cost, 0), "). Tests whether the base-case conclusion ",
        "is sensitive to using an independent historical cost track instead of the CMS-2026 ",
        "fee-schedule figure."
      ),
      provisional = FALSE
    )
  )
}

#' Run the strategy-cost model under every named scenario
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param price_index_table Tibble from [load_price_index_table()].
#' @return A tibble binding `strategy_costs` for every scenario, with a
#'   leading `scenario` column and the scenario's `provisional` flag.
run_scenario_analysis <- function(
  model_parameters,
  price_index_table = load_price_index_table()
) {
  scenario_definitions <- build_scenario_definitions(
    model_parameters, price_index_table
  )

  base::message("Running ", length(scenario_definitions), " scenario(s).")

  scenario_rows <- purrr::imap(scenario_definitions, function(scenario_definition, scenario_name) {
    base::message(
      "  Scenario: ", scenario_name,
      if (isTRUE(scenario_definition$provisional)) " [PROVISIONAL]" else ""
    )

    scenario_parameters <- override_model_parameters(
      model_parameters, scenario_definition$overrides
    )
    strategy_result <- compute_strategy_costs(
      scenario_parameters, price_index_table = price_index_table
    )

    strategy_result$strategy_costs %>%
      dplyr::mutate(
        scenario = scenario_name,
        scenario_description = scenario_definition$description,
        scenario_provisional = scenario_definition$provisional
      ) %>%
      dplyr::select("scenario", dplyr::everything())
  })

  dplyr::bind_rows(scenario_rows)
}
