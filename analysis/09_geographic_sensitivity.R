#!/usr/bin/env Rscript
#' Geographic sensitivity analysis
#'
#' Re-prices the base-case model at four localities -- national, Colorado
#' (Denver-Aurora-Centennial), a low-cost locality (Arkansas), and a
#' high-cost locality (Manhattan) -- using real CMS GPCI values (RVU26C,
#' GPCI2026.csv) for professional-fee components and the real CMS OPPS wage
#' index (FY2026 IPPS Final Rule, Table 3) for the D&C facility fee. See
#' R/geographic_sensitivity.R and docs/data_sources.md for the full
#' methodology and citations. Run from the repository root:
#'   Rscript analysis/09_geographic_sensitivity.R

base::source("R/00_source_all.R")

base::message("=== Geographic sensitivity analysis ===")

model_parameters <- load_model_parameters("config/model_parameters.csv")
price_index_table <- load_price_index_table("data/cpi_medical_care.csv")

locality_indices <- readr::read_csv("data/cms_geographic_indices_2026.csv", show_col_types = FALSE)
pfs_rvus <- readr::read_csv("data/cms_pfs_rvus_2026.csv", show_col_types = FALSE)

# Only parameters with a directly verified CPT/setting RVU match are
# geographically adjusted. Pathology, the preop E/M visit, and anesthesia
# are deliberately left out until their exact Medicare payment/setting
# treatment is verified -- see docs/data_sources.md.
professional_mapping <- tibble::tribble(
  ~parameter, ~cpt, ~setting,
  "emb_office_professional_cost", "58100", "nonfacility",
  "emb_office_professional_cost_facility", "58100", "facility",
  "dc_professional_cost", "58120", "facility"
)

# labor_share = 0.60, the real CMS CY2026 OPPS labor-related share (Federal
# Register, 90 FR [2025-20907], Nov 25 2025: "The OPPS labor-related share
# is 60 percent of the national OPPS payment.") -- not a guessed default.
facility_mapping <- tibble::tribble(
  ~parameter, ~index_column, ~labor_share,
  "dnc_facility_or_asc_fee", "opps_wage_index", 0.60
)

geographic_analysis <- run_geographic_sensitivity(
  model_parameters = model_parameters,
  locality_indices = locality_indices,
  pfs_rvus = pfs_rvus,
  professional_mapping = professional_mapping,
  facility_mapping = facility_mapping,
  price_index_table = price_index_table
)

geographic_summary <- summarize_geographic_sensitivity(geographic_analysis)

saved_paths <- save_geographic_sensitivity(
  geographic_analysis = geographic_analysis,
  geographic_summary = geographic_summary,
  directory = "tables"
)

# Per-locality PSA error bars: re-runs run_probabilistic_sensitivity()
# under each locality's own geographically adjusted parameters, so the
# interval reflects uncertainty in the underlying cost/probability
# evidence AS PRICED at that locality -- not uncertainty about geography
# itself, which this analysis deliberately treats as deterministic (see
# R/geographic_sensitivity.R's file-level docblock and
# summarize_psa_cost_interval()'s docblock).
geographic_psa_intervals <- dplyr::bind_rows(purrr::map(
  locality_indices$locality_id,
  function(current_locality) {
    locality_label <- locality_indices %>%
      dplyr::filter(.data$locality_id == current_locality) %>%
      dplyr::pull(.data$locality_label)
    geographic_bundle <- build_geographic_overrides(
      model_parameters = model_parameters, locality_id = current_locality,
      locality_indices = locality_indices, pfs_rvus = pfs_rvus,
      professional_mapping = professional_mapping, facility_mapping = facility_mapping
    )
    locality_parameters <- override_model_parameters(
      model_parameters, geographic_bundle$overrides
    )
    summarize_psa_cost_interval(locality_parameters, price_index_table) %>%
      dplyr::mutate(locality_id = current_locality, locality_label = locality_label, .before = 1)
  }
))
save_table(geographic_psa_intervals, "geographic_psa_intervals.csv")

geographic_strategy_costs_with_ci <- geographic_analysis$strategy_costs %>%
  dplyr::left_join(
    geographic_psa_intervals, by = base::c("locality_id", "locality_label", "strategy")
  ) %>%
  dplyr::mutate(label = STRATEGY_LABELS[.data$strategy])

geo_dodge_position <- ggplot2::position_dodge(width = 0.9)

geographic_figure <- ggplot2::ggplot(
  geographic_strategy_costs_with_ci,
  ggplot2::aes(x = .data$locality_label, y = .data$expected_total_cost, fill = .data$label)
) +
  ggplot2::geom_col(position = geo_dodge_position) +
  ggplot2::geom_errorbar(
    ggplot2::aes(ymin = .data$ci_low, ymax = .data$ci_high),
    position = geo_dodge_position, width = 0.25, linewidth = 0.4, colour = "grey30"
  ) +
  ggplot2::geom_text(
    ggplot2::aes(y = .data$ci_high, label = scales::dollar(.data$ci_high, accuracy = 1)),
    position = geo_dodge_position, vjust = -0.5, size = 2.2, colour = "grey35"
  ) +
  ggplot2::scale_y_continuous(
    labels = scales::dollar_format(), expand = ggplot2::expansion(mult = c(0, 0.12))
  ) +
  ggplot2::scale_fill_brewer(palette = "Set1", name = "Strategy") +
  ggplot2::labs(
    x = NULL, y = "Expected cost per patient ($)",
    caption = "Error bars: 95% probabilistic-sensitivity-analysis interval, re-run under each locality's own geographically adjusted costs."
  ) +
  theme_journal() +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 20, hjust = 1))

ggplot2::ggsave(
  "figures/figure6_geographic_sensitivity.jpeg",
  plot = geographic_figure, width = 9, height = 6.5, device = "jpeg", dpi = 300
)
base::message("Saved figure to: figures/figure6_geographic_sensitivity.jpeg")

base::message("\n", geographic_summary$summary_sentence, "\n")

base::message("=== Geographic sensitivity analysis complete ===")
