#' Look up one strategy's value from a strategy-cost table
#'
#' Central accessor for `strategy_costs`-shaped tibbles produced by
#' [compute_strategy_costs()] or [compute_multi_strategy_costs()]. It
#' enforces the same "exactly one row" contract as [compare_two_strategies()],
#' so missing or duplicated strategy names fail loudly instead of silently
#' returning `numeric(0)` or a longer vector.
#'
#' @param strategy_costs Tibble with `strategy` and the requested `column`.
#' @param strategy_name Character scalar naming the strategy row.
#' @param column Character scalar column to return; defaults to
#'   `"expected_total_cost"`.
#' @return A length-one numeric (or the column's class) value.
#' @export
get_strategy_value <- function(
  strategy_costs,
  strategy_name,
  column = "expected_total_cost"
) {
  validate_columns(strategy_costs, c("strategy", column), "strategy_costs")

  matched_values <- strategy_costs[[column]][strategy_costs$strategy == strategy_name]
  if (length(matched_values) != 1) {
    base::stop(
      "get_strategy_value() requires exactly one '", strategy_name,
      "' row in strategy_costs column '", column, "'."
    )
  }
  matched_values[[1]]
}
