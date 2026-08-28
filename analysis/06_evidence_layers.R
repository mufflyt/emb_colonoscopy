#!/usr/bin/env Rscript
#' Evidence-layer pipeline: CMS professional, Hospital Price Transparency,
#' MEPS
#'
#' Runs the empirical "evidence layer" analyses documented in
#' docs/evidence_layers.md. Only the CMS professional-fee layer runs
#' against live, no-setup-required public data; the HPT and MEPS layers
#' are conditional on external files that are never committed to this
#' repository. A layer with no data available logs why it was skipped
#' and moves on rather than failing the whole script. Run from the
#' repository root:
#'   Rscript analysis/06_evidence_layers.R
#'
#' Two layers considered during design were deliberately NOT built here
#' -- see docs/evidence_layers.md for the full reasoning:
#'   - An APCD (state all-payer claims database) linkage layer was
#'     prototyped and worked on synthetic data, but was dropped: it
#'     requires an approved state data use agreement this project does
#'     not have, and the model does not need patient-linked claims to
#'     answer its core question.
#'   - A CMS facility/OPPS layer was attempted and abandoned after
#'     confirming the public "Outpatient Hospitals by Provider and
#'     Service" dataset is keyed by APC code, not HCPCS/CPT code, and
#'     that the CMS data-api silently ignores a filter on a field that
#'     does not exist rather than erroring -- so a naive by-HCPCS query
#'     against it returns the entire unfiltered dataset. A HCPCS->APC
#'     crosswalk (e.g. the annual OPPS Addendum B) would be needed first.

base::source("R/00_source_all.R")

base::message("=== Evidence-layer pipeline ===")
print(evidence_layer_catalog())

# ---------------------------------------------------------------------
# Layer: CMS Medicare professional benchmarks (public data.cms.gov API,
# no credentials required). Network-dependent, so failures are caught and
# reported rather than aborting the rest of the pipeline.
# ---------------------------------------------------------------------
base::message("Layer: CMS Medicare professional benchmarks.")

cms_layer_result <- base::tryCatch(
  {
    physician_uuid <- cms_find_dataset_uuid(
      "Medicare Physician.*Other Practitioners.*by Provider and Service"
    )
    cms_tbl <- cms_sampling_benchmarks(physician_uuid)
    cms_summary <- summarize_cms_benchmarks(cms_tbl)
    save_table(cms_summary, "evidence_cms_professional_benchmarks.csv")
    cms_summary
  },
  error = function(condition) {
    base::message(
      "  Skipping: could not query the CMS data API (", conditionMessage(condition),
      "). This layer requires live network access to data.cms.gov."
    )
    NULL
  }
)

# ---------------------------------------------------------------------
# Layer: Hospital Price Transparency (commercial negotiated/allowed
# amounts). Requires a real manifest of hospital MRF URLs -- copy
# config/hpt_mrf_manifest_template.csv to config/hpt_mrf_manifest.csv and
# fill it in. That file is git-ignored so real hospital selections never
# get committed.
# ---------------------------------------------------------------------
base::message("Layer: hospital price transparency.")

hpt_manifest_path <- "config/hpt_mrf_manifest.csv"

if (base::file.exists(hpt_manifest_path)) {
  hpt_manifest <- read_hpt_manifest(hpt_manifest_path)
  hpt_prices <- extract_hpt_manifest_prices(hpt_manifest)
  hpt_summary <- summarize_hpt_prices(hpt_prices)
  save_table(hpt_summary, "evidence_hpt_price_summary.csv")
} else {
  base::message(
    "  Skipping: ", hpt_manifest_path, " not found. Copy ",
    "config/hpt_mrf_manifest_template.csv to ", hpt_manifest_path,
    " and fill in real hospital MRF URLs to run this layer. Selecting which ",
    "hospitals to include is a study-design decision, not something this ",
    "script makes for you."
  )
}

# ---------------------------------------------------------------------
# Layer: MEPS patient/societal burden. Requires the 2024 MEPS
# office-based visit and Jobs public-use files (large files, downloaded
# separately -- never committed to this repository).
# ---------------------------------------------------------------------
base::message("Layer: MEPS patient and societal burden.")

meps_office_path <- base::Sys.getenv("MEPS_OFFICE_XLSX")
meps_jobs_path <- base::Sys.getenv("MEPS_JOBS_XLSX")

if (base::nzchar(meps_office_path) && base::nzchar(meps_jobs_path)) {
  office_visit_cost <- estimate_meps_office_visit_cost(
    read_meps_xlsx(meps_office_path)
  )
  hourly_wage <- estimate_meps_hourly_wage(read_meps_xlsx(meps_jobs_path))
  patient_time_cost <- estimate_patient_time_cost(hourly_wage, avoided_hours = 4)

  save_table(office_visit_cost, "evidence_meps_office_visit_cost.csv")
  save_table(patient_time_cost, "evidence_meps_patient_time_cost.csv")
} else {
  base::message(
    "  Skipping: MEPS_OFFICE_XLSX/MEPS_JOBS_XLSX not set. Download the 2024 ",
    "MEPS office-based visit and Jobs public-use files and point these ",
    "environment variables at them to run this layer."
  )
}

base::message("=== Evidence-layer pipeline complete ===")
