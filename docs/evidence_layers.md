# Evidence layers

In addition to the literature-parameterized decision model in `R/strategy_costs.R`
(driven by `config/model_parameters.csv`), this repository has an "evidence layer" --
code that pulls cost benchmarks directly from public government and survey data rather
than from a hand-curated parameter table. This document covers what exists, what was
tried and dropped, and several real bugs the review process caught before they could
silently corrupt a result -- every one of them found by actually running the code
against real or realistic data, none of them by reading it.

## What exists

| Layer | File(s) | Data source | Status |
| --- | --- | --- | --- |
| CMS Medicare professional benchmarks | `R/cms_benchmarks.R`, `R/evidence_codes.R` | Public `data.cms.gov` API, "Medicare Physician & Other Practitioners - by Provider and Service" (2024) | Working against live data, no setup required |
| Hospital Price Transparency (commercial) | `R/hpt_prices.R` | Hospital-published CMS-format MRFs, listed in a local manifest | Working; requires a real (non-template) `config/hpt_mrf_manifest.csv`; parser handles both CMS v3 tall and wide CSV layouts |
| MEPS patient/societal burden | `R/meps_burden.R` | 2024 MEPS office-based visit and Jobs public-use files | Working; requires local MEPS `.xlsx` files (large, downloaded separately, never committed) |
| Public-input acquisition | `R/meps_download.R`, `R/hpt_hospital_discovery.R`, `R/public_input_config.R`, `analysis/00_get_public_inputs.R` | Live downloads: 2024 MEPS ZIPs, CMS hospital list, each sampled hospital's CMS-mandated `cms-hpt.txt` | MEPS download/extract/validate and the CMS hospital download + fixed-seed 120-hospital stratified sample are verified working against live data; the per-hospital `cms-hpt.txt` resolution step (potentially 100+ requests to real hospital domains) is verified on one hospital but was deliberately not run in bulk as part of this integration -- see below |

Run the CMS/HPT/MEPS layers via `Rscript analysis/06_evidence_layers.R`. Each layer
independently skips itself with an explanatory message if its data isn't available --
the script never fails outright just because, say, no HPT manifest has been filled in
yet. Run `Rscript analysis/00_get_public_inputs.R` first to acquire the MEPS files and
draw the frozen HPT hospital sample (set `RUN_EVIDENCE_LAYERS=true` to chain straight
into the evidence layers afterward).

**On running the 120-hospital `cms-hpt.txt` resolution step:** `resolve_hpt_manifest()`
in `R/hpt_hospital_discovery.R` makes one (or two, http/https) request per sampled
hospital to that hospital's own domain. This is a materially larger and more
hit-or-miss network footprint than the single-request CMS/MEPS downloads above -- real
coverage of the CMS "automatic discovery" convention (`https://{domain}/cms-hpt.txt`)
is currently inconsistent across hospitals (confirmed live: it worked immediately for
NYU Langone, returning five correctly-parsed hospital locations with contact info and
MRF URLs, but 404'd for a domain guess against Cleveland Clinic). The pipeline handles
this correctly -- an unresolvable hospital gets logged to
`config/hpt_hospital_domains.csv` for manual fill-in rather than silently dropped or
guessed -- but running all 120 for real is a deliberate action worth doing knowingly,
not something to trigger as a side effect of routine setup.

## What was designed, prototyped, and dropped

### APCD claims linkage

An all-payer claims database (APCD) layer was built and tested against synthetic
claims: schema standardization (`standardize_apcd_claims()`), same-day episode
construction (`build_same_day_sampling_episodes()`), and 90-day operative-rescue
linkage. It worked correctly (after the bug fixes below) and would have let the model
estimate `E[cost(colonoscopy+EMB)] - E[cost(colonoscopy alone)]` directly from
observed claims, with Colorado as the primary source and Massachusetts as external
validation.

It was removed from the repository because this project does not have an approved
state APCD data use agreement, and there is no value in carrying claims-ingestion
code that can never be pointed at real data. If a DUA is obtained later, the design
(canonical schema + column-map template + env-var-gated file paths, so no real
extract or its column names are ever committed) is worth reproducing -- follow the
same pattern used for the HPT and MEPS layers below.

### CMS facility/OPPS benchmarks

An attempt was made to add a facility-cost layer analogous to the professional-fee
layer, querying "Medicare Outpatient Hospitals - by Provider and Service" by HCPCS
code. This was abandoned after live testing revealed two things:

1. That dataset is keyed by **APC code** (Ambulatory Payment Classification), not
   HCPCS/CPT code. There is no `HCPCS_Cd` column to filter on.
2. The CMS data-api **silently ignores a filter condition on a field that does not
   exist in the dataset**, rather than erroring. A query filtered on `HCPCS_Cd`
   against the facility dataset returned all 116,182 rows in the dataset, unfiltered
   -- indistinguishable from a real result unless you happen to check the row count
   against what's plausible for a single procedure code.

Getting real facility costs per CPT code from this dataset requires a HCPCS-to-APC
crosswalk (published annually by CMS as OPPS Addendum B) that has not been obtained.
This is documented in `R/evidence_provenance.R::evidence_layer_catalog()` as
`hospital_cost_reports`-adjacent future work rather than shipped half-working.

## Real bugs this review caught (fix it, don't trust it)

None of this code had been executed before it was reviewed here -- both scaffold
deliveries were static-verified only (no R runtime in the environment that produced
them). Actually running each one surfaced genuine correctness bugs the author's own
static checks and, in two cases, the author's own synthetic test fixtures could not
have caught:

1. **Data-masking name collision** (`sampling_code_vector()` in `R/evidence_codes.R`,
   and reintroduced in a later delivery of the same file): `dplyr::filter(.data$concept
   %in% concept)` had the function argument `concept` colliding with a data column also
   named `concept`. dplyr's data-masking resolved the bare `concept` on the right to
   the *column*, not the argument, so every call silently returned every code in the
   codebook regardless of what was asked for. Fixed with `.env$concept` to force
   argument resolution.
2. **Reversed inequality-join columns** (in the removed APCD episode code):
   `dplyr::join_by(rescue_date > service_date, rescue_date <= followup_end)` named
   columns that existed in the *other* table on each side of the comparison, and
   crashed outright rather than silently misjoining. Fixed by swapping to
   `service_date < rescue_date, followup_end >= rescue_date`.
3. **Silent unfiltered response from the CMS API** (`R/cms_benchmarks.R`): as
   described above under "CMS facility/OPPS benchmarks" -- discovered by checking an
   implausible row count, not by an error. `cms_query_hcpcs()` checks that the
   requested filter field actually exists in the response and raises a loud error if
   not, rather than silently returning an unfiltered dataset that looks like a real
   answer. Regression test: `validate_cms_filter_field` in
   `tests/testthat/test-evidence-extras.R`.
4. **The same data-masking collision, in different code** (`hpt_wide_metric_column()`
   in `R/hpt_prices.R`): `dplyr::filter(.data$payer_name == payer_name, .data$plan_name
   == plan_name, .data$metric == metric)` had all three function arguments colliding
   with same-named data columns. The filter became tautologically true for every row,
   so the function always returned the *first* matching column regardless of which
   payer/plan was actually requested -- silently attributing every payer's negotiated
   price to whichever payer's column happened to come first. This one **was** covered
   by the author's own test (`"wide HPT parser pivots payer columns"`), which failed
   on first run once actually executed (`Expected: 140, 110`, `Actual: 140, 140`) --
   the test was correct, it had just never been run. Fixed the same way as #1,
   with `.env$` on all three comparisons.
5. **Real-vs-assumed CMS column name mismatch** (`download_cms_hospital_frame()` in
   `R/hpt_hospital_discovery.R`): the code expected a normalized column named
   `citytown`, but the real CMS Hospital General Information file's `"City/Town"`
   header normalizes (via the same slash-to-underscore rule that correctly handles
   `"Facility ID"` -> `facility_id`) to `city_town`, not `citytown`. This is the one
   case in this list where **the author's own synthetic test fixture shared the exact
   same wrong assumption** (`citytown = "Test City"`, no underscore) as the
   implementation, so the test passed while being wrong about the real world --
   internal consistency between code and test is not the same as correctness. Only
   running `download_cms_hospital_frame()` against a live download (5,419 real
   hospitals) surfaced it. Fixed by renaming at the ingestion boundary
   (`normalize_cms_hospital_frame_names()`, extracted as a pure function precisely so
   this could get an offline regression test:
   `tests/testthat/test-public-inputs.R`).

The general lessons carried forward, now formalized in `docs/testing_philosophy.md`:
**run every new data-ingestion function against real (or realistic synthetic) data and
sanity-check the row counts and values before trusting it** -- a function that runs
without an R error is not the same as a function that returns correct data -- and **a
test sharing the same assumption as the code it tests provides false confidence**; bug
#5 above is a live example of exactly that failure mode.

## Evidence tiers

Every parameter in `config/model_parameters.csv` now carries an `evidence_tier`:

- **A** -- directly observed data specific to Lynch syndrome surveillance populations
  (e.g. `emb_failure_lynch`, `combined_to_dnc_probability`, `combined_emb_added_minutes`)
- **B** -- contemporary U.S. public cost/reimbursement data (CMS fee-schedule figures,
  the real BLS CPI anchors, Munro et al. 2022's hysteroscopy cost figures)
- **C** -- general or adjacent-population literature (non-Lynch failure rates, the
  JAMA Surgery OR-cost-per-minute study, which is not colonoscopy-suite-specific)
- **D** -- provisional assumption or placeholder with no source yet
- **structural** -- an analysis convention, not an evidence claim (e.g.
  `reference_dollar_year`)

`R/evidence_synthesis.R::summarize_evidence_tiers()` counts parameters per tier; see
`tables/manuscript_table8_evidence_tiers.csv` after running
`analysis/07_manuscript_outputs.R`. This is a first-pass count, not a sensitivity
result -- a full leave-one-source-out or value-of-information analysis (which
parameter's uncertainty actually matters for the conclusion) is a documented next
step, not implemented here.

## External validation status

`R/literature_replication.R` provides a generic harness
(`validate_against_published_model()`) for checking whether this repository's cost
engine reproduces a published study's result when fed that study's own parameters.
`literature_replication_status()` documents where each candidate published model
currently stands -- see `docs/validation_notes.md` for the fuller reasoning. In short:
Ladabaum et al. 2011's office-EMB cost anchor is cross-checked (its inflation
adjustment reproduces the expected ~1.529x multiplier), but Yi et al. 2018 and
Havrilesky et al. 2009 remain `pending_parameter_extraction` -- their internal
parameters have not been obtained, and this repository will not fabricate them to
force a match against their headline outputs.
