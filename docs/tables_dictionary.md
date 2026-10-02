# Data dictionary: every CSV in `tables/` and `data/`

A column-by-column reference for every generated table and every raw/input data file in
this repository, so a reader doesn't have to open a CSV and guess what a column means or
grep `analysis/` to find out which script produced it. Strategy names recur across almost
every table and are not redefined per-table below: `office_emb` (standalone office
endometrial biopsy), `combined_emb` (biopsy during the already-scheduled colonoscopy), and
`dnc` (operative dilation and curettage) -- see `docs/clinical_coding_reference.md` Section
3.1 for the decision-tree structure these three strategies form.

This file describes structure, not current values -- it will go stale on units/columns
only if a script's output schema changes, not when a parameter's dollar value is refreshed.

## 1. `tables/` -- generated analysis outputs

### Base case (`analysis/01_base_case.R`)

**`strategy_comparison.csv`** -- the core per-strategy cost comparison.
`strategy`, `strategy_label` (human-readable name), `initial_cost` (before any
escalation), `escalation_probability` (chance of needing D&C after a failed sample),
`escalation_cost` (expected added cost from that chance), `expected_total_cost`
(`initial_cost` + probability-weighted `escalation_cost`), `incremental_cost_vs_cheapest`,
`pct_difference_vs_cheapest`, `is_cheapest` (boolean).

**`cost_components.csv`** -- the same base-case run, broken into line items instead of
totals. `strategy`, `component` (e.g. professional fee, pathology, anesthesia, facility
fee), `amount`.

**`pairwise_comparison.csv`** -- every strategy pair's head-to-head cost difference.
`strategy_a`, `strategy_b`, `cost_a`, `cost_b`, `absolute_difference`, `pct_difference`.

**`combined_vs_office.csv`** -- the single comparison the manuscript's abstract leads with.
`combined_emb_cost`, `office_emb_cost`, `incremental_cost_combined_vs_office`,
`pct_difference_combined_vs_office`, `combined_is_cost_saving` (boolean).

**`threshold_estimates_base_case.csv`** -- same schema as `threshold_estimates.csv` below,
computed within the base-case script rather than the dedicated threshold script.

**`budget_impact.csv`** -- cohort-level savings projection. `cohort_size`, `comparator`
(which strategy combined EMB is being compared against), `per_patient_savings`,
`annual_savings` (`per_patient_savings` x `cohort_size`).

### Deterministic one-way sensitivity (`analysis/02_deterministic_sensitivity.R`)

**`one_way_sensitivity.csv`** -- the data behind the tornado plot (`figure2_tornado.jpeg`).
`parameter`, `base_value`, `low_value`, `high_value`, `metric_at_base` (the outcome metric,
typically combined-vs-office incremental cost, at the parameter's base value),
`metric_at_low`, `metric_at_high`, `spread` (the tornado bar length: the range of the
outcome metric as this one parameter alone moves from low to high, every other parameter
held at base value).

### Probabilistic sensitivity analysis / PSA (`analysis/03_probabilistic_sensitivity.R`)

**`probabilistic_sensitivity_draws.csv`** -- the raw Monte Carlo draws (1,000 rows), one
row per simulated draw, every uncertain parameter varied simultaneously per its own
distribution. `draw` (index), `office_emb_cost`, `combined_emb_cost`, `dnc_cost`,
`incremental_cost_combined_vs_office`, `cheapest_strategy` (which of the three strategies
won this draw), plus per-strategy `*_neoplasia_delayed_per_1000` and `*_major_ae_per_1000`
(clinical-outcome companions to the cost draws, feeding the diagnostic-yield extension).

**`probabilistic_sensitivity_summary.csv`** -- `probabilistic_sensitivity_draws.csv`
collapsed to one row per strategy. `strategy`, `mean_cost`, `sd_cost`, `p2_5`, `p97_5` (95%
simulation interval bounds).

**`probabilistic_sensitivity_probability_cheapest.csv`** -- how often each strategy won.
`strategy`, `n_draws_cheapest`, `pct_draws_cheapest` (the source of the oft-quoted "91.4%
of draws" headline figure).

### Threshold analysis (`analysis/04_threshold_analysis.R`)

**`threshold_estimates.csv`** -- the break-even value at which a stated conclusion would
flip, one row per question. `question` (plain-English, e.g. "D&C facility fee at which D&C
becomes dominated by both alternatives," "Max coordination cost before combined loses its
advantage vs. office," "Max incremental colonoscopy-suite minutes before combined stops
being cheapest," "Office EMB failure probability at which combined becomes cost-saving vs.
office"), `parameter` (which parameter the question's root-finding search is over),
`threshold_value` (the break-even value found), `converged` (boolean -- did the numerical
search actually bracket a root), `search_lower`/`search_upper` (the search bounds used).
Underlies `figure3a_threshold_minutes.jpeg` and `figure3b_threshold_office_failure.jpeg`.

### Scenario analysis (`analysis/05_scenario_analysis.R`)

**`scenario_analysis.csv`** -- the base case re-run under alternative payer/historical
assumptions. `scenario` (`base_case_medicare`, `medicaid`, `commercial`,
`combined_without_preop_visit`, `office_cost_ladabaum_historical`), `strategy`,
`initial_cost`, `escalation_probability`, `escalation_cost`, `expected_total_cost`,
`scenario_description`, `scenario_provisional` (boolean -- flags scenarios resting on
provisional/placeholder multipliers rather than directly observed payer rates). Underlies
`figure5_scenario_comparison.jpeg`.

**`scenario_psa_intervals.csv`** -- PSA uncertainty intervals computed per scenario, not
just the base case. `scenario`, `strategy`, `mean_cost`, `sd_cost`, `ci_low`, `ci_high`.

### Geographic sensitivity (`analysis/09_geographic_sensitivity.R`, via `R/geographic_sensitivity.R`)

**`geographic_strategy_costs.csv`** -- per-strategy costs at each of the 4 tested
localities. `locality_id`, `locality_label` (National, Colorado, a low-cost locality, a
high-cost locality), `strategy`, `initial_cost`, `escalation_probability`,
`escalation_cost`, `expected_total_cost`.

**`geographic_adjustment_audit.csv`** -- the full audit trail of *how* each locality's
price differs from the national value, one row per adjusted parameter per locality.
`locality_id`, `locality_label`, `parameter`, `adjustment_type` (e.g. `pfs_gpci` for a
Physician Fee Schedule Geographic Practice Cost Index adjustment), `source_key` (e.g. the
CPT code and facility/nonfacility setting the GPCI was looked up for), `national_value`,
`multiplier` (the real CMS GPCI or OPPS wage-index value applied; `1` at the National row
by construction), `local_value` (`national_value` x `multiplier`). This is the file to
check if a geographic result looks surprising -- it shows exactly which CMS index value
produced it, nothing invented.

**`geographic_sensitivity_summary.csv`** -- one row per locality, the headline comparison.
`locality_id`, `locality_label`, `combined_emb_cost`, `office_emb_cost`, `dnc_cost`,
`combined_vs_office`, `combined_savings_vs_office`, `combined_cheaper_than_office`
(boolean), `combined_savings_vs_dnc`. Underlies `figure6_geographic_sensitivity.jpeg`.

**`geographic_psa_intervals.csv`** -- PSA uncertainty intervals computed per locality.
`locality_id`, `locality_label`, `strategy`, `mean_cost`, `sd_cost`, `ci_low`, `ci_high`.

### Diagnostic yield (`analysis/13_diagnostic_yield.R`)

**`diagnostic_yield.csv`** -- the additive clinical-outcome extension (not part of the
base-case cost comparison). `strategy`, `disease` (`cancer` or `precancer`),
`escalation_probability`, `detection_probability` (probability this strategy ultimately
detects the disease, accounting for escalation to D&C on a failed sample).

### Societal perspective (`analysis/14_societal_perspective.R`)

**`societal_perspective.csv`** -- adds patient time cost to the healthcare-sector cost, a
secondary analysis, both preop-visit scenarios. `scenario`
(`base_case_preop_visit_required` or `no_separate_combined_preop_visit`), `strategy`,
`expected_encounters` (how many in-person visits this strategy requires, probability-
weighted for escalation), `patient_time_cost_per_encounter` (a MEPS-derived wage-based time
cost, constant across strategies), `societal_addon` (`expected_encounters` x
`patient_time_cost_per_encounter`), `healthcare_sector_cost` (the same cost reported
elsewhere in this model), `societal_total_cost` (the sum of the two).

### Cost-effectiveness (`analysis/15_cost_effectiveness.R`)

**`cost_effectiveness.csv`** -- cost-consequence secondary analysis, both disease types.
`strategy`, `disease` (`cancer` or `precancer`), `cost`, `effect` (detection probability
from `diagnostic_yield.csv`), `status` (`on_frontier` if not strictly dominated by a
cheaper-and-more-effective alternative), `icer` (incremental cost-effectiveness ratio
vs. the next-cheapest frontier strategy; `NA` for the cheapest strategy itself, which has
no "incremental" comparator below it).

### Colonoscopy opportunity cost (`analysis/16_opportunity_cost_colonoscopy.R`)

**`colonoscopy_opportunity_cost_bound.csv`** -- the commercial-margin-based ceiling on what
displacing a colonoscopy-suite slot for a combined-EMB add-on could reasonably cost, across
6 real hospitals. `state_abbr`, `hospital`, `medicare_rate`, `commercial_mean_rate`,
`commercial_margin` (`commercial_mean_rate` - `medicare_rate`), `opportunity_cost_ceiling`
(the bound itself, derived from `commercial_margin`).

### Manuscript-specific outputs (`analysis/07_manuscript_outputs.R`, `analysis/11_manuscript_table10_summary.R`)

These largely re-derive or reformat tables already listed above into the manuscript's
exact Table 1-10 numbering and column labels (CHEERS-compliant headers, human-readable
units in parentheses). Each is noted only where its schema adds information not already
covered above.

- **`manuscript_table1_parameters.csv`** -- every model parameter, manuscript-formatted:
  `parameter`, `category`, `strategy`, `description`, `base_value`, `unit`, `low_value`,
  `high_value`, `distribution`, `dollar_year`, `source`, `evidence_tier`, `provisional`,
  `notes`. The manuscript's copy of `config/model_parameters.csv`'s own columns (minus the
  `gamma_alpha`/`gamma_rate` distribution-fitting internals) -- see
  `docs/vignettes/03_interpreting_evidence_tiers_and_sensitivity.md` for how to read
  `evidence_tier`.
- **`manuscript_table2_cost_components.csv`** -- manuscript copy of `cost_components.csv`.
- **`manuscript_table3_strategy_comparison.csv`** -- manuscript copy of
  `strategy_comparison.csv`.
- **`manuscript_table4_one_way_sensitivity.csv`** -- manuscript copy of
  `one_way_sensitivity.csv`.
- **`manuscript_table5_psa_summary.csv`** -- manuscript copy of
  `probabilistic_sensitivity_summary.csv`.
- **`manuscript_table6_thresholds.csv`** -- manuscript copy of `threshold_estimates.csv`.
- **`manuscript_table7_budget_impact.csv`** -- manuscript copy of `budget_impact.csv`.
- **`manuscript_table8_evidence_tiers.csv`** -- the tier-count rollup.
  `evidence_tier` (`A`/`B`/`C`/`D`/`structural`), `n_parameters`, `pct_parameters`. Built by
  `summarize_evidence_tiers()` (`R/evidence_synthesis.R`) directly from the live parameter
  table, not hand-counted.
- **`manuscript_table9_validation_status.csv`** -- independent-verification tracking, not
  a model output. `study` (an external paper this model's numbers are checked against),
  `target_description` (what specifically is being checked), `status`
  (`cross_checked`/`extracted_structurally_incomparable`/`pending_parameter_extraction`,
  etc.), `notes` (often a paragraph explaining *why* a numeric match was or wasn't
  attempted -- see `docs/validation_notes.md` for the full reasoning behind entries like
  Yi et al. 2018, where this repository deliberately did not force a numeric match against
  a structurally different decision-tree model).
- **`manuscript_table10_summary.csv`** -- the combined cost-and-clinical-outcome summary
  table (human-readable column headers with units, e.g. `"Initial cost ($)"`,
  `"Major adverse events per 1,000"`), built from the same PSA draws the manuscript's
  Results text cites.

### Evidence layer (`analysis/06_evidence_layers.R`)

**`evidence_cms_professional_benchmarks.csv`** -- live CMS Physician & Other Practitioners
PUF benchmarks for this model's CPT codes, used to sanity-check parameters against a
second, independently-pulled CMS extract. `HCPCS_Cd`, `n_provider_service_rows`,
`total_services`, `service_weighted_mean_allowed`, `mean_allowed`, `sd_allowed`,
`median_allowed`, `p25_allowed`, `p75_allowed`.

*(`evidence_hpt_price_summary.csv` and `evidence_meps_office_visit_cost.csv`/
`evidence_meps_patient_time_cost.csv` are also written by this script when the optional
HPT manifest/MEPS input files are present, but are not currently checked into `tables/` --
re-run `analysis/06_evidence_layers.R` with those inputs available to regenerate them.)*

### Hospital MRF map (`analysis/19_hospital_mrf_map.R`)

**`hospital_mrf_points.csv`** -- one row per hospital behind
`figures/figure8_hospital_mrf_map.jpeg`, from either the 74-hospital FREIDA sample or the
6-hospital convenience sample (de-duplicated where a hospital appears in both). `hospital`,
`state`, `coverage` (`full` if every code attempted at that hospital was usable, else
`partial`), `lat`/`lon` (approximate, joined from `data/gyn_onc_hospital_cities.csv`
below), `coordinate_source`. See `docs/mrf_hospital_data_overview.md` for the
hospital-level list this table summarizes.

### Adverse-event costing evidence (built within `R/strategy_costs.R`)

**`ae_cost_evidence_table.csv`** -- the full D&C uterine-perforation management-pathway
cost evidence, the CSV companion to `docs/ae_cost_evidence_table.md`'s prose. `event` (e.g.
uterine perforation), `event_probability`, `population` (which study population the
probability was observed in), `management_state` (e.g. observation, laparoscopy-only,
immediate laparotomy, laparoscopy-converted-to-laparotomy), `p_management_given_event`
(conditional probability of this management pathway given the event occurred), `unit_cost`
(`NA`/"UNSOURCEABLE" for the laparotomy pathways -- see
`docs/clinical_coding_reference.md`'s CPT 49000 note), `cost_source`, `evidence_tier`,
`provisional`, `notes`.

## 2. `data/` -- raw/input data

**`cms_geographic_indices_2026.csv`** -- real CMS Physician Fee Schedule GPCI values and
OPPS wage index, one row per Medicare payment locality. `locality_id`, `locality_label`,
`gpci_work`, `gpci_pe` (practice expense), `gpci_mp` (malpractice), `opps_wage_index`.
Feeds `analysis/09_geographic_sensitivity.R`; see `geographic_adjustment_audit.csv` above
for exactly how each value gets applied.

**`cms_pfs_rvus_2026.csv`** -- real CMS Physician Fee Schedule relative value units for
this model's CPT codes, by site of service. `cpt`, `setting` (facility/nonfacility),
`work_rvu`, `pe_rvu`, `mp_rvu`. The RVU half of the GPCI calculation above.

**`cpi_medical_care.csv`** / **`cpi_all_items.csv`** -- BLS Consumer Price Index series
used to inflate historical-dollar parameters to the model's current reference year.
`year`, `index_value`, `index_source`, `is_placeholder` (boolean -- flags any year not yet
backed by a real downloaded BLS value; see `data-raw/00_get_price_index.R` for how to
replace a placeholder).

**`colonoscopy_multi_hospital_rates.csv`** -- the original 6-hospital real-MRF payer-rate
sample (predates the 74-hospital FREIDA sample). `state_abbr`, `hospital`,
`medicare_rate`, `commercial_mean_rate`, `medicare_confidence`, `commercial_confidence`,
`notes`, `commercial_to_medicare_ratio`, `source`. Feeds
`analysis/16_opportunity_cost_colonoscopy.R`'s commercial-margin ceiling. Does not feed
`config/model_parameters.csv` or the base-case cost engine.

**`gyn_onc_fellowship_programs_freida.csv`** -- the 75-hospital sampling frame (ACGME-
accredited gynecologic oncology fellowship programs, per AMA's FREIDA directory).
`program_name`, `city`, `state`, `source`, `accessed_date`.

**`gyn_onc_hospital_payer_rates.csv`** -- the 74-hospital payer-rate sample built from that
frame's hospitals' own CMS price-transparency MRFs (414 rows, one per hospital x CPT code).
`hospital`, `state`, `cpt_code`, `cpt_description`, `rate_basis`, `medicare_proxy_type`
(`FFS`/`MA`/`not_found` -- see `docs/clinical_coding_reference.md`'s facility/nonfacility
note for why this distinction matters), `medicare_proxy_low`, `medicare_proxy_high`,
`medicare_confidence`, `commercial_low`, `commercial_high`, `commercial_n_payers`,
`commercial_confidence`, `notes`, `source_url`, `access_date`. Full method and the 7
zero-data hospitals' reasons: `docs/data_sources.md`'s "Hospital payer-rate sample
expansion" section and `docs/vignettes/02_adding_a_new_hospital_payer_rate.md`. Does not
feed `config/model_parameters.csv` or the base-case cost engine.

**`gyn_onc_hospital_cities.csv`** -- approximate home-city coordinates for every hospital
in the two MRF samples above, used only by `analysis/19_hospital_mrf_map.R`. `hospital`,
`city`, `state`, `lat`, `lon`, `coordinate_source` (one of: an exact match against the U.S.
Census Bureau's 2024 Gazetteer Places file; a Gazetteer Counties centroid, for the two
NYC-borough hospitals -- Bronx, Brooklyn -- that are not their own Census place; or the
nearest incorporated city's Gazetteer Places coordinate, for La Jolla, CA, an
unincorporated San Diego neighborhood with no Census place of its own). These are
city-level approximations, not geocoded hospital street addresses -- see
`R/hospital_mrf_map.R`'s file-level docblock for why.

## 3. Plain-text summary outputs

**`tables/summary_sentence.txt`** (`analysis/01_base_case.R`) and
**`tables/manuscript_summary_sentence.txt`** (`analysis/07_manuscript_outputs.R`) -- a
single auto-generated sentence stating the base-case headline result, built directly from
the same numbers as `strategy_comparison.csv`/`combined_vs_office.csv` rather than
hand-typed, so the prose can never silently drift from the data it describes.
