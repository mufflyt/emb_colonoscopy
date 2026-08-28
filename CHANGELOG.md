# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project does not use
semantic version numbers (there is no `DESCRIPTION`/package version), so entries are
grouped by date.

## 2026-08-28

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
