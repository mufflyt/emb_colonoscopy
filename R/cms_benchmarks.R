#' CMS Medicare benchmark queries
#'
#' Queries the public CMS data.cms.gov API by HCPCS code. Keeps the
#' professional (Physician & Other Practitioners) and facility (Outpatient
#' Hospitals) layers separate rather than treating them as contemporaneous
#' -- the physician file and the facility file are not released on the
#' same schedule. No API key is required; this hits a public endpoint.

cms_find_dataset_uuid <- function(title_pattern) {
  catalog_url <- "https://data.cms.gov/data.json"

  base::message("Reading CMS Open Data catalog.")

  response <- httr2::request(catalog_url) |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_perform()

  payload <- httr2::resp_body_json(
    response,
    simplifyVector = TRUE
  )

  catalog_tbl <- tibble::as_tibble(payload$dataset)

  match_tbl <- catalog_tbl |>
    dplyr::filter(
      stringr::str_detect(
        .data$title,
        stringr::regex(
          title_pattern,
          ignore_case = TRUE
        )
      )
    )

  if (base::nrow(match_tbl) != 1L) {
    base::stop(
      "CMS title matched ",
      base::nrow(match_tbl),
      " records: ",
      title_pattern
    )
  }

  # The catalog's `identifier` field is a full URL (e.g.
  # ".../dataset/<uuid>/data-viewer"), not a bare UUID -- extract the UUID
  # itself, which is what the data-api endpoints in cms_query_hcpcs()
  # expect.
  identifier_value <- match_tbl$identifier[[1]]
  uuid_pattern <- "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
  uuid <- stringr::str_extract(identifier_value, uuid_pattern)

  if (base::is.na(uuid)) {
    base::stop(
      "Could not extract a dataset UUID from CMS identifier: ", identifier_value
    )
  }

  base::message("Resolved CMS UUID: ", uuid)

  uuid
}

cms_extract_rows <- function(payload) {
  if (is.data.frame(payload)) {
    return(tibble::as_tibble(payload))
  }

  if (!is.null(payload$data) &&
      is.data.frame(payload$data)) {
    return(tibble::as_tibble(payload$data))
  }

  if (!is.null(payload$data) &&
      is.list(payload$data)) {
    return(dplyr::bind_rows(payload$data))
  }

  base::stop("Unrecognized CMS API response.")
}

cms_query_hcpcs <- function(uuid,
                            hcpcs_code,
                            hcpcs_field = "HCPCS_Cd",
                            page_size = 5000L) {
  base_url <- base::paste0(
    "https://data.cms.gov/data-api/v1/dataset/",
    uuid,
    "/data"
  )

  base::message("Querying CMS HCPCS: ", hcpcs_code)

  offset <- 0L
  page_list <- list()

  repeat {
    request_obj <- httr2::request(base_url)

    query_args <- list(
      size = page_size,
      offset = offset,
      `filter[filter-1][condition][path]` =
        hcpcs_field,
      `filter[filter-1][condition][operator]` =
        "=",
      `filter[filter-1][condition][value]` =
        hcpcs_code
    )

    request_obj <- rlang::exec(
      httr2::req_url_query,
      request_obj,
      !!!query_args
    )

    response <- request_obj |>
      httr2::req_retry(max_tries = 3) |>
      httr2::req_perform()

    payload <- httr2::resp_body_json(
      response,
      simplifyVector = TRUE
    )

    page_tbl <- cms_extract_rows(payload)

    if (offset == 0L && base::nrow(page_tbl) > 0L &&
        !hcpcs_field %in% base::names(page_tbl)) {
      # The CMS data-api silently ignores a filter condition on a field
      # that does not exist in the dataset, returning the ENTIRE
      # unfiltered table rather than erroring (confirmed empirically: an
      # OPPS "by Provider and Service" query filtered on "HCPCS_Cd" -- a
      # column that dataset does not have, since it is organized by APC
      # code instead -- silently returned 116,182 unfiltered rows). Fail
      # loudly instead of returning data that looks plausible but is not
      # actually filtered to the requested code.
      base::stop(
        "CMS dataset has no '", hcpcs_field, "' field to filter on -- got ",
        "columns: ", base::paste(base::names(page_tbl), collapse = ", "),
        ". This dataset may be organized by a different code (e.g. APC ",
        "rather than HCPCS); do not treat this result as filtered."
      )
    }

    if (base::nrow(page_tbl) == 0L) {
      break
    }

    page_list[[base::length(page_list) + 1L]] <-
      page_tbl

    if (base::nrow(page_tbl) < page_size) {
      break
    }

    offset <- offset + page_size
  }

  combined_tbl <- dplyr::bind_rows(page_list)

  base::message(
    "CMS HCPCS rows: ",
    scales::comma(base::nrow(combined_tbl))
  )

  combined_tbl
}

cms_sampling_benchmarks <- function(
    physician_uuid,
    hcpcs_codes = sampling_codebook()$code) {
  base::message("Building CMS professional benchmarks.")

  cms_tbl <- purrr::map_dfr(
    hcpcs_codes,
    function(code) {
      cms_query_hcpcs(
        uuid = physician_uuid,
        hcpcs_code = code
      )
    }
  )

  numeric_candidates <- c(
    "Avg_Sbmtd_Chrg",
    "Avg_Mdcr_Alowd_Amt",
    "Avg_Mdcr_Pymt_Amt",
    "Tot_Srvcs"
  )

  keep_numeric <- base::intersect(
    numeric_candidates,
    base::names(cms_tbl)
  )

  cms_tbl |>
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(keep_numeric),
        as.numeric
      )
    )
}

summarize_cms_benchmarks <- function(cms_tbl) {
  base::message("Summarizing CMS benchmark costs.")

  required_cols <- c(
    "HCPCS_Cd",
    "Avg_Mdcr_Alowd_Amt"
  )

  missing_cols <- base::setdiff(
    required_cols,
    base::names(cms_tbl)
  )

  if (base::length(missing_cols) > 0L) {
    base::stop(
      "CMS table missing: ",
      base::paste(missing_cols, collapse = ", ")
    )
  }

  cms_tbl |>
    dplyr::group_by(.data$HCPCS_Cd) |>
    dplyr::summarise(
      n_rows = dplyr::n(),
      mean_allowed = mean(
        .data$Avg_Mdcr_Alowd_Amt,
        na.rm = TRUE
      ),
      sd_allowed = stats::sd(
        .data$Avg_Mdcr_Alowd_Amt,
        na.rm = TRUE
      ),
      median_allowed = stats::median(
        .data$Avg_Mdcr_Alowd_Amt,
        na.rm = TRUE
      ),
      p25_allowed = stats::quantile(
        .data$Avg_Mdcr_Alowd_Amt,
        0.25,
        na.rm = TRUE
      ),
      p75_allowed = stats::quantile(
        .data$Avg_Mdcr_Alowd_Amt,
        0.75,
        na.rm = TRUE
      ),
      .groups = "drop"
    )
}


summarize_cms_facility_benchmarks <- function(
    cms_facility_tbl,
    code_field = "HCPCS_Cd",
    payment_field = "Avg_Tot_Pymt_Amt") {
  base::message("Summarizing CMS facility benchmarks.")

  required_cols <- c(
    code_field,
    payment_field
  )

  missing_cols <- base::setdiff(
    required_cols,
    base::names(cms_facility_tbl)
  )

  if (base::length(missing_cols) > 0L) {
    base::stop(
      "CMS facility table missing: ",
      base::paste(missing_cols, collapse = ", ")
    )
  }

  cms_facility_tbl |>
    dplyr::group_by(
      code = .data[[code_field]]
    ) |>
    dplyr::summarise(
      n_rows = dplyr::n(),
      mean_payment = mean(
        as.numeric(.data[[payment_field]]),
        na.rm = TRUE
      ),
      sd_payment = stats::sd(
        as.numeric(.data[[payment_field]]),
        na.rm = TRUE
      ),
      median_payment = stats::median(
        as.numeric(.data[[payment_field]]),
        na.rm = TRUE
      ),
      p25_payment = stats::quantile(
        as.numeric(.data[[payment_field]]),
        0.25,
        na.rm = TRUE
      ),
      p75_payment = stats::quantile(
        as.numeric(.data[[payment_field]]),
        0.75,
        na.rm = TRUE
      ),
      .groups = "drop"
    )
}
