#' Instructions for replacing the placeholder price-index table
#'
#' This script is deliberately NOT wired to fetch or write data
#' automatically -- the repository must never commit a network credential,
#' institutional data pull, or unverified scrape as if it were a
#' validated public dataset. Instead this file documents exactly how a
#' human should replace `data/cpi_medical_care.csv` with a real
#' price index before this model is used for anything beyond development.
#'
#' Recommended index: BLS CPI-U Medical Care, series CUUR0000SAM
#'   https://www.bls.gov/cpi/data.htm
#'   (Databases > Top Picks > "Medical care" under CPI-U, U.S. city
#'   average, not seasonally adjusted.)
#'
#' Alternative index: CMS Medicare Economic Index (MEI), published
#' annually as part of the Medicare Physician Fee Schedule final rule.
#'   https://www.cms.gov/medicare/payment/fee-schedules/physician
#'
#' Current status of data/cpi_medical_care.csv:
#'   - 2010 (388.436) and 2026 (593.781): REAL BLS CPI-U Medical Care
#'     annual values, surfaced during literature review of Ladabaum et
#'     al. 2011 for the cost_emb_ladabaum_2010 cross-validation scenario.
#'     RECOMMEND independently re-confirming both against the live BLS
#'     series before publication -- they were not fetched directly by
#'     this repository's code.
#'   - 2014: still an ESTIMATED PLACEHOLDER (geometrically interpolated
#'     between the two real anchors above), needed for the
#'     Childers/Maggard-Gibbons JAMA Surgery per-minute OR/anesthesia
#'     cost parameters (procedure_room_cost_per_minute,
#'     direct_room_cost_per_minute, anesthesia_cost_per_minute).
#'
#' CAUTION -- a real bug this repository already hit once: do not add a
#' new year's index value to this table using a different, disconnected
#' scale (e.g. rebasing to 100) than the existing real anchors. Mixing
#' scales silently produces a nonsensical multiplicative adjustment
#' (this happened during development: a synthetic 2014=100 value next to
#' real 2010/2026 values ~390-590 produced a spurious ~5.9x inflation
#' factor). tests/testthat/test-inflation.R includes a sanity check on
#' year-to-year index ratios to catch this class of bug in the future --
#' keep that test passing when editing this file.
#'
#' Steps to close the remaining 2014 gap:
#'   1. Download the annual (not monthly) BLS CPI-U Medical Care value
#'      for 2014 from https://www.bls.gov/cpi/data.htm (series
#'      CUUR0000SAM).
#'   2. Replace the 2014 row in data/cpi_medical_care.csv with the real
#'      value, setting is_placeholder = FALSE.
#'   3. Re-run analysis/01_base_case.R and confirm the inflation-adjusted
#'      room/anesthesia costs change only modestly (the interpolated
#'      placeholder is already on the correct scale, so this should be a
#'      refinement, not a large swing).
#'
#' No PHI, institutional data, or credentials belong in this file or in
#' data/. Only publicly published index values should ever be committed.
