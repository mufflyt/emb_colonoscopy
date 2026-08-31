#' Diagnostic-yield extension (additive to the cost-minimization base case)
#'
#' `docs/methods_notes.md` states the condition under which this repository's
#' cost-minimization analysis would need to become a cost-effectiveness
#' analysis: "If a future extension adds differences in adequate-sampling
#' probability *combined with* differences in downstream diagnostic
#' consequences (cancer detection, time-to-diagnosis, QALYs), the analysis
#' would become a true cost-effectiveness analysis at that point." This file
#' is that extension's first piece. It does NOT change the base-case cost
#' engine in `R/strategy_costs.R` and is not called by
#' `compute_strategy_costs()`.
#'
#' Two deliberately separate functions, answering two different questions:
#'
#' - [compute_strategy_clinical_outcomes()] -- the PRIMARY, repo-native
#'   question: does office EMB's higher inadequate-sampling probability
#'   leave a meaningful fraction of patients with a delayed cancer/precancer
#'   diagnosis, and how much operative-adverse-event exposure does each
#'   strategy's D&C-rescue rate imply? Built entirely from parameters
#'   already resident in this repository (`cancer_or_precancer_after_failed_sample`,
#'   a `future_extension` row since before this file existed) plus newly
#'   added, real-cited D&C/hysteroscopy adverse-event probabilities. Wired
#'   into [run_probabilistic_sensitivity()] so cost and clinical-outcome
#'   findings share the same Monte Carlo draws.
#' - [compute_diagnostic_yield()] -- a SECONDARY, broader question (Pipelle
#'   vs. D&C sensitivity/specificity for cancer/precancer detection) that
#'   this repository deliberately does not build out further yet (no PSA
#'   wiring, no equivalence-margin testing) -- see `docs/methods_notes.md`'s
#'   note on why replicating a full diagnostic-accuracy decision tree
#'   (`docs/validation_notes.md`'s discussion of Yi et al. 2018) is a larger
#'   undertaking than this repository's cost-minimization scope currently
#'   calls for. Kept as a documented, tested, but intentionally
#'   not-yet-extended building block for that larger future piece.
#'
#' Every underlying diagnostic-sensitivity and adverse-event parameter is
#' drawn from non-Lynch, symptomatic (mostly postmenopausal-bleeding)
#' populations -- see `evidence_tier = "C"` and the per-parameter notes in
#' `config/model_parameters.csv` and `docs/data_sources.md`. This is
#' explicitly indirect evidence, not a direct measurement of Lynch
#' surveillance outcomes.
#'
#' **Escalation consistency, by design:** both functions reuse the exact
#' same escalation parameters already wired into
#' `compute_office_emb_strategy_cost()` and `compute_combined_emb_strategy_cost()`
#' (`emb_failure_lynch`, `office_to_dnc_escalation_fraction`,
#' `combined_to_dnc_probability`), rather than introducing a second,
#' differently-sourced escalation probability. Using two different
#' escalation numbers for cost and for clinical outcomes in the same
#' strategy would be internally inconsistent and would let the two halves of
#' the model quietly disagree about how often a failed sample is rescued.
#' The newer, more granular `office_failed_emb_further_workup_fraction`
#' parameter (Slaager et al. 2025) is intentionally NOT wired in here for
#' the same reason -- it measures a different clinical pathway (further
#' workup via hysteroscopy or saline infusion sonography, not specifically
#' D&C) and is kept as a documented reference value pending a real
#' Lynch-specific or D&C-specific escalation study.
#'
#' **No adverse-event dollar costs anywhere in this file.** The AE
#' probabilities added alongside this file (`dnc_perforation_probability`,
#' `dnc_overall_complication_probability`, etc.) have no companion cost
#' parameters. `docs/validation_notes.md` explicitly warns against adding
#' unsupported structure to hit a target number; a per-event dollar cost
#' would need a real CMS resource-pathway costing exercise (or a genuinely
#' comparable published cost anchor) before being added, not an invented
#' placeholder.

#' Compute each strategy's clinical-outcome profile (sampling adequacy,
#' unresolved-failure risk, and adverse-event exposure)
#'
#' This is a narrower, more directly repo-native question than
#' [compute_diagnostic_yield()]'s sensitivity/specificity-based detection
#' probability: it asks "does office EMB's higher inadequate-sampling
#' probability leave a meaningful fraction of patients with cancer/precancer
#' unresolved, given the current escalation assumptions?" using the
#' `cancer_or_precancer_after_failed_sample` parameter already sitting in
#' `config/model_parameters.csv` (`future_extension`, tier C, 7%, from the
#' same postmenopausal-bleeding meta-analysis as `emb_failure_general`/
#' `emb_insufficient_general`) rather than the newer, non-Lynch Sakna/Nabhan
#' sensitivity values `compute_diagnostic_yield()` uses. Both functions are
#' legitimate, separately-cited answers to related but distinct questions;
#' this one is intentionally the narrower claim, per the reasoning in
#' `docs/methods_notes.md`'s "Simplifying assumptions not yet relaxed"
#' section.
#'
#' For the office arm:
#'   P(rescue D&C)            = P(office failure) * P(D&C after failure)
#'   P(unresolved failure)    = P(office failure) * (1 - P(D&C after failure))
#'   P(neoplasia delayed)     = P(unresolved failure) * P(cancer/precancer | failed sample)
#'
#' The combined arm's `combined_to_dnc_probability` is used as-is (per
#' `docs/methods_notes.md`'s explicit note that it is a directly-observed
#' escalation rate, not decomposed into a separate failure/rescue-fraction
#' pair the way the office arm's is) -- so the combined arm's
#' `unresolved_sampling_probability` is defined as the complement of its
#' escalation probability among instances where the combined attempt itself
#' was not already successful. Because `combined_to_dnc_probability` already
#' represents "attempt failed AND was escalated," this repository has no
#' evidence of a combined-arm "failed and not escalated" sub-population, so
#' `unresolved_sampling_probability` is set to 0 for `combined_emb` -- this
#' is the same reasoning `compute_combined_emb_strategy_cost()` uses (no
#' separate combined-arm failure-without-rescue cost branch exists either).
#'
#' D&C's own inadequate-sampling risk is not modeled here (D&C has no
#' escalation branch in the base-case cost engine either -- see
#' `hysteroscopy_failure_rate_lynch_range`, `future_extension`, for a
#' not-yet-implemented D&C/hysteroscopy failure branch), so
#' `unresolved_sampling_probability` and `neoplasia_delayed_probability` are
#' both 0 for `dnc`. Its `major_ae_probability` uses
#' `dnc_overall_complication_probability`.
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @return A tibble with one row per strategy: `strategy`,
#'   `rescue_dnc_probability`, `unresolved_sampling_probability`,
#'   `neoplasia_delayed_probability`, `neoplasia_delayed_per_1000`,
#'   `major_ae_probability`, `major_ae_per_1000`.
compute_strategy_clinical_outcomes <- function(model_parameters) {
  base::message("Computing strategy clinical outcomes.")

  office_failure_probability <- get_parameter_value(model_parameters, "emb_failure_lynch")
  office_escalation_fraction <- get_parameter_value(
    model_parameters, "office_to_dnc_escalation_fraction"
  )
  office_rescue_probability <- office_failure_probability * office_escalation_fraction
  office_unresolved_probability <- office_failure_probability * (1 - office_escalation_fraction)

  neoplasia_after_failed_sample <- get_parameter_value(
    model_parameters, "cancer_or_precancer_after_failed_sample"
  )
  office_neoplasia_delayed_probability <-
    office_unresolved_probability * neoplasia_after_failed_sample

  combined_rescue_probability <- get_parameter_value(
    model_parameters, "combined_to_dnc_probability"
  )

  dnc_overall_ae_probability <- get_parameter_value(
    model_parameters, "dnc_overall_complication_probability"
  )

  outcomes <- tibble::tibble(
    strategy = c("office_emb", "combined_emb", "dnc"),
    rescue_dnc_probability = c(
      office_rescue_probability, combined_rescue_probability, 0
    ),
    unresolved_sampling_probability = c(
      office_unresolved_probability, 0, 0
    ),
    neoplasia_delayed_probability = c(
      office_neoplasia_delayed_probability, 0, 0
    ),
    major_ae_probability = c(
      dnc_overall_ae_probability * office_rescue_probability,
      dnc_overall_ae_probability * combined_rescue_probability,
      dnc_overall_ae_probability
    )
  ) %>%
    dplyr::mutate(
      neoplasia_delayed_per_1000 = 1000 * .data$neoplasia_delayed_probability,
      major_ae_per_1000 = 1000 * .data$major_ae_probability
    )

  base::message(
    "  office_emb neoplasia-delayed per 1,000: ",
    base::round(outcomes$neoplasia_delayed_per_1000[outcomes$strategy == "office_emb"], 2),
    "; major AE per 1,000 (office/combined/dnc): ",
    base::paste(base::round(outcomes$major_ae_per_1000, 2), collapse = " / ")
  )

  outcomes
}

#' Compute each strategy's probability of detecting disease, given disease
#' is present
#'
#' Models each strategy as: initial sampling attempt (applying that
#' strategy's own sensitivity), or -- on failure/escalation -- a D&C rescue
#' attempt (applying D&C's sensitivity). A residual branch where a failed
#' office EMB does NOT escalate to D&C contributes zero detection
#' probability, matching `compute_office_emb_strategy_cost()`'s own
#' escalation-cost logic.
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param disease Character scalar, `"cancer"` or `"precancer"` -- selects
#'   which pair of sensitivity parameters
#'   (`office_emb_<disease>_sensitivity`, `dnc_<disease>_sensitivity`) to
#'   use.
#' @return A tibble with one row per strategy (`office_emb`, `combined_emb`,
#'   `dnc`): `strategy`, `disease`, `escalation_probability` (identical to
#'   the value `compute_strategy_costs()` uses for that strategy),
#'   `detection_probability` (probability of detecting disease, given
#'   disease is present).
compute_diagnostic_yield <- function(
  model_parameters,
  disease = c("cancer", "precancer")
) {
  disease <- base::match.arg(disease)

  base::message("Computing diagnostic yield for disease type: ", disease)

  office_sensitivity <- get_parameter_value(
    model_parameters, base::paste0("office_emb_", disease, "_sensitivity")
  )
  dnc_sensitivity <- get_parameter_value(
    model_parameters, base::paste0("dnc_", disease, "_sensitivity")
  )

  office_failure_probability <- get_parameter_value(model_parameters, "emb_failure_lynch")
  office_escalation_fraction <- get_parameter_value(
    model_parameters, "office_to_dnc_escalation_fraction"
  )
  office_escalation_probability <- office_failure_probability * office_escalation_fraction

  combined_escalation_probability <- get_parameter_value(
    model_parameters, "combined_to_dnc_probability"
  )

  office_detection_probability <-
    (1 - office_failure_probability) * office_sensitivity +
    office_escalation_probability * dnc_sensitivity

  combined_detection_probability <-
    (1 - combined_escalation_probability) * office_sensitivity +
    combined_escalation_probability * dnc_sensitivity

  dnc_detection_probability <- dnc_sensitivity

  base::message(
    "  office_emb detection probability: ",
    base::round(office_detection_probability, 4),
    "; combined_emb: ", base::round(combined_detection_probability, 4),
    "; dnc: ", base::round(dnc_detection_probability, 4)
  )

  tibble::tibble(
    strategy = c("office_emb", "combined_emb", "dnc"),
    disease = disease,
    escalation_probability = c(
      office_escalation_probability, combined_escalation_probability, 0
    ),
    detection_probability = c(
      office_detection_probability, combined_detection_probability,
      dnc_detection_probability
    )
  )
}
