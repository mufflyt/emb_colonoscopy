# NEWS

User-facing highlights. For the exhaustive technical log (every file added/changed/
fixed/removed), see [`CHANGELOG.md`](CHANGELOG.md).

## 2026-08-28 (real D&C facility fee)

**The largest placeholder in the model is now real data.** The D&C facility fee --
~75% of that strategy's total cost, and previously an unsourced $1,800 guess -- is
now the actual CMS hospital-outpatient (OPPS) payment for CPT 58120: $3,307.24,
pulled directly from the current CMS payment addenda. The base case updated
accordingly: combined EMB is now $553.45 per patient vs. $914.38 for office EMB and
$4,387.14 for D&C, a 39.5% saving (was 29.5%), remaining the cheapest strategy up to
~15.8 minutes of added colonoscopy-suite time -- comfortably covering the entire
observed 1-12 minute range from the literature, not just brushing its upper edge.

## 2026-08-28 (national colonoscopy-setting analysis)

**A new national feasibility analysis, complementary to the cost model.** Beyond
what EMB-with-colonoscopy costs, `analysis/08_colonoscopy_setting.R` asks a related
question at national scale: what share of U.S. Medicare colonoscopy-coded services
actually happen in facility settings (ASC or hospital outpatient) where a coordinated
sedated biopsy would be structurally possible? Verified against real 2019-2024 CMS
data during integration -- and this was the first externally-generated delivery this
session that needed no bug fixes after full live verification. See
[`docs/evidence_layers.md`](docs/evidence_layers.md).

## 2026-08-28 (public-input acquisition)

**Public inputs can now be acquired reproducibly.** `analysis/00_get_public_inputs.R`
downloads and validates the real 2024 MEPS files and draws a frozen, fixed-seed
120-hospital sample for the commercial-price layer, instead of requiring hand
downloads. Verified against live data during integration -- and along the way, two
more real bugs turned up (another instance of the data-masking bug from the entry
below, and a CMS column-naming mismatch that the author's own test had shared the
same wrong assumption with, so it never caught it). See
[`docs/evidence_layers.md`](docs/evidence_layers.md).

## 2026-08-28

**CI added.** Every push and pull request now runs the full test suite automatically
(`.github/workflows/r-tests.yml`); status badge is on the README.

**Public-data cost benchmarking added.** Beyond the literature-parameterized model,
`analysis/06_evidence_layers.R` can now pull live CMS Medicare physician-fee
benchmarks, hospital commercial price-transparency data, and MEPS patient-burden
data. See [`docs/evidence_layers.md`](docs/evidence_layers.md) -- including three
real bugs caught and fixed during review before any of it was trusted, and two
layers (claims linkage, CMS facility costs) that were deliberately not shipped
because the data or crosswalk needed to do them correctly isn't available yet.

**New reporting: probability of being cheapest, budget impact, evidence tiers.**
The probabilistic sensitivity analysis now reports what fraction of simulations each
strategy was the least expensive strategy, not just a mean cost difference. A new
budget-impact calculator scales per-patient savings to a health system's annual
patient volume. Every model parameter is now labeled with an evidence tier
(A = Lynch-specific direct data ... D = provisional placeholder) so it's clear at a
glance which conclusions rest on strong versus weak inputs.

**External validation, honestly scoped.** `R/literature_replication.R` can check
this model's engine against a published study's own parameters. Right now that's
used to cross-check the Ladabaum et al. 2011 cost anchor; two other candidate
studies (Yi et al. 2018, Havrilesky et al. 2009) are explicitly tracked as pending
because their internal parameters haven't been extracted yet -- this repository will
not fabricate parameters to fake a match against a known headline number.

**Manuscript tables.** `analysis/07_manuscript_outputs.R` generates all nine
manuscript-ready tables (parameters, cost components, strategy comparison, one-way
sensitivity, PSA summary, thresholds, budget impact, evidence tiers, validation
status) in one run.

## 2026-08-28 (initial release)

First working version: a cost-minimization model comparing standalone office
endometrial biopsy, operative D&C, and biopsy coordinated with an already-planned
surveillance colonoscopy for patients with Lynch syndrome. Base case, deterministic
and probabilistic sensitivity analysis, threshold analysis, and scenario analysis are
all runnable end to end (`analysis/01`-`05`), backed by a fully sourced,
literature-cited parameter table (`config/model_parameters.csv`) and a testthat
suite. See the [README](README.md) for the current base-case result and
[`docs/reuse_mapping.md`](docs/reuse_mapping.md) for what was adapted from the prior
`colpocleisis_costeff` model.
