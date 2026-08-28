base::message("Starting public-input bootstrap.")

base::source("R/09_download_meps.R")
base::source("R/10_hpt_discovery.R")
base::source("R/11_public_input_config.R")

base::message("Step 1: download and validate 2024 MEPS files.")

meps_inputs <- download_meps_2024(
  directory = "data-raw/meps/2024"
)

office_xlsx <- meps_inputs |>
  dplyr::filter(.data$key == "office") |>
  dplyr::pull(.data$xlsx_path)

jobs_xlsx <- meps_inputs |>
  dplyr::filter(.data$key == "jobs") |>
  dplyr::pull(.data$xlsx_path)

if (base::length(office_xlsx) != 1L ||
    base::length(jobs_xlsx) != 1L) {
  base::stop("Could not resolve both MEPS workbooks.")
}

base::message("Step 2: download CMS hospital sampling frame.")

hospital_frame <- download_cms_hospital_frame(
  directory = "data-raw/cms/hospitals"
)

base::message("Step 3: load or draw the fixed HPT hospital sample.")

resample_hpt <- base::tolower(
  base::Sys.getenv(
    "RESAMPLE_HPT",
    unset = "false"
  )
) %in% base::c("1", "true", "yes")

sample_bundle <- load_or_create_hpt_sample(
  hospital_frame,
  config_dir = "config",
  per_stratum = 10L,
  seed = 20260828L,
  resample = resample_hpt
)

hpt_sample <- sample_bundle$sample
sample_files <- sample_bundle$files

base::message(
  "Step 4: prefill hospital domains from a public URL index."
)

historical_hpt_index <- download_hpt_historical_index(
  directory = "data-raw/hpt/index"
)

domain_tbl <- prefill_hpt_domains(
  domain_path = sample_files$domain_path,
  index_tbl = historical_hpt_index
)

missing_domain_n <- base::sum(
  base::is.na(domain_tbl$website_domain) |
    !base::nzchar(domain_tbl$website_domain)
)

if (missing_domain_n > 0L) {
  base::message(
    "HPT domains still required for ",
    scales::comma(missing_domain_n),
    " sampled hospitals."
  )
  base::message(
    "Fill website_domain in: ",
    sample_files$domain_path
  )
  base::stop(
    "HPT domain mapping is incomplete. Fill it and rerun."
  )
}

base::message("Step 5: resolve CMS-mandated HPT TXT files.")

hpt_resolution <- resolve_hpt_manifest(
  sample_tbl = hpt_sample,
  domains_tbl = domain_tbl
)

resolution_files <- write_hpt_resolution_files(
  hpt_resolution,
  config_dir = "config"
)

if (base::nrow(hpt_resolution$failures) > 0L) {
  base::stop(
    "HPT resolution has ",
    base::nrow(hpt_resolution$failures),
    " failures. Review: ",
    resolution_files$failure_path
  )
}

if (base::nrow(hpt_resolution$manifest) != 120L) {
  base::stop(
    "Expected 120 resolved HPT hospitals; found ",
    base::nrow(hpt_resolution$manifest),
    "."
  )
}

base::message("Step 6: write analysis input configuration.")

config_path <- write_public_input_config(
  office_xlsx = office_xlsx,
  jobs_xlsx = jobs_xlsx,
  hpt_manifest = resolution_files$manifest_path,
  path = "config/public_inputs.R"
)

base::message("Public inputs are ready.")
base::message("MEPS office workbook: ", office_xlsx)
base::message("MEPS jobs workbook: ", jobs_xlsx)
base::message(
  "HPT manifest: ",
  resolution_files$manifest_path
)
base::message("Input config: ", config_path)

run_layers <- base::tolower(
  base::Sys.getenv(
    "RUN_EVIDENCE_LAYERS",
    unset = "false"
  )
) %in% base::c("1", "true", "yes")

if (run_layers) {
  base::message("RUN_EVIDENCE_LAYERS=true; starting analysis.")
  base::source("analysis/06_evidence_layers.R")
}
