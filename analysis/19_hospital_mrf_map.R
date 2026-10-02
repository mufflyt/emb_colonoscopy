#!/usr/bin/env Rscript
#' Static map of hospitals with usable MRF-derived payer-rate data
#'
#' Neither hospital sample this map summarizes feeds config/model_parameters.csv
#' or the base-case cost engine -- this is a documentation/transparency figure,
#' not a model output. See docs/mrf_hospital_data_overview.md for the full
#' hospital-level list and R/hospital_mrf_map.R for how each hospital's
#' approximate city-level coordinates were derived (Census Bureau Gazetteer
#' Files, not a geocoded street address). Run from the repository root:
#'   Rscript analysis/19_hospital_mrf_map.R

base::source("R/00_source_all.R")

base::message("=== Static map of hospitals with usable MRF-derived payer-rate data ===")

hospital_payer_rates <- readr::read_csv(
  "data/gyn_onc_hospital_payer_rates.csv", show_col_types = FALSE
)
colonoscopy_hospital_rates <- load_colonoscopy_hospital_rates_table()

hospital_points <- build_hospital_mrf_points(
  hospital_payer_rates, colonoscopy_hospital_rates
)

base::message(
  base::nrow(hospital_points), " hospitals with usable data across ",
  dplyr::n_distinct(hospital_points$state), " states."
)

save_table(hospital_points, "hospital_mrf_points.csv")

hospital_map <- plot_hospital_mrf_map(hospital_points)
ggplot2::ggsave(
  "figures/figure8_hospital_mrf_map.jpeg",
  plot = hospital_map, width = 9, height = 6, device = "jpeg", dpi = 300
)
base::message("Saved figure to: figures/figure8_hospital_mrf_map.jpeg")

base::message("=== Hospital MRF map complete ===")
