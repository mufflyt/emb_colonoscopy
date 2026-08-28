#' Plotting conventions
#'
#' `theme_journal()` and the tornado/threshold plotting patterns are
#' ported directly from `colpocleisis_costeff/generate_figures.R`, which
#' used a minimal `ggplot2::theme_minimal()`-based journal theme, a
#' segment-based tornado diagram, and a line-based threshold plot. The
#' strategy-cost-plane figure is new (this model is cost-minimization,
#' not cost-utility, so there is no QALY axis to plot against).

#' Journal-style ggplot2 theme
#'
#' @return A `ggplot2` theme object.
theme_journal <- function() {
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.border = ggplot2::element_rect(fill = NA, colour = "grey70"),
      axis.ticks = ggplot2::element_line(colour = "grey70"),
      legend.position = "bottom",
      plot.title = ggplot2::element_text(face = "bold", size = 11),
      plot.subtitle = ggplot2::element_text(size = 8, colour = "grey40", lineheight = 1.2),
      plot.title.position = "plot"
    )
}

#' Display labels for the three strategies
STRATEGY_LABELS <- c(
  office_emb = "Office EMB (standalone)",
  dnc = "Operative D&C",
  combined_emb = "EMB with colonoscopy"
)

#' Bar chart of expected cost per strategy
#'
#' @param strategy_costs Tibble from
#'   `compute_strategy_costs()$strategy_costs`.
#' @return A `ggplot` object.
plot_strategy_cost_comparison <- function(strategy_costs) {
  plot_data <- strategy_costs %>%
    dplyr::mutate(label = STRATEGY_LABELS[.data$strategy]) %>%
    dplyr::arrange(.data$expected_total_cost)

  ggplot2::ggplot(
    plot_data,
    ggplot2::aes(
      x = stats::reorder(.data$label, .data$expected_total_cost),
      y = .data$expected_total_cost,
      fill = .data$label
    )
  ) +
    ggplot2::geom_col(width = 0.6) +
    ggplot2::geom_text(
      ggplot2::aes(label = scales::dollar(.data$expected_total_cost, accuracy = 1)),
      vjust = -0.5, size = 3.2
    ) +
    ggplot2::scale_y_continuous(
      labels = scales::dollar_format(),
      expand = ggplot2::expansion(mult = c(0, 0.15))
    ) +
    ggplot2::scale_fill_brewer(palette = "Set1", guide = "none") +
    ggplot2::labs(
      x = NULL,
      y = "Expected cost per patient ($)"
    ) +
    theme_journal()
}

#' Tornado diagram from one-way sensitivity results
#'
#' @param sensitivity_estimates Tibble from [run_one_way_sensitivity()].
#' @param base_metric_value Numeric scalar: vertical reference line
#'   (typically `sensitivity_estimates$metric_at_base[[1]]`).
#' @param metric_label Character scalar for the x-axis label.
#' @return A `ggplot` object.
plot_tornado <- function(
  sensitivity_estimates,
  base_metric_value = sensitivity_estimates$metric_at_base[[1]],
  metric_label = "Incremental cost, combined EMB vs. office EMB ($)"
) {
  tornado_data <- sensitivity_estimates %>%
    dplyr::mutate(
      parameter = forcats::fct_reorder(.data$parameter, .data$spread),
      bar_left = pmin(.data$metric_at_low, .data$metric_at_high),
      bar_right = pmax(.data$metric_at_low, .data$metric_at_high)
    )

  ggplot2::ggplot(tornado_data) +
    ggplot2::geom_segment(
      ggplot2::aes(
        y = .data$parameter, yend = .data$parameter,
        x = .data$bar_left, xend = .data$bar_right
      ),
      linewidth = 6, colour = "#4A90D9", alpha = 0.8
    ) +
    ggplot2::geom_vline(
      xintercept = base_metric_value, linetype = "dashed", colour = "grey30"
    ) +
    ggplot2::scale_x_continuous(
      labels = scales::dollar_format(),
      expand = ggplot2::expansion(mult = c(0.15, 0.15))
    ) +
    ggplot2::labs(x = metric_label, y = NULL) +
    theme_journal() +
    ggplot2::theme(legend.position = "none")
}

#' Line plot of a metric across a swept parameter range (threshold plot)
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param parameter_name Character scalar parameter to sweep.
#' @param parameter_grid Numeric vector of values to evaluate.
#' @param price_index_table Tibble from [load_price_index_table()].
#' @param target_metric_fn Function of `strategy_costs` returning a
#'   numeric scalar. Defaults to
#'   [metric_combined_vs_office_incremental()].
#' @param x_label,y_label Character scalars for axis labels.
#' @return A `ggplot` object.
plot_threshold_sweep <- function(
  model_parameters,
  parameter_name,
  parameter_grid,
  price_index_table = load_price_index_table(),
  target_metric_fn = metric_combined_vs_office_incremental,
  x_label = parameter_name,
  y_label = "Incremental cost, combined EMB vs. office EMB ($)"
) {
  sweep_values <- purrr::map_dbl(
    parameter_grid,
    ~ evaluate_metric_at(
      model_parameters, parameter_name, .x, price_index_table, target_metric_fn
    )
  )

  sweep_data <- tibble::tibble(
    parameter_value = parameter_grid,
    metric_value = sweep_values
  )

  ggplot2::ggplot(
    sweep_data,
    ggplot2::aes(x = .data$parameter_value, y = .data$metric_value)
  ) +
    ggplot2::geom_line(linewidth = 0.8, colour = "#4A90D9") +
    ggplot2::geom_hline(yintercept = 0, linetype = "dashed", colour = "grey30") +
    ggplot2::scale_y_continuous(labels = scales::dollar_format()) +
    ggplot2::labs(x = x_label, y = y_label) +
    theme_journal()
}
