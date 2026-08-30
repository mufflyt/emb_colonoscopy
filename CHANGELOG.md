# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project does not use
semantic version numbers (there is no `DESCRIPTION`/package version), so entries are
grouped by date.

## 2026-08-30 (combined_requires_preop_office_visit flipped to TRUE -- base case changes)

### Changed
- Per the model owner's clinical practice (Tyler Muffly, MD, Denver Health): the combined strategy's
  protocol includes a separate preoperative office visit before the colonoscopy date, for consent and
  risk assessment specific to adding EMB. `combined_requires_preop_office_visit` flipped from `FALSE`
  to `TRUE`, `provisional` cleared, re-tiered from D to `structural` (matches `reference_dollar_year`
  -- a modeling convention, not a literature-evidence claim).
- This adds `office_visit_em_cost` ($88.76) to the combined arm's cost via the `preop_office_visit`
  component in `compute_combined_emb_strategy_cost()`. Scenario analysis can still set this back to
  `FALSE` to model consent/risk assessment folded into existing care (the prior base-case assumption).
- Three tests updated for the new default: `test-parameters.R`'s boolean-parsing test now expects
  `TRUE`; `test-strategy-costs.R`'s preop-visit test rewritten to explicitly compare FALSE vs. TRUE
  overrides rather than relying on the (now-changed) default, and now also asserts the
  `preop_office_visit` component's presence/absence directly; `test-independent-confirmation.R`'s
  hand-derived combined-arm formula updated to include the preop visit cost when the toggle is TRUE.
- Base case updated: combined EMB **$574.77** (was $486.01), office EMB unchanged at $780.23, D&C
  unchanged at $3,827.04. Combined EMB is **26.3%** cheaper than office EMB (was 37.7%); minutes
  threshold **~11.1** (was ~13.8); PSA cost-saving frequency **79.7%** (was 92.3%). Provisional count
  down to 4 of 41 (was 5 of 41).

## 2026-08-30 (office_to_dnc_escalation_fraction grounded with an analogous real citation)

### Changed
- Searched for Lynch-specific data on `office_to_dnc_escalation_fraction` (fraction of failed office
  EMB attempts that proceed to D&C vs. a repeat office attempt), currently a 100% placeholder.
- The four Lynch EMB-failure studies underlying `emb_failure_lynch` (Elmasry 2009, Lecuru 2008,
  Rijcken 2003, Woolderink 2020) are all confirmed hard-paywalled with no free full text found
  anywhere -- a genuine access barrier, not an unsearched gap.
- Checked the two MD Anderson combined-screening papers already used elsewhere in this model: Huang
  et al. 2011 has no mention of escalation pathways anywhere in its full text. Nebgen et al. 2014
  (already the source of `combined_to_dnc_probability`) states its protocol explicitly: "If cervical
  stenosis or insufficient endometrial tissue was encountered, hysteroscopy and dilation and
  curettage were scheduled" -- real, quotable evidence that this Lynch-surveillance program's own
  protocol escalates 100% of EMB failures straight to D&C with no repeat-office step.
- `office_to_dnc_escalation_fraction`'s source/notes updated to cite this quote; re-tiered from D
  (unfounded placeholder) to C (general/adjacent Lynch-surveillance evidence). **Base value stays at
  100% and `provisional` stays `TRUE`** -- Nebgen describes the combined arm's own protocol, not
  standalone office EMB, so this is real analogous grounding, not a direct measurement of this
  parameter's target population. Base case is unchanged (no numeric value changed).

## 2026-08-30 (citation-integrity check on emb_failure_lynch, resolved -- no error found)

### Changed
- While researching `office_to_dnc_escalation_fraction`, flagged a possible citation mismatch on the
  already-in-the-base-case `emb_failure_lynch` parameter: Fam Cancer 2009 vol. 8 contains two
  similarly-themed Lynch endometrial-screening papers back-to-back (Elmasry et al., a
  patient-acceptability study, pp. 431-9; Gerritzen et al., an EMB-vs-TVUS study, pp. 391-7), and
  Elmasry's own PubMed abstract makes no mention of the "6/25" failure count attributed to it.
- Checked directly against the NIHR review's own Table 11 (NBK606812/table/table11): confirmed
  verbatim that all four pooled numerators/denominators (Elmasry 6/25, Lecuru 12/116, Rijcken 2/17,
  Woolderink 5/25) match `emb_failure_lynch`'s existing sourcing exactly. No citation error --
  Elmasry's 6/25 is reported in the paper's results, not its abstract. Independently corroborated by
  a German HTA evidence report's own full-text extraction of Elmasry 2009.
- `emb_failure_lynch`'s notes updated to document this verification chain and close the "verify
  against primary studies" open item (verified against the review's authoritative table and a
  third-party independent extraction; all four primary papers remain hard-paywalled with no free full
  text found anywhere, so direct primary-source confirmation is still not possible).
- **No base_value or evidence-tier change** -- this was a provenance-integrity check, not a data
  update. Base case is unchanged.

## 2026-08-29 (CPT 58558 data-quality flag resolved)

### Changed
- Resolved the `hysteroscopy_dc_professional_cost` data-quality flag: the recorded $204.41 and a
  conflicting $1,269.90 citation for CPT 58558 were both superseded by a live CMS Physician & Other
  Practitioners PUF query, split by `Place_Of_Srvc`: facility = $796.75 (383 rows, 6,393 services,
  2024), nonfacility = $1,310.79 (89 rows, 1,752 services, 2024). The $1,269.90 citation turns out to
  be close to the real nonfacility figure, not a professional-plus-facility bundle as originally
  suspected.
- `hysteroscopy_dc_professional_cost` updated to the real facility-setting value **$796.75**
  (matching its own description), low/high set to the real p25/p75 ($221.61 / $1,460.92), distribution
  switched from `fixed` to `gamma`, `provisional` set to `FALSE`, evidence tier upgraded from D to B.
- This parameter is still not wired into any strategy cost function (it is a reference/scenario
  parameter for a not-yet-implemented hysteroscopy-guided D&C comparator), so **the base case is
  unchanged** by this fix. Only the evidence-tier distribution shifted: Tier D 6->5, Tier B 17->18.
- Provisional count down to 5 of 41 parameters (was 6 of 41).

## 2026-08-28 (supply-cost double-count and facility-vs-nonfacility rate correction)

### Changed
- Investigated whether `emb_disposable_supply_cost` ($35 placeholder) was double-counted against
  `emb_office_professional_cost` (CPT 58100's nonfacility professional fee, charged unmodified to
  both office_emb and combined_emb), and whether the combined_emb arm should use a facility-rate
  professional fee instead, since the EMB portion of that arm is performed in the facility/
  endoscopy-suite setting where the colonoscopy itself takes place, not the physician's own office.
- Confirmed via CMS's CY2026 Physician Fee Schedule Final Rule Direct Practice Expense (PE) Inputs
  file (CMS-1832-F, no AMA-license gate): every disposable-supply line item CMS prices into CPT
  58100 -- pelvic exam pack, sterile gloves, needle, syringe, an "endometrial suction curette
  (Pipelle)," uterine sound, tenaculum, lidocaine, povidone swabsticks -- carries `nf_quantity = 1`
  (priced into the nonfacility PE RVU) and `f_quantity = 0` (excluded from the facility-setting PE
  calculation). This confirms `emb_disposable_supply_cost` was double-counted for office_emb (the
  Pipelle itself is already inside `emb_office_professional_cost`) and that the facility setting
  does not price these supplies in at all.
- Confirmed via a live CMS Physician & Other Practitioners PUF query for CPT 58100, split by
  `Place_Of_Srvc`: facility allowed amount = **$60.05** (283 services, 2024) vs. nonfacility =
  **$97.03** (4,431 services, 2024), a real ~38% gap.
- **`emb_disposable_supply_cost` removed from `compute_office_emb_strategy_cost()`** (double-count).
- **New parameter `emb_office_professional_cost_facility` ($60.05)** added and wired into
  `compute_combined_emb_strategy_cost()`'s `incremental_professional_fee` component, replacing
  `emb_office_professional_cost`. `emb_disposable_supply_cost` remains in the combined arm (genuine
  incremental cost there, since the facility-rate fee does not price supplies in) and its value was
  replaced with the real CMS-itemized sum, **$28.79** (was the $35 placeholder).
- `emb_office_professional_cost` itself switched from a 2026 fee-schedule-aggregator source to the
  live 2024 PUF nonfacility figure ($97.03, was $98.20), for methodological consistency with the new
  facility-rate parameter (both now come from the identical query/methodology).
- Two new regression tests added to `test-strategy-costs.R` (office_emb never includes a supplies
  component; combined_emb uses the facility rate, never the nonfacility rate); both mutation-tested
  (planted each defect back in, confirmed the relevant tests in `test-strategy-costs.R` and
  `test-independent-confirmation.R` fail, reverted, confirmed all pass again).
- `test-independent-confirmation.R`'s hand-derived arithmetic updated to match (removed the supply
  term from the office formula, switched the combined formula to the facility-rate parameter).
- Base case updated: combined EMB **$486.01** (was $530.37), office EMB **$780.23** (was $816.40),
  D&C unchanged at $3,827.04. Combined EMB is **37.7%** cheaper than office EMB (was 35.0%); minutes
  threshold **~13.8** (was ~13.6); PSA cost-saving frequency **92.3%** (was 90.2%). Provisional count
  dropped to 6 of 41 parameters (was 7 of 40) -- `emb_disposable_supply_cost` is no longer a
  placeholder.

## 2026-08-28 (D&C arm fully empirical; real E/M costs; recovery-room double-count removed)

### Changed
- `dnc_preop_clinic_visit_cost` replaced with a real, sourced value: CMS PUF 2024, CPT 99214
  (established patient, moderate complexity), filtered to `Rndrng_Prvdr_Type = 'Obstetrics &
  Gynecology'` specifically (7,642 real provider-service rows, 515,741 observed services),
  **$125.40** (service-weighted mean; low/high are the real p25/p75). Before pricing this, checked
  whether it might already be bundled: CMS's 90-day global-surgery period bundles the preoperative
  day into a major procedure's own payment, which would make a separate line item a double-count.
  Verified directly against the live CMS PFS Relative Value File (RVU26C, no AMA license gate) that
  CPT 58120's `GLOB DAYS` field is **010**, not 090 -- a minor-procedure period where the 1-day-before
  bundling rule does not apply, so this cost is genuinely separate.
- `office_visit_em_cost` replaced with a real, sourced value: CMS PUF 2024, CPT 99213, same OB/GYN
  filter (12,739 rows, 686,012 observed services), **$88.76**, replacing the earlier unverified $110
  national-all-specialty guess.
- `dnc_recovery_room_cost` **removed** from `compute_dnc_strategy_cost()` entirely (not priced --
  excluded). Per MedPAC's Ambulatory Surgical Center Services Payment System documentation: "Medicare
  pays for facility services provided in ASCs -- such as nursing, recovery care, anesthetics, drugs,
  and other supplies -- using a payment system that is primarily linked to [OPPS]... Within each APC,
  CMS packages most ancillary items and services with the primary service." Recovery-room/PACU time
  was already inside `dnc_facility_or_asc_fee`; summing it separately was a genuine double-count that
  had been inflating the D&C arm (and therefore inflating the combined-vs-office savings estimate) by
  ~$250 per patient. `dnc_recovery_room_cost` is kept in the parameter table only as a documented,
  explicitly-excluded reference value, matching the `colonoscopy_anesthesia_episode_cost` pattern.
- New regression test (`test-strategy-costs.R`) enforces the exclusion; mutation-tested (planted the
  double-count back in, confirmed both this test and `test-independent-confirmation.R` fail, reverted,
  confirmed both pass again).
- `test-independent-confirmation.R`'s hand-derived arithmetic updated to match the corrected D&C
  structure (it had gone stale relative to the pipeline after the recovery-room removal, which is
  exactly the kind of divergence that test exists to catch).
- **Milestone:** every component feeding the "D&C dominated even at $0 facility fee" finding
  (`dc_professional_cost`, `emb_pathology_cost`, `dnc_preop_clinic_visit_cost`,
  `dnc_anesthesia_cost`) is now a real, CMS-sourced value -- this finding no longer rests on any
  provisional placeholder.
- Base case updated: combined EMB $530.37 (was $540.26), office EMB $816.40 (was $875.26), D&C
  $3,827.04 (was $4,101.64). Combined EMB is 35.0% cheaper than office EMB (was 38.3%); minutes
  threshold ~13.6 (was ~15.0, still comfortably above Huang et al.'s entire 1-12 minute range); PSA
  cost-saving frequency 90.2% (was 93.9%). This is the first fix this session to *narrow* rather than
  widen the combined arm's advantage -- expected, since it corrected a double-count that had been
  inflating D&C's cost, not filled a gap that happened to favor one arm.

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
