# Evidence layers

In addition to the literature-parameterized decision model in `R/strategy_costs.R`
(driven by `config/model_parameters.csv`), this repository has an "evidence layer" --
code that pulls cost benchmarks directly from public government and survey data rather
than from a hand-curated parameter table. This document covers what exists, what was
tried and dropped, and three real bugs the review process caught before they could
silently corrupt a result.

## What exists

| Layer | File(s) | Data source | Status |
| --- | --- | --- | --- |
| CMS Medicare professional benchmarks | `R/cms_benchmarks.R`, `R/evidence_codes.R` | Public `data.cms.gov` API, "Medicare Physician & Other Practitioners - by Provider and Service" (2024) | Working against live data, no setup required |
| Hospital Price Transparency (commercial) | `R/hpt_prices.R` | Hospital-published CMS-format MRFs, listed in a local manifest | Working; requires a real (non-template) `config/hpt_mrf_manifest.csv` |
| MEPS patient/societal burden | `R/meps_burden.R` | 2024 MEPS office-based visit and Jobs public-use files | Working; requires local MEPS `.xlsx` files (large, downloaded separately, never committed) |

Run all three via `Rscript analysis/06_evidence_layers.R`. Each layer independently
skips itself with an explanatory message if its data isn't available -- the script
never fails outright just because, say, no HPT manifest has been filled in yet.

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

## Three real bugs this review caught (fix it, don't trust it)

None of this code had been executed before it was reviewed here. Running it against
even small synthetic inputs surfaced three genuine correctness bugs:

1. **Data-masking name collision** (originally in the now-removed APCD schema code,
   `sampling_code_vector()` in `R/evidence_codes.R`): `dplyr::filter(.data$concept %in%
   concept)` had the function argument `concept` colliding with a data column also
   named `concept`. dplyr's data-masking resolved the bare `concept` on the right to
   the *column*, not the argument, so every call silently returned every code in the
   codebook regardless of what was asked for. Fixed with `.env$concept` to force
   argument resolution. A regression test (`sampling_code_vector` returns only the
   requested concept's codes) exists in the git history from when the APCD layer was
   present; if that layer is rebuilt, restore an equivalent test.
2. **Reversed inequality-join columns** (also in the removed APCD episode code):
   `dplyr::join_by(rescue_date > service_date, rescue_date <= followup_end)` named
   columns that existed in the *other* table on each side of the comparison, and
   crashed outright rather than silently misjoining. Fixed by swapping to
   `service_date < rescue_date, followup_end >= rescue_date`.
3. **Silent unfiltered response from the CMS API** (`R/cms_benchmarks.R`): as
   described above under "CMS facility/OPPS benchmarks" -- discovered by checking an
   implausible row count, not by an error. `cms_query_hcpcs()` now checks that the
   requested filter field actually exists in the response and raises a loud error if
   not, rather than silently returning an unfiltered dataset that looks like a real
   answer.

The general lesson carried forward: **run every new data-ingestion function against
real (or realistic synthetic) data and sanity-check the row counts and values before
trusting it** -- a function that runs without an R error is not the same as a function
that returns correct data.

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
