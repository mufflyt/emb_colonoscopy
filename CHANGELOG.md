# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project does not use
semantic version numbers (there is no `DESCRIPTION`/package version), so entries are
grouped by date.

## 2026-08-28 (public-input acquisition)

### Added
- `R/meps_download.R`, `R/hpt_hospital_discovery.R`, `R/public_input_config.R`,
  `analysis/00_get_public_inputs.R`: a reproducible pipeline that downloads and
  validates the real 2024 MEPS office-visit and Jobs files, downloads the current CMS
  hospital list, and draws a fixed-seed (`20260828`), stratified (4 Census regions x
  3 ownership types x 10 hospitals) sample of 120 hospitals for the HPT layer.
- `R/cms_benchmarks.R` rewritten with year-aware CMS dataset resolution (walks the
  catalog's `distribution` array by format/year/`accessURL` rather than regex-parsing
  the top-level `identifier`), verified against live data to resolve the same UUID as
  the previous approach.
- `R/hpt_prices.R` rewritten to handle both CMS v3 tall and wide MRF CSV layouts
  (metadata rows before the real header, `code|1`/`code|2`/... columns, payer-pivoted
  wide columns), with per-hospital failure auditing instead of silent drops.
- `tests/testthat/test-public-inputs.R`: 13 test blocks (23 assertions) covering MEPS
  column validation, `cms-hpt.txt` parsing, domain normalization, Census
  region/ownership classification, deterministic stratified sampling, config writing,
  CMS year-resolution, and tall/wide HPT parsing.

### Fixed (all found by actually running the code against real or realistic data)
- **Data-masking name collision**, again, in a fresh delivery of `R/evidence_codes.R`
  (`sampling_code_vector()`) -- same bug as 2026-08-28 (evidence layer), reintroduced
  in a later delivery of the same file. Fixed the same way.
- **Data-masking name collision in `hpt_wide_metric_column()`** (`R/hpt_prices.R`):
  `dplyr::filter(.data$payer_name == payer_name, .data$plan_name == plan_name,
  .data$metric == metric)` had all three arguments colliding with same-named columns,
  making the filter always match every row and always return the first payer's price
  column regardless of which payer was requested. This one was caught by the author's
  own test on first execution (`Expected: 140, 110`, `Actual: 140, 140`) -- the test
  was right, it had simply never been run. Fixed with `.env$` on all three comparisons.
- **Real-vs-assumed CMS column name mismatch** (`download_cms_hospital_frame()`):
  code and the author's own synthetic test fixture both assumed a normalized column
  named `citytown`; CMS's real `"City/Town"` header actually normalizes to
  `city_town`. Only a live download (5,419 real hospitals) surfaced this, since the
  test shared the same wrong assumption as the implementation. Fixed by extracting
  `normalize_cms_hospital_frame_names()` as a pure, offline-testable function and
  adding a regression test using the real column name.
- Restored the silent-CMS-filter guard (dropped in the rewritten `04_cms_benchmarks.R`)
  and a stray `.data$` tidyselect deprecation warning.

### Verified against live data during this integration
- Full MEPS pipeline (download -> extract -> validate -> estimate) against the real
  2024 files: weighted office-visit total payment $308.10, out-of-pocket $57.38,
  weighted hourly wage $23.71, 4-hour avoided-visit time cost $94.85.
- CMS hospital sampling frame: 5,419 real hospitals downloaded, correctly classified
  into 4 regions x 3 ownership groups, and stratified-sampled to exactly 120 (10 per
  stratum).
- `cms-hpt.txt` discovery + parsing against one real hospital (NYU Langone): 5
  locations correctly parsed with location name, source page, MRF URL, and contact
  info. Not run in bulk across the full 120-hospital sample (see `docs/evidence_layers.md`).

## 2026-08-28 (evidence layer)

### Added
- CI: `.github/workflows/r-tests.yml` runs `tests/testthat.R` on every push and pull
  request to `main` via `r-lib/actions`. The suite is fully offline (no live API
  calls), so CI runs are deterministic. Status badge added to `README.md`.
- Evidence layer: `R/cms_benchmarks.R` (live CMS Medicare physician-fee API),
  `R/hpt_prices.R` (Hospital Price Transparency MRF ingestion), `R/meps_burden.R`
  (MEPS patient/societal burden), `R/evidence_codes.R` (shared HCPCS codebook),
  `R/evidence_synthesis.R` and `R/evidence_provenance.R` (formatting and provenance
  helpers), run via `analysis/06_evidence_layers.R`.
- `R/budget_impact.R`: scales per-patient savings to annual cohort sizes
  (10/25/50/100/1000 patients).
- `R/sensitivity_probabilistic.R`: `summarize_probability_cheapest()` reports what
  fraction of Monte Carlo draws each strategy was the least expensive, not just the
  mean incremental cost.
- `evidence_tier` column (A/B/C/D/structural) added to every row of
  `config/model_parameters.csv`, summarized by `summarize_evidence_tiers()`.
- `R/literature_replication.R`: a generic harness (`validate_against_published_model()`)
  for checking this repository's cost engine against a published study's own
  parameters, plus `literature_replication_status()` tracking Ladabaum et al. 2011
  (cross-checked), Yi et al. 2018, and Havrilesky et al. 2009 (both
  `pending_parameter_extraction` -- not fabricated).
- `analysis/07_manuscript_outputs.R`: consolidates Tables 1-9 (parameters, cost
  components, strategy comparison, one-way sensitivity, PSA summary, thresholds,
  budget impact, evidence tiers, validation status) into `tables/manuscript_*.csv`.
- Real BLS CPI-U Medical Care anchors (2010: 388.436; 2026: 593.781) in
  `data/cpi_medical_care.csv`, and a Ladabaum et al. 2011-anchored office-EMB cost
  cross-validation scenario (`office_cost_ladabaum_historical` in `R/scenarios.R`).
- `docs/evidence_layers.md`, `docs/reuse_mapping.md`, `docs/data_sources.md`,
  `docs/methods_notes.md`, `docs/validation_notes.md`.
- Initial repository build: `R/` cost-engine (parameters, validation, inflation,
  strategy costs, comparison, deterministic + probabilistic sensitivity, threshold
  analysis, scenarios, plotting, tables), `config/model_parameters.csv`,
  `data/cpi_medical_care.csv`, `analysis/01`-`05` scripts, `tests/testthat/` suite,
  `figures/`, `tables/`.

### Changed
- `emb_failure_lynch` base value changed from an ad hoc midpoint (0.17) to a pooled
  proportion across four named Lynch-specific studies (0.137 = 25/183 pooled events),
  with the four studies' numerators/denominators recorded in the parameter's notes.
- `R/cms_benchmarks.R::cms_query_hcpcs()` now verifies the requested filter field
  actually exists in the CMS API response and errors loudly if not, rather than
  silently returning an unfiltered dataset.

### Fixed
- **Data-masking name collision** in the (since-removed) APCD prototype's
  `sampling_code_vector()`: `dplyr::filter(.data$concept %in% concept)` had the
  function argument shadowed by a same-named data column, so every call silently
  returned every procedure code regardless of what was requested. Fixed with
  `.env$concept`.
- **Reversed inequality-join columns** in the same prototype's rescue-linkage logic:
  `dplyr::join_by(rescue_date > service_date, ...)` named columns from the wrong side
  of the join, causing a hard crash. Fixed by swapping to
  `service_date < rescue_date, followup_end >= rescue_date`.
- **CPI index-scale mismatch**: an early placeholder 2014 CPI value (100) sat on a
  disconnected scale from the real 2010/2026 BLS anchors (~390-590), producing a
  spurious ~5.9x inflation multiplier for the JAMA Surgery-sourced per-minute
  room/anesthesia costs. Replaced with a geometrically interpolated placeholder on
  the correct scale, and added a permanent sanity-check test
  (`tests/testthat/test-inflation.R`) against year-to-year implausible ratios.
- `dplyr::if_else()` in `compare_strategies_to_cheapest()` and a `min()`-on-empty
  warning in the rescue-linkage logic (vctrs recycling and eager branch-evaluation
  issues respectively).

### Removed
- APCD (all-payer claims database) claims-linkage layer: designed, built, and
  verified working on synthetic data (after the two bug fixes above), but removed
  because this project has no approved state APCD data use agreement. See
  `docs/evidence_layers.md`.
- CMS facility/OPPS benchmark layer: abandoned after confirming the public
  "Outpatient Hospitals by Provider and Service" dataset is keyed by APC code, not
  HCPCS/CPT code, and would require a HCPCS-to-APC crosswalk not currently available.
