#' Probabilistic sensitivity analysis (PSA)
#'
#' `colpocleisis_costeff` did not implement PSA -- only a deterministic
#' one-way tornado -- so this module is new, not adapted. It follows the
#' distributional convention used by the NIHR Lynch-syndrome
#' gynecologic-surveillance economic model (NCBI Bookshelf NBK606810):
#' costs are drawn from gamma distributions and probabilities from beta
#' distributions.
#'
#' Because most `low_value`/`high_value` bounds in
#' `config/model_parameters.csv` are plausible sensitivity ranges rather
#' than formally estimated confidence intervals, this PSA implementation
#' is a first-pass scaffold: it treats `low_value`/`high_value` as an
#' approximate 95% interval around `base_value` (except where the source
#' study reported a true SD, e.g. the per-minute OR/anesthesia costs,
#' where `low_value`/`high_value` are mean +/- 1 SD -- treated the same
#' way here for simplicity, which will understate their true variance).
#' This approximation is documented, not hidden, and should be refined
#' once better parameter-level uncertainty data are available.

#' Draw one Monte Carlo sample for a single parameter row
#'
#' @param parameter_row One-row slice of `model_parameters`.
#' @return Numeric scalar (or the original base value for `distribution
#'   == "fixed"`).
draw_parameter_sample <- function(parameter_row) {
  distribution_type <- parameter_row$distribution[[1]]
  base_value <- base::as.numeric(parameter_row$base_value[[1]])

  if (distribution_type == "fixed" || base::is.na(distribution_type)) {
    return(base_value)
  }

  low_value <- parameter_row$low_value[[1]]
  high_value <- parameter_row$high_value[[1]]

  if (base::is.na(low_value) || base::is.na(high_value)) {
    return(base_value)
  }

  approx_sd <- (high_value - low_value) / (2 * 1.96)
  if (!base::is.finite(approx_sd) || approx_sd <= 0) {
    return(base_value)
  }

  if (distribution_type == "beta") {
    mean_value <- base::min(base::max(base_value, 1e-6), 1 - 1e-6)
    variance <- base::min(approx_sd^2, mean_value * (1 - mean_value) * 0.99)
    common_term <- (mean_value * (1 - mean_value) / variance) - 1
    shape1 <- mean_value * common_term
    shape2 <- (1 - mean_value) * common_term
    return(stats::rbeta(1, shape1, shape2))
  }

  if (distribution_type == "gamma") {
    explicit_alpha <- parameter_row$gamma_alpha[[1]]
    explicit_rate <- parameter_row$gamma_rate[[1]]
    if (!base::is.na(explicit_alpha) && !base::is.na(explicit_rate)) {
      return(stats::rgamma(1, shape = explicit_alpha, rate = explicit_rate))
    }

    shape_param <- (base_value / approx_sd)^2
    rate_param <- base_value / approx_sd^2
    return(stats::rgamma(1, shape = shape_param, rate = rate_param))
  }

  if (distribution_type == "triangular") {
    return(sample_triangular(low_value, base_value, high_value))
  }

  base_value
}

#' Sample from a triangular distribution
#'
#' A degenerate range (`min_value == max_value`) is treated the same way
#' `draw_parameter_sample()` already treats a degenerate beta/gamma range
#' (`approx_sd <= 0`, see above): fall back to the fixed value rather than
#' dividing by zero. `mode_value - min_value)/(max_value - min_value)` would
#' otherwise be `0/0 = NaN`, and `if (uniform_draw < NaN)` errors with
#' "missing value where TRUE/FALSE needed" -- not a silent wrong number, but
#' not the graceful degenerate-range handling this model uses everywhere
#' else either.
#'
#' @param min_value,mode_value,max_value Numeric scalars.
#' @return One draw.
sample_triangular <- function(min_value, mode_value, max_value) {
  if (base::isTRUE(min_value == max_value)) {
    return(mode_value)
  }

  uniform_draw <- stats::runif(1)
  mode_fraction <- (mode_value - min_value) / (max_value - min_value)

  if (uniform_draw < mode_fraction) {
    min_value + base::sqrt(
      uniform_draw * (max_value - min_value) * (mode_value - min_value)
    )
  } else {
    max_value - base::sqrt(
      (1 - uniform_draw) * (max_value - min_value) * (max_value - mode_value)
    )
  }
}

#' Draw one full Monte Carlo parameter set
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @return `model_parameters` with `base_value` replaced by one Monte
#'   Carlo draw for every row (fixed/boolean rows are left unchanged).
draw_parameter_set <- function(model_parameters) {
  sampled_parameters <- model_parameters
  for (row_index in base::seq_len(nrow(model_parameters))) {
    parameter_row <- model_parameters[row_index, ]
    if (parameter_row$parameter == "combined_requires_preop_office_visit") {
      next
    }
    sampled_parameters$base_value[[row_index]] <- base::as.character(
      draw_parameter_sample(parameter_row)
    )
  }
  sampled_parameters
}

#' Run probabilistic sensitivity analysis
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param price_index_table Tibble from [load_price_index_table()].
#' @param n_simulations Integer number of Monte Carlo draws. Default 1000.
#' @return A tibble with `n_simulations` rows, one per draw, giving each
#'   strategy's `expected_total_cost` and the combined-vs-office
#'   incremental cost.
run_probabilistic_sensitivity <- function(
  model_parameters,
  price_index_table = load_price_index_table(),
  n_simulations = 1000
) {
  validate_positive(n_simulations, "n_simulations")

  base::message(
    "Running probabilistic sensitivity analysis: ", n_simulations,
    " Monte Carlo draws."
  )

  simulation_rows <- purrr::map(base::seq_len(n_simulations), function(draw_index) {
    if (draw_index %% 200 == 0) {
      base::message("  Draw ", draw_index, " / ", n_simulations)
    }

    sampled_parameters <- draw_parameter_set(model_parameters)
    strategy_result <- compute_strategy_costs(
      sampled_parameters,
      price_index_table = price_index_table
    )
    incremental_result <- compare_combined_vs_office(
      strategy_result$strategy_costs
    )
    # Clinical-outcome columns computed from the SAME per-draw sampled
    # parameters as the cost columns above, not a separate Monte Carlo loop
    # -- see R/diagnostic_yield.R's file-level docblock for why a second PSA
    # framework was deliberately avoided (draws would not otherwise be
    # paired to the same underlying parameter realization).
    clinical_outcomes <- compute_strategy_clinical_outcomes(sampled_parameters)

    dnc_cost <- strategy_result$strategy_costs$expected_total_cost[
      strategy_result$strategy_costs$strategy == "dnc"
    ]

    draw_costs <- c(
      office_emb = incremental_result$office_emb_cost,
      combined_emb = incremental_result$combined_emb_cost,
      dnc = dnc_cost
    )

    outcome_at <- function(strategy_name, column_name) {
      clinical_outcomes[[column_name]][clinical_outcomes$strategy == strategy_name]
    }

    tibble::tibble(
      draw = draw_index,
      office_emb_cost = incremental_result$office_emb_cost,
      combined_emb_cost = incremental_result$combined_emb_cost,
      dnc_cost = dnc_cost,
      incremental_cost_combined_vs_office =
        incremental_result$incremental_cost_combined_vs_office,
      cheapest_strategy = base::names(draw_costs)[
        base::which.min(draw_costs)
      ],
      office_emb_neoplasia_delayed_per_1000 =
        outcome_at("office_emb", "neoplasia_delayed_per_1000"),
      combined_emb_neoplasia_delayed_per_1000 =
        outcome_at("combined_emb", "neoplasia_delayed_per_1000"),
      dnc_neoplasia_delayed_per_1000 =
        outcome_at("dnc", "neoplasia_delayed_per_1000"),
      office_emb_major_ae_per_1000 =
        outcome_at("office_emb", "major_ae_per_1000"),
      combined_emb_major_ae_per_1000 =
        outcome_at("combined_emb", "major_ae_per_1000"),
      dnc_major_ae_per_1000 =
        outcome_at("dnc", "major_ae_per_1000")
    )
  })

  probabilistic_estimates <- dplyr::bind_rows(simulation_rows)

  pct_combined_cost_saving <- 100 * base::mean(
    probabilistic_estimates$incremental_cost_combined_vs_office < 0
  )

  base::message(
    "PSA complete. Combined EMB was cost-saving vs. office EMB in ",
    base::round(pct_combined_cost_saving, 1), "% of draws."
  )

  probabilistic_estimates
}

#' Probability each strategy is the least expensive, across PSA draws
#'
#' Answers "combined sampling was the least-cost strategy in N% of
#' simulations" rather than only reporting a single deterministic
#' comparison.
#'
#' @param probabilistic_estimates Tibble from
#'   [run_probabilistic_sensitivity()], which must include a
#'   `cheapest_strategy` column.
#' @return A tibble with one row per strategy: `strategy`, `n_draws_cheapest`,
#'   `pct_draws_cheapest`.
summarize_probability_cheapest <- function(probabilistic_estimates) {
  base::message("Summarizing probability each strategy is least expensive.")

  n_total <- base::nrow(probabilistic_estimates)

  summary_tbl <- probabilistic_estimates %>%
    dplyr::count(.data$cheapest_strategy, name = "n_draws_cheapest") %>%
    dplyr::mutate(pct_draws_cheapest = 100 * .data$n_draws_cheapest / n_total) %>%
    dplyr::rename(strategy = "cheapest_strategy") %>%
    dplyr::arrange(dplyr::desc(.data$pct_draws_cheapest))

  purrr::walk2(
    summary_tbl$strategy, summary_tbl$pct_draws_cheapest,
    ~ base::message(
      "  ", .x, " was cheapest in ", base::round(.y, 1), "% of draws."
    )
  )

  summary_tbl
}
