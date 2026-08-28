#' Hospital Price Transparency (machine-readable file) ingestion
#'
#' Reads a hospital's CMS-format MRF (from a direct URL listed in
#' `config/hpt_mrf_manifest_template.csv`) and extracts negotiated-dollar
#' prices plus the 2026 median/10th/90th-percentile allowed-amount fields
#' for the target CPT codes, using pattern-matched column lookup since MRF
#' column names are not standardized across hospitals.

read_hpt_csv <- function(path_or_url) {
  base::message("Reading hospital MRF: ", path_or_url)

  duckplyr::read_csv_duckdb(
    path = path_or_url,
    prudence = "stingy",
    options = list(
      header = TRUE,
      all_varchar = TRUE
    )
  )
}

find_hpt_column <- function(column_names,
                            patterns,
                            required = TRUE) {
  matches <- purrr::map(
    patterns,
    function(pattern) {
      column_names[
        stringr::str_detect(
          column_names,
          stringr::regex(
            pattern,
            ignore_case = TRUE
          )
        )
      ]
    }
  ) |>
    unlist() |>
    unique()

  if (base::length(matches) == 0L && required) {
    base::stop(
      "Could not locate HPT column: ",
      base::paste(patterns, collapse = " | ")
    )
  }

  if (base::length(matches) == 0L) {
    return(NA_character_)
  }

  matches[[1]]
}

extract_hpt_sampling_prices <- function(
    hpt_tbl,
    codes = c("58100", "58120", "58558", "88305")) {
  base::message("Extracting sampling prices from MRF.")

  column_names <- base::names(hpt_tbl)

  code_col <- find_hpt_column(
    column_names,
    c("^code$", "code\\|1$", "billing.*code")
  )

  payer_col <- find_hpt_column(
    column_names,
    c("payer.*name", "^payer_name$"),
    required = FALSE
  )

  plan_col <- find_hpt_column(
    column_names,
    c("plan.*name", "^plan_name$"),
    required = FALSE
  )

  median_col <- find_hpt_column(
    column_names,
    c("median.*allowed", "median_amount"),
    required = FALSE
  )

  p10_col <- find_hpt_column(
    column_names,
    c("10th.*allowed", "10.*percentile"),
    required = FALSE
  )

  p90_col <- find_hpt_column(
    column_names,
    c("90th.*allowed", "90.*percentile"),
    required = FALSE
  )

  negotiated_col <- find_hpt_column(
    column_names,
    c(
      "payer.*specific.*negotiated.*dollar",
      "negotiated.*dollar"
    ),
    required = FALSE
  )

  filtered_tbl <- hpt_tbl |>
    dplyr::filter(.data[[code_col]] %in% codes) |>
    as.data.frame() |>
    tibble::as_tibble()

  base::message(
    "Materialized ",
    scales::comma(base::nrow(filtered_tbl)),
    " target MRF rows."
  )

  get_col <- function(column_name) {
    if (is.na(column_name)) {
      return(rep(NA_character_, nrow(filtered_tbl)))
    }

    filtered_tbl[[column_name]]
  }

  filtered_tbl |>
    dplyr::transmute(
      code = as.character(.data[[code_col]]),
      payer_name = get_col(payer_col),
      plan_name = get_col(plan_col),
      negotiated_dollar = suppressWarnings(
        as.numeric(get_col(negotiated_col))
      ),
      allowed_p10 = suppressWarnings(
        as.numeric(get_col(p10_col))
      ),
      allowed_median = suppressWarnings(
        as.numeric(get_col(median_col))
      ),
      allowed_p90 = suppressWarnings(
        as.numeric(get_col(p90_col))
      )
    )
}

summarize_hpt_prices <- function(price_tbl) {
  base::message("Summarizing commercial MRF prices.")

  price_tbl |>
    dplyr::group_by(.data$code) |>
    dplyr::summarise(
      n_price_rows = dplyr::n(),
      mean_negotiated = mean(
        .data$negotiated_dollar,
        na.rm = TRUE
      ),
      sd_negotiated = stats::sd(
        .data$negotiated_dollar,
        na.rm = TRUE
      ),
      median_negotiated = stats::median(
        .data$negotiated_dollar,
        na.rm = TRUE
      ),
      p25_negotiated = stats::quantile(
        .data$negotiated_dollar,
        0.25,
        na.rm = TRUE
      ),
      p75_negotiated = stats::quantile(
        .data$negotiated_dollar,
        0.75,
        na.rm = TRUE
      ),
      .groups = "drop"
    )
}


read_hpt_manifest <- function(path) {
  base::message("Reading HPT manifest: ", path)

  manifest_tbl <- readr::read_csv(
    file = path,
    show_col_types = FALSE
  )

  required_cols <- c(
    "hospital_name",
    "hospital_state",
    "mrf_url"
  )

  missing_cols <- base::setdiff(
    required_cols,
    base::names(manifest_tbl)
  )

  if (base::length(missing_cols) > 0L) {
    base::stop(
      "HPT manifest missing: ",
      base::paste(missing_cols, collapse = ", ")
    )
  }

  manifest_tbl
}

extract_hpt_manifest_prices <- function(manifest_tbl,
                                        codes = c(
                                          "58100",
                                          "58120",
                                          "58558",
                                          "88305"
                                        )) {
  base::message("Processing HPT manifest.")

  purrr::pmap_dfr(
    manifest_tbl,
    function(hospital_name,
             hospital_state,
             mrf_url,
             ...) {
      hpt_tbl <- read_hpt_csv(mrf_url)

      price_tbl <- extract_hpt_sampling_prices(
        hpt_tbl = hpt_tbl,
        codes = codes
      )

      price_tbl |>
        dplyr::mutate(
          hospital_name = hospital_name,
          hospital_state = hospital_state
        )
    }
  )
}
