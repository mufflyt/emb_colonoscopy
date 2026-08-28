base::message("Starting national colonoscopy-setting analysis.")

base::source("R/00_source_all.R")

years <- 2019:2024

base::message(
  "Input years: ",
  base::paste(years, collapse = ", ")
)

colonoscopy_tbl <- fetch_colonoscopy_physician_years(years)

base::message("Transformation 1: facility/nonfacility summary.")
place_tbl <- summarize_colonoscopy_place(colonoscopy_tbl)

base::message("Transformation 2: conservative code-set sensitivity.")
base_place_tbl <- summarize_base_code_place(colonoscopy_tbl)

base::message("Transformation 3: HCPCS service mix.")
code_mix_tbl <- summarize_colonoscopy_code_mix(colonoscopy_tbl)

base::message("Transformation 4: provider-state summary.")
state_tbl <- summarize_colonoscopy_state(colonoscopy_tbl)

base::message("Transformation 5: provider-RUCA summary.")
rurality_tbl <- summarize_colonoscopy_rurality(colonoscopy_tbl)

base::message("Transformation 6: provider-specialty summary.")
specialty_tbl <- summarize_colonoscopy_specialty(colonoscopy_tbl)

base::message("Transformation 7: Medicare allowed amounts.")
allowed_tbl <- summarize_colonoscopy_allowed(colonoscopy_tbl)

base::message("Transformation 8: provider concentration.")
concentration_tbl <- summarize_colonoscopy_concentration(
  colonoscopy_tbl
)

base::message("Transformation 9: ASC facility directory.")
asc_directory_tbl <- build_asc_colonoscopy_directory(
  colonoscopy_tbl
)

base::message("Transformation 10: ASC share of facility services.")
facility_type_tbl <- estimate_facility_type_share(
  colonoscopy_tbl
)

base::message("Transformation 11: observed setting decomposition.")
setting_decomposition_tbl <- decompose_colonoscopy_observed_settings(
  colonoscopy_tbl,
  data_year = base::max(years)
)

base::message("Transformation 12: longitudinal trend.")
trend_tbl <- fit_colonoscopy_facility_trend(place_tbl)
trend_sentence <- format_colonoscopy_trend_sentence(trend_tbl)
base::message("Dynamic summary: ", trend_sentence)

base::message("Creating publication figures.")
place_figure <- plot_colonoscopy_place_trend(place_tbl)
state_figure <- plot_state_facility_share(
  state_tbl,
  data_year = base::max(years)
)

base::message("Saving timestamped analysis products.")
save_colonoscopy_table(
  place_tbl,
  "tables",
  "colonoscopy_place_of_service"
)
save_colonoscopy_table(
  base_place_tbl,
  "tables",
  "colonoscopy_base_code_place_sensitivity"
)
save_colonoscopy_table(
  code_mix_tbl,
  "tables",
  "colonoscopy_code_mix"
)
save_colonoscopy_table(
  state_tbl,
  "tables",
  "colonoscopy_state_setting"
)
save_colonoscopy_table(
  rurality_tbl,
  "tables",
  "colonoscopy_ruca_setting"
)
save_colonoscopy_table(
  specialty_tbl,
  "tables",
  "colonoscopy_specialty"
)
save_colonoscopy_table(
  allowed_tbl,
  "tables",
  "colonoscopy_allowed_amounts"
)
save_colonoscopy_table(
  concentration_tbl,
  "tables",
  "colonoscopy_provider_concentration"
)
save_colonoscopy_table(
  asc_directory_tbl,
  "tables",
  "colonoscopy_asc_directory"
)
save_colonoscopy_table(
  facility_type_tbl,
  "tables",
  "colonoscopy_facility_type_estimate"
)
save_colonoscopy_table(
  setting_decomposition_tbl,
  "tables",
  "colonoscopy_observed_setting_decomposition"
)
save_colonoscopy_table(
  trend_tbl,
  "tables",
  "colonoscopy_facility_trend"
)
save_colonoscopy_figure(
  place_figure,
  "figures",
  "colonoscopy_place_trend"
)
save_colonoscopy_figure(
  state_figure,
  "figures",
  "colonoscopy_state_facility_share",
  width = 8,
  height = 10
)

summary_stamp <- base::format(
  base::Sys.time(),
  "%Y%m%d_%H%M%S"
)
summary_path <- base::file.path(
  "tables",
  base::paste0(
    "colonoscopy_dynamic_summary_",
    summary_stamp,
    ".txt"
  )
)
base::writeLines(trend_sentence, summary_path)
base::message("Saved dynamic summary: ", summary_path)

base::message("National colonoscopy-setting analysis complete.")
