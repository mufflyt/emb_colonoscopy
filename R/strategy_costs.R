#' Strategy cost functions
#'
#' Each endometrial-sampling strategy is modeled as a one-step decision
#' tree: an initial attempt, which either succeeds, or fails and escalates
#' to operative D&C. This mirrors how MD Anderson's combined-screening
#' program actually behaves in practice (Nebgen et al. 2014 explicitly
#' describe escalation to hysteroscopy/D&C after inadequate combined
#' sampling), and it gives office-first and combined-first strategies a
#' structurally identical -- and therefore directly comparable -- shape:
#'
#'   E(cost) = initial_cost + P(escalation) * E(cost_dnc)
#'
#' D&C is modeled as the deterministic reference arm with no escalation
#' branch of its own (a simplifying assumption; see docs/methods_notes.md).
#'
#' The **incremental-cost principle** governs the combined-EMB arm: no
#' colonoscopy base cost, GI professional fee, or baseline sedation cost
#' is charged to this strategy, because the Lynch patient is assumed to be
#' undergoing that colonoscopy regardless of whether EMB is added.
#' `colonoscopy_anesthesia_episode_cost` is deliberately never referenced
#' in `compute_combined_emb_strategy_cost()` -- see
#' `tests/testthat/test-strategy-costs.R` for a unit test that enforces
#' this.

#' Look up a base-case value and inflation-adjust it if needed
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param parameter_name Character scalar.
#' @param price_index_table Tibble from [load_price_index_table()].
#' @param reference_year Numeric scalar target year.
#' @return Numeric scalar, adjusted to `reference_year` dollars.
get_adjusted_cost_parameter <- function(
  model_parameters,
  parameter_name,
  price_index_table,
  reference_year
) {
  matched_row <- model_parameters %>%
    dplyr::filter(.data$parameter == parameter_name)

  if (nrow(matched_row) != 1) {
    base::stop("Expected exactly one row for parameter '", parameter_name, "'.")
  }

  raw_value <- base::as.numeric(matched_row$base_value[[1]])
  source_year <- matched_row$dollar_year[[1]]

  adjust_for_inflation(
    cost_value = raw_value,
    source_year = source_year,
    reference_year = reference_year,
    price_index_table = price_index_table
  )
}

#' Compute the D&C (operative) strategy cost
#'
#' Recovery-room/PACU time is deliberately NOT a separate component here.
#' Per MedPAC's payment-basics documentation of the ASC payment system
#' (methodologically linked to OPPS): "Medicare pays for facility
#' services provided in ASCs -- such as nursing, recovery care,
#' anesthetics, drugs, and other supplies -- using a payment system that
#' is primarily linked to [OPPS]... Within each APC, CMS packages most
#' ancillary items and services with the primary service." Recovery-room
#' cost is therefore already inside `dnc_facility_or_asc_fee`; adding a
#' separate `dnc_recovery_room_cost` component would double-count it.
#' `dnc_recovery_room_cost` is kept in `config/model_parameters.csv` only
#' as a documented, explicitly-excluded reference value (same pattern as
#' `colonoscopy_anesthesia_episode_cost` for the combined arm) -- see
#' `tests/testthat/test-strategy-costs.R` for the regression test that
#' enforces this.
#'
#' @inheritParams get_adjusted_cost_parameter
#' @return A list with `components` (tibble) and `expected_total_cost`
#'   (numeric scalar; identical to `initial_cost` since D&C has no
#'   escalation branch in the base-case model).
compute_dnc_strategy_cost <- function(
  model_parameters,
  price_index_table,
  reference_year
) {
  base::message("Computing D&C (operative) strategy cost.")

  components <- tibble::tibble(
    strategy = "dnc",
    component = c(
      "professional_fee",
      "pathology",
      "facility_fee",
      "preop_clinic_visit",
      "anesthesia"
    ),
    amount = c(
      get_parameter_value(model_parameters, "dc_professional_cost"),
      get_parameter_value(model_parameters, "emb_pathology_cost"),
      get_parameter_value(model_parameters, "dnc_facility_or_asc_fee"),
      get_parameter_value(model_parameters, "dnc_preop_clinic_visit_cost"),
      get_parameter_value(model_parameters, "dnc_anesthesia_cost")
    )
  )

  initial_cost <- base::sum(components$amount)

  base::message("  D&C total cost: $", base::round(initial_cost, 2))

  list(
    components = components,
    escalation_probability = 0,
    escalation_cost = 0,
    initial_cost = initial_cost,
    expected_total_cost = initial_cost
  )
}

#' Compute the standalone office EMB strategy cost
#'
#' @inheritParams get_adjusted_cost_parameter
#' @param dnc_expected_cost Numeric scalar. Expected D&C cost, used as the
#'   rescue-procedure cost for failed office EMB attempts.
#' @return A list with `components`, `escalation_probability`,
#'   `escalation_cost`, `initial_cost`, and `expected_total_cost`.
compute_office_emb_strategy_cost <- function(
  model_parameters,
  dnc_expected_cost,
  price_index_table,
  reference_year
) {
  base::message("Computing office EMB (standalone) strategy cost.")

  components <- tibble::tibble(
    strategy = "office_emb",
    component = c(
      "office_visit",
      "professional_fee",
      "pathology",
      "supplies"
    ),
    amount = c(
      get_parameter_value(model_parameters, "office_visit_em_cost"),
      get_parameter_value(model_parameters, "emb_office_professional_cost"),
      get_parameter_value(model_parameters, "emb_pathology_cost"),
      get_parameter_value(model_parameters, "emb_disposable_supply_cost")
    )
  )

  initial_cost <- base::sum(components$amount)

  failure_probability <- get_parameter_value(model_parameters, "emb_failure_lynch")
  escalation_fraction <- get_parameter_value(
    model_parameters, "office_to_dnc_escalation_fraction"
  )
  escalation_probability <- failure_probability * escalation_fraction
  escalation_cost <- escalation_probability * dnc_expected_cost

  expected_total_cost <- initial_cost + escalation_cost

  base::message(
    "  Office EMB initial cost: $", base::round(initial_cost, 2),
    "; escalation probability: ", base::round(escalation_probability, 4),
    "; expected total: $", base::round(expected_total_cost, 2)
  )

  list(
    components = components,
    escalation_probability = escalation_probability,
    escalation_cost = escalation_cost,
    initial_cost = initial_cost,
    expected_total_cost = expected_total_cost
  )
}

#' Compute the colonoscopy-combined EMB strategy cost
#'
#' Only costs incremental to an already-planned surveillance colonoscopy
#' are included (the incremental-cost principle). Room and anesthesia
#' minutes use the marginal/direct per-minute rates
#' (`direct_room_cost_per_minute`, `anesthesia_cost_per_minute`), not the
#' fully-loaded `procedure_room_cost_per_minute` scenario value.
#'
#' @inheritParams compute_office_emb_strategy_cost
#' @return A list with `components`, `escalation_probability`,
#'   `escalation_cost`, `initial_cost`, and `expected_total_cost`.
compute_combined_emb_strategy_cost <- function(
  model_parameters,
  dnc_expected_cost,
  price_index_table,
  reference_year
) {
  base::message("Computing colonoscopy-combined EMB strategy cost.")

  added_minutes <- get_parameter_value(model_parameters, "combined_emb_added_minutes")

  direct_room_cost_per_minute <- get_adjusted_cost_parameter(
    model_parameters, "direct_room_cost_per_minute", price_index_table, reference_year
  )
  anesthesia_cost_per_minute <- get_adjusted_cost_parameter(
    model_parameters, "anesthesia_cost_per_minute", price_index_table, reference_year
  )

  incremental_room_cost <- added_minutes * direct_room_cost_per_minute
  incremental_anesthesia_time_cost <- added_minutes * anesthesia_cost_per_minute

  components <- tibble::tibble(
    strategy = "combined_emb",
    component = c(
      "incremental_professional_fee",
      "pathology",
      "supplies",
      "incremental_room_time",
      "incremental_anesthesia_time",
      "incremental_anesthesia_drug",
      "coordination"
    ),
    amount = c(
      get_parameter_value(model_parameters, "emb_office_professional_cost"),
      get_parameter_value(model_parameters, "emb_pathology_cost"),
      get_parameter_value(model_parameters, "emb_disposable_supply_cost"),
      incremental_room_cost,
      incremental_anesthesia_time_cost,
      get_parameter_value(
        model_parameters, "combined_emb_anesthesia_drug_increment_cost"
      ),
      get_parameter_value(model_parameters, "coordination_cost")
    )
  )

  requires_preop_visit <- get_parameter_value(
    model_parameters, "combined_requires_preop_office_visit", as_numeric = FALSE
  )
  if (isTRUE(requires_preop_visit)) {
    components <- dplyr::bind_rows(
      components,
      tibble::tibble(
        strategy = "combined_emb",
        component = "preop_office_visit",
        amount = get_parameter_value(model_parameters, "office_visit_em_cost")
      )
    )
  }

  initial_cost <- base::sum(components$amount)

  escalation_probability <- get_parameter_value(
    model_parameters, "combined_to_dnc_probability"
  )
  escalation_cost <- escalation_probability * dnc_expected_cost
  expected_total_cost <- initial_cost + escalation_cost

  base::message(
    "  Combined EMB initial cost: $", base::round(initial_cost, 2),
    " (", added_minutes, " incremental minutes); escalation probability: ",
    base::round(escalation_probability, 4),
    "; expected total: $", base::round(expected_total_cost, 2)
  )

  list(
    components = components,
    escalation_probability = escalation_probability,
    escalation_cost = escalation_cost,
    initial_cost = initial_cost,
    expected_total_cost = expected_total_cost
  )
}

#' Compute expected costs for all three strategies
#'
#' Orchestrates [compute_dnc_strategy_cost()],
#' [compute_office_emb_strategy_cost()], and
#' [compute_combined_emb_strategy_cost()], and assembles both a
#' strategy-level summary table and a long-format resource-component
#' table for plotting and reporting.
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param price_index_table Tibble from [load_price_index_table()].
#'   Defaults to loading `data/cpi_medical_care.csv`.
#' @param reference_year Numeric scalar. Defaults to the model's
#'   `reference_dollar_year` parameter.
#' @return A named list with `strategy_costs` (tibble, one row per
#'   strategy) and `cost_components` (long tibble, one row per
#'   strategy-component).
compute_strategy_costs <- function(
  model_parameters,
  price_index_table = load_price_index_table(),
  reference_year = get_parameter_value(model_parameters, "reference_dollar_year")
) {
  base::message(
    "Computing strategy costs (reference year: ", reference_year, ")."
  )

  dnc_result <- compute_dnc_strategy_cost(
    model_parameters, price_index_table, reference_year
  )
  office_result <- compute_office_emb_strategy_cost(
    model_parameters, dnc_result$expected_total_cost,
    price_index_table, reference_year
  )
  combined_result <- compute_combined_emb_strategy_cost(
    model_parameters, dnc_result$expected_total_cost,
    price_index_table, reference_year
  )

  strategy_results <- list(
    dnc = dnc_result,
    office_emb = office_result,
    combined_emb = combined_result
  )

  strategy_costs <- tibble::tibble(
    strategy = base::names(strategy_results),
    initial_cost = base::unname(purrr::map_dbl(strategy_results, "initial_cost")),
    escalation_probability = base::unname(purrr::map_dbl(
      strategy_results, "escalation_probability"
    )),
    escalation_cost = base::unname(purrr::map_dbl(strategy_results, "escalation_cost")),
    expected_total_cost = base::unname(
      purrr::map_dbl(strategy_results, "expected_total_cost")
    )
  ) %>%
    dplyr::arrange(.data$expected_total_cost)

  cost_components <- dplyr::bind_rows(
    dnc_result$components,
    office_result$components,
    combined_result$components
  )

  base::message("Strategy cost ranking (lowest to highest expected cost):")
  purrr::walk2(
    strategy_costs$strategy, strategy_costs$expected_total_cost,
    ~ base::message("  ", .x, ": $", base::round(.y, 2))
  )

  list(
    strategy_costs = strategy_costs,
    cost_components = cost_components
  )
}
