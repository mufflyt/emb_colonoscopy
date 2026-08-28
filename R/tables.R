#' Table generation
#'
#' Formats analysis outputs into plain, human-readable tables and writes
#' them to `tables/` as CSV (kept dependency-light -- no `gt`/`kableExtra`
#' requirement -- consistent with `colpocleisis_costeff`'s CSV-first
#' convention).

#' Save a tibble to `tables/` with a timestamped or fixed filename
#'
#' @param table_data Tibble to save.
#' @param file_name Character scalar, e.g. `"strategy_costs.csv"`.
#' @param output_dir Character scalar directory. Default `"tables"`.
#' @return Invisibly, the path the file was saved to.
save_table <- function(table_data, file_name, output_dir = "tables") {
  if (!base::dir.exists(output_dir)) {
    base::message("Creating output directory: ", output_dir)
    base::dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  output_path <- file.path(output_dir, file_name)
  readr::write_csv(table_data, output_path)
  base::message("Saved table to: ", output_path)

  base::invisible(output_path)
}

#' Build the primary human-readable strategy comparison table
#'
#' @param strategy_comparison Tibble from
#'   [compare_strategies_to_cheapest()].
#' @return A tibble formatted for reporting: dollar amounts rounded to
#'   the nearest cent, strategy labels applied.
build_strategy_comparison_table <- function(strategy_comparison) {
  strategy_comparison %>%
    dplyr::mutate(
      strategy_label = STRATEGY_LABELS[.data$strategy],
      initial_cost = base::round(.data$initial_cost, 2),
      escalation_probability = base::round(.data$escalation_probability, 4),
      escalation_cost = base::round(.data$escalation_cost, 2),
      expected_total_cost = base::round(.data$expected_total_cost, 2),
      incremental_cost_vs_cheapest = base::round(.data$incremental_cost_vs_cheapest, 2),
      pct_difference_vs_cheapest = base::round(.data$pct_difference_vs_cheapest, 1)
    ) %>%
    dplyr::select(
      "strategy", "strategy_label", "initial_cost", "escalation_probability",
      "escalation_cost", "expected_total_cost", "incremental_cost_vs_cheapest",
      "pct_difference_vs_cheapest", "is_cheapest"
    )
}

#' Build a dynamic, model-driven summary sentence
#'
#' Generates the headline sentence from live model output rather than a
#' hard-coded narrative, following the `summary_sentence` pattern in
#' `colpocleisis_costeff`.
#'
#' @param strategy_comparison Tibble from
#'   [compare_strategies_to_cheapest()].
#' @param combined_vs_office Tibble from [compare_combined_vs_office()].
#' @param threshold_estimates Tibble from [run_threshold_analyses()].
#' @return A character scalar.
build_summary_sentence <- function(
  strategy_comparison,
  combined_vs_office,
  threshold_estimates
) {
  get_cost <- function(strategy_name) {
    strategy_comparison$expected_total_cost[
      strategy_comparison$strategy == strategy_name
    ]
  }

  minutes_threshold <- threshold_estimates$threshold_value[
    threshold_estimates$parameter == "combined_emb_added_minutes"
  ]

  minutes_clause <- if (length(minutes_threshold) == 1 && !base::is.na(minutes_threshold)) {
    base::paste0(
      "remains the least expensive strategy as long as the incremental ",
      "colonoscopy-suite time stays below approximately ",
      base::round(minutes_threshold, 1), " minutes"
    )
  } else {
    "remained the least expensive strategy across the tested range of incremental colonoscopy-suite time"
  }

  base::paste0(
    "Among a modeled cohort of patients with Lynch syndrome already undergoing ",
    "surveillance colonoscopy, performing endometrial biopsy during the same ",
    "sedated encounter cost an estimated ", scales::dollar(get_cost("combined_emb")),
    " per patient, compared with ", scales::dollar(get_cost("office_emb")),
    " for standalone office biopsy and ", scales::dollar(get_cost("dnc")),
    " for operative dilation and curettage. Adding EMB to colonoscopy cost ",
    scales::dollar(base::abs(combined_vs_office$incremental_cost_combined_vs_office)),
    if (combined_vs_office$combined_is_cost_saving) " less than" else " more than",
    " performing EMB separately (",
    base::round(base::abs(combined_vs_office$pct_difference_combined_vs_office), 1),
    "%). The combined strategy ", minutes_clause, "."
  )
}
