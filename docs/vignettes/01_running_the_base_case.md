# Vignette 1: Running the base-case model end to end

This walks through what actually happens, in order, when you run this model from a clean
checkout -- not a tutorial on decision-analytic modeling in general, but a narrated tour
of this specific repository's real scripts and real output files.

## 1. Install dependencies and run the tests first

```sh
cd emb_colonoscopy
install.packages(c(
  "readr", "dplyr", "tibble", "tidyr", "purrr", "ggplot2", "scales",
  "forcats", "rlang", "testthat",
  "duckplyr", "httr2", "readxl", "stringr", "openssl"
))
Rscript tests/testthat.R
```

If this doesn't print all-green across the 18 test files (colonoscopy-setting, comparison,
cost-effectiveness, diagnostic-yield, evidence-extras, geographic-sensitivity,
independent-confirmation, inflation, model-identity, opportunity-cost-colonoscopy,
parameters, payer-multipliers, public-inputs, societal-costs, strategy-costs, tables,
threshold, validation), stop and fix that before trusting anything downstream -- every
other script in this repository assumes these tests pass.

## 2. The single source of truth: `config/model_parameters.csv`

Nothing in `analysis/` or `R/` hardcodes a dollar figure or a probability. Every single
model input -- CPT-coded professional fees, failure probabilities, anesthesia costs,
pathology costs -- lives in one CSV, one row per parameter, with columns for the base
value, low/high bounds, probability distribution, dollar year, source citation, a
free-text notes field (often a paragraph of verification history), and an `evidence_tier`
(`A` = Lynch-specific direct data, `B` = contemporary U.S. public cost/reimbursement data,
`C` = general/adjacent-population literature, `D` = provisional placeholder with no source
yet, `structural` = an analysis convention rather than an evidence claim). See
`docs/clinical_coding_reference.md` for exactly which CPT/HCPCS codes back the cost
parameters, and `docs/manuscript_methods_results.md` for the full tier breakdown (10 tier
A, 32 tier B, 27 tier C, 6 tier D, 2 structural, out of 77 parameters).

`R/parameters.R` reads and type-checks this file; `R/validation.R` enforces structural
invariants (no missing required columns, no out-of-range probabilities, low <= base <=
high, etc.) before any cost function is allowed to run.

## 3. The three strategies

`R/strategy_costs.R` implements `compute_office_emb_strategy_cost()`,
`compute_combined_emb_strategy_cost()`, and `compute_dnc_strategy_cost()` -- one function
per arm of the decision tree in `docs/clinical_coding_reference.md` Section 3.1. Each
function pulls its own subset of parameters, applies the failure/escalation branches where
they exist (office EMB and combined EMB can both escalate to D&C on an inadequate sample),
and returns a cost breakdown, not just a total -- so you can see exactly which line item
(professional fee, pathology, anesthesia, facility fee, partial adverse-event cost) drove
the number.

## 4. Base case, sensitivity, and the scripts that build the manuscript's figures

```sh
Rscript analysis/01_base_case.R                  # base-case comparison + budget impact + Figure 1
Rscript analysis/02_deterministic_sensitivity.R  # one-way sensitivity + tornado (Figure 2)
Rscript analysis/03_probabilistic_sensitivity.R  # Monte Carlo PSA + probability-cheapest (Figure 4)
Rscript analysis/04_threshold_analysis.R         # threshold analyses + sweep plots (Figure 3)
Rscript analysis/05_scenario_analysis.R          # Medicaid/commercial/historical scenarios (Figure 5)
Rscript analysis/09_geographic_sensitivity.R     # 4-locality Medicare GPCI/wage-index re-pricing (Figure 6)
Rscript analysis/10_decision_tree_figure.R       # decision-tree model diagram (Figure 7)
```

Every script logs its inputs, transformations, and output paths via `base::message()` as
it runs -- read that console output, don't just trust that a `.jpeg` appeared in `figures/`.

The headline result as of the current base case: combined EMB (biopsy performed during the
already-scheduled colonoscopy) is the least expensive strategy, and remained so in all 4 of
4 geographic localities tested and in 91.4% of 1,000 Monte Carlo draws. See
`README.md`'s "What the base case currently shows" section for the exact current numbers --
this vignette intentionally doesn't repeat them, since they're the one thing in this repo
most likely to change as parameters get refreshed, and a stale copy here would be worse
than no copy.

## 5. Building the manuscript and the slide deck from the same outputs

```sh
Rscript analysis/07_manuscript_outputs.R         # consolidated Tables 1-9
Rscript analysis/18_manuscript_slides.R          # builds manuscript/manuscript_slides.pptx
quarto render manuscript/manuscript.qmd          # renders the Quarto manuscript
```

Nothing in `manuscript/manuscript.qmd` or `manuscript_slides.pptx` is hand-typed from the
model's numbers -- both are generated from (or directly cite) the same tables and figures
the `analysis/` scripts just produced. If you change a parameter in
`config/model_parameters.csv`, the correct order of operations is: re-run the relevant
`analysis/` script(s), re-render the manuscript, then re-run
`analysis/18_manuscript_slides.R` -- not edit the manuscript text or slides directly.

## Where to go next

- `docs/vignettes/02_adding_a_new_hospital_payer_rate.md` -- how the real-hospital MRF
  payer-rate datasets in `data/` were built, if you want to extend that sample
- `docs/vignettes/03_interpreting_evidence_tiers_and_sensitivity.md` -- how to read the
  evidence-tier system and the three different sensitivity analyses together
