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

geographic_figure <- ggplot2::ggplot(
  geographic_analysis$strategy_costs %>%
    dplyr::mutate(label = STRATEGY_LABELS[.data$strategy]),
  ggplot2::aes(x = .data$locality_label, y = .data$expected_total_cost, fill = .data$label)
) +
  ggplot2::geom_col(position = "dodge") +
  ggplot2::scale_y_continuous(labels = scales::dollar_format()) +
  ggplot2::scale_fill_brewer(palette = "Set1", name = "Strategy") +
  ggplot2::labs(x = NULL, y = "Expected cost per patient ($)") +
  theme_journal() +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 20, hjust = 1))

ggplot2::ggsave(
  "figures/figure6_geographic_sensitivity.jpeg",
  plot = geographic_figure, width = 9, height = 6.5, device = "jpeg", dpi = 300
)
base::message("Saved figure to: figures/figure6_geographic_sensitivity.jpeg")

base::message("\n", geographic_summary$summary_sentence, "\n")

base::message("=== Geographic sensitivity analysis complete ===")
