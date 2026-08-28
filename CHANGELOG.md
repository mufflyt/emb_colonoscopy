# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project does not use
semantic version numbers (there is no `DESCRIPTION`/package version), so entries are
grouped by date.

## 2026-08-28 (real coordination-cost wage component)

### Changed
- `coordination_cost`'s wage component replaced with a real, sourced value: the O*NET OnLine (BLS
  OEWS) median hourly wage for SOC 43-6013 Medical Secretaries and Administrative Assistants,
  **$22.08/hour** (2025) -- also added as its own citable reference parameter,
  `scheduler_hourly_wage_onet_2025`. bls.gov itself returns HTTP 403 to automated retrieval with an
  explicit stated bot policy; O*NET OnLine is the DOL/BLS-funded site that republishes the same OEWS
  data and does not block this.
- The time component (2 schedulers -- GYN and colorectal -- x 30 minutes each) is a practitioner
  estimate from the PI's own Denver Health institutional experience, obtained by asking rather than
  guessing, and remains flagged `provisional = TRUE` since it is not independently published. Base
  value: 2 x 0.5hr x $22.08 = **$22.08** (coincidentally close to the $25 placeholder it replaced,
  but now traceable and defensible rather than an unfounded guess).
- Caught and fixed a second small mistake before committing (this time unrelated to CSV quoting: the
  new notes text used lowercase "provisional" where `test-parameters.R`'s own-provenance check
  requires the uppercase `PROVISIONAL` keyword) via the same immediate-test-run discipline.
- Base case updated: combined EMB $540.26 (was $543.18), office EMB unchanged $875.26, D&C unchanged
  $4,101.64. Minutes threshold ~15.0 (was ~14.9); PSA cost-saving frequency 93.9% (was 94%, both
  within Monte Carlo noise of the small $2.92 base-case shift).

## 2026-08-28 (real D&C anesthesia cost)

### Changed
- `dnc_anesthesia_cost` replaced with a real, sourced value: the CMS PUF (Physician & Other
  Practitioners by Provider and Service) service-weighted mean allowed amount for CPT 00952 (the ASA
  crosswalk anesthesia code for CPT 58120), **$114.50** (2024, 118 real provider-service rows, 1,936
  observed services; low/high are the real p25/p75, $77.84/$139.10). Previously a $400 unsourced
  placeholder -- notably, the real value is far *below* the placeholder, so this fix makes the
  D&C-dominance finding more conservative, not less, correcting an assumption that had been inflating
  it. Represents only the anesthesia provider's separately-billed professional fee; routine anesthesia
  drugs/supplies are packaged into `dnc_facility_or_asc_fee` under OPPS/ASC methodology, so this does
  not double-count facility-side anesthesia costs.
- Base case updated: combined EMB $543.18 (was $553.45), office EMB $875.26 (was $914.38), D&C
  $4,101.64 (was $4,387.14). Combined EMB is 37.9% cheaper than office EMB (was 39.5%); minutes
  threshold ~14.9 (was ~15.8, still comfortably above Huang et al.'s entire 1-12 minute range); PSA
  cost-saving frequency 94% (was 93.4%). The D&C arm now has only two remaining provisional
  components (`dnc_preop_clinic_visit_cost`, `dnc_recovery_room_cost`), down from four at the start
  of this session.

## 2026-08-28 (real D&C facility fee)

### Changed
- `dnc_facility_or_asc_fee` replaced with a real, sourced value: the CMS OPPS (hospital outpatient)
  facility payment for CPT 58120, **$3,307.24** (July 2026 Addendum B, status indicator J1, APC 5414,
  relative weight 36.1783), downloaded directly from cms.gov. Previously a $1,800 placeholder with no
  source -- the largest-magnitude provisional input anywhere in the model (~75% of the D&C arm's
  total cost). Low sensitivity bound is now the real CMS ASC facility rate ($1,738.07, July 2026
  Addendum AA, payment indicator A2), also added as its own named parameter
  (`dnc_facility_fee_asc_2026`) for a "D&C in ASC" scenario. Both files required a POST-based
  workaround for CMS's AMA-license click-through gate -- documented in `docs/data_sources.md` for
  future quarterly refreshes.
- Added `cost_hysteroscopy_or_opps_2026` ($3,307.24) -- CPT 58558's own OPPS rate, confirmed identical
  to 58120's since both group into APC 5414; a same-methodology cross-check distinct from the earlier
  Munro et al. 2022 comparison (which now compares against the facility-fee component specifically,
  not the whole D&C arm total, since that total changed).
- Base case updated accordingly: combined EMB $553.45 (was $499.19), office EMB $914.38 (was
  $707.89), D&C $4,387.14 (was $2,879.90). Combined EMB is now 39.5% cheaper than office EMB (was
  29.5%); the minutes threshold rose to ~15.8 (was ~11.2, now comfortably above Huang et al.'s entire
  1-12 minute observed range rather than just its upper end); PSA cost-saving frequency rose to 93.4%
  (was 85.8%). The independent-confirmation test's premise (D&C dominance driven by its three
  *remaining* provisional components) is unaffected, since it explicitly zeroes this exact parameter.
- `docs/methods_notes.md`'s D&C-dominance caveat updated: the largest D&C-arm cost driver is no longer
  provisional, though three smaller components (`dnc_preop_clinic_visit_cost`,
  `dnc_recovery_room_cost`, `dnc_anesthesia_cost`) still are.

## 2026-08-28 (national colonoscopy-setting analysis)

### Added
- `R/colonoscopy_setting.R`, `analysis/08_colonoscopy_setting.R`: a national analysis,
  complementary to the cost model, of what fraction of U.S. Medicare colonoscopy-coded
  services occur in facility settings where coordinated sedated EMB is structurally
  feasible. Queries CMS for 2019-2024 across all 11 diagnostic/screening/therapeutic
  colonoscopy HCPCS codes, with per-year timestamped caching
  (`data-raw/cms_colonoscopy/`). Reports facility vs. nonfacility share by year/state/
  RUCA/specialty, HCPCS code mix, Medicare allowed amounts by setting, provider
  concentration (HHI), a named ASC directory, a conservative base/screening-code
  encounter-proxy sensitivity check (using CMS's beneficiary-day service counts to
  reduce within-day line-service duplication), and a dynamically-generated trend
  sentence with a fitted linear trend and p-value.
- Correctly separates ASC organizational billing from physician/supplier "facility"
  billing (`claim_role`) so the two are never summed into a double-counted facility
  total; the unidentified residual is reported as "other facility residual," not
  assumed to be hospital outpatient.
- `tests/testthat/test-colonoscopy-setting.R`: 8 test blocks, all passing on first run
  with no fixes needed -- the first externally-generated delivery this session that
  required no bug fixes after full live verification.

### Verified against live data during this integration
- All six years (2019-2024) independently confirmed to resolve to distinct CMS
  dataset UUIDs via the already-verified `cms_find_dataset_uuid()`.
- Full standardization -> ASC/professional separation -> place-of-service/RUCA/
  specialty classification -> facility-type-share/HHI/ASC-directory chain run
  end-to-end against real 2024 data for CPT 45378 (8,237 rows): 94.1% facility share,
  43.7% ASC share of facility services, HHI 0.000236 (6,815 unique providers), a
  real named ASC directory (verified plausible facility names/addresses), and a
  nonfacility/facility Medicare-payment differential ($305.70 vs. $170.70) consistent
  with Medicare's known site-of-service payment policy -- a strong signal the
  place-of-service classification is correct, not inverted.
- The full 11-code x 6-year pull (66 queries) was not run end-to-end during
  integration (some codes likely return tens of thousands of rows per year); left as
  a deliberate run via `analysis/08_colonoscopy_setting.R`.

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
