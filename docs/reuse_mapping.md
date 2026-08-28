# What was reused from `colpocleisis_costeff`

Before writing any code for `emb_colonoscopy`, the source repository named by the user as
`colpocleisis_sampling` was located and inspected. No repository with that exact name exists
locally or on GitHub; after clarifying with the user, the repository inspected was
**`mufflyt/colpocleisis_costeff`** (public GitHub), a cost-effectiveness decision model comparing
TVUS, office Pipelle biopsy, and concurrent D&C before LeFort colpocleisis. A related, earlier
scaffold repository, `mufflyt/cost_lefort`, was noted in `colpocleisis_costeff/ONBOARDING.md` as
its predecessor but was not itself the primary source.

`colpocleisis_costeff` is three files (`colpocleisis_selective_testing_model.R`,
`generate_figures.R`, `run_example.R`) plus a README and an onboarding document -- not a package,
and not a large codebase. It is considerably smaller than the repository structure requested for
`emb_colonoscopy` (no `tests/`, no `data-raw/`, no `config/`, no PSA). The table below maps every
component the user asked us to look for against what `colpocleisis_costeff` actually had.

| Component the user asked us to look for | Present in `colpocleisis_costeff`? | What `emb_colonoscopy` did |
| --- | --- | --- |
| Cost parameter storage | No -- every parameter was a hard-coded function default (~25 arguments to `run_colpocleisis_selective_testing_model()`) | **New.** Parameters were pulled out into `config/model_parameters.csv`, a single auditable table with base/low/high/unit/source/dollar_year/provisional/notes columns, loaded by `R/parameters.R`. This is a deliberate improvement, not a port. |
| CMS/Medicare reimbursement ingestion | No -- no ingestion mechanism; all costs were literals in the function signature | **New.** No live ingestion is implemented (network fetches don't belong in a static repo); instead every CMS-sourced value in `config/model_parameters.csv` records the CPT code, the fee-schedule year, and the aggregator/source it came from, so it can be independently re-verified against the CMS Physician Fee Schedule Look-Up Tool. |
| Inflation adjustment | No | **New.** `R/inflation.R::adjust_for_inflation()`, driven by `data/cpi_medical_care.csv`. See `docs/data_sources.md` for the real vs. placeholder index values in that table. |
| Cost aggregation | Yes, informally -- costs for each strategy were summed inline inside one long function body (e.g. `cost_pipelle <- (high_risk_count * pipelle_cost) + ...`) | **Adapted.** `R/strategy_costs.R` keeps the "sum named cost pieces into a strategy total" idea but restructures it into small per-strategy functions returning both a component breakdown tibble and a scalar total, and adds a shared escalation-to-D&C branch (see `docs/methods_notes.md`) that `colpocleisis_costeff` did not need for its use case. |
| Deterministic (one-way) sensitivity analysis / tornado plot | Yes -- `generate_figures.R` built a `sensitivity_params` tibble of `(param_name, low_val, high_val, display_label, format_type)` and looped `run_colpocleisis_selective_testing_model()` at each bound, computing a `get_preferred_nmb()` helper, then plotted a segment-based tornado diagram | **Adapted directly.** `R/sensitivity_deterministic.R::run_one_way_sensitivity()` generalizes the same loop-over-bounds pattern to work off `config/model_parameters.csv`'s `low_value`/`high_value` columns and any target metric function, instead of a hard-coded 6-row tibble. `R/plotting.R::plot_tornado()` is a close port of the original `geom_segment` tornado, adapted to the new data shape. |
| Probabilistic sensitivity analysis | No | **New.** `R/sensitivity_probabilistic.R` draws parameter sets from gamma (costs), beta (probabilities), and triangular (the combined-arm added-minutes range) distributions and re-runs the full cost model per draw. Where a source reported an explicit gamma shape/rate (Ladabaum et al. 2011's EMB cost), that parameterization is used directly instead of a moment-matched approximation -- see `gamma_alpha`/`gamma_rate` columns in `config/model_parameters.csv`. |
| Threshold analysis | Partially -- `generate_figures.R`'s Figure 3 swept `high_risk_prevalence` across a grid and plotted net monetary benefit per strategy, but did not solve for a specific crossing point (no root-finding) | **Extended.** `R/threshold_analysis.R` adds `stats::uniroot()`-based root-finding (`find_parameter_threshold()`) on top of the same "sweep a parameter, recompute the model" idea, answering the specific clinical questions the user posed (minutes threshold, failure-probability threshold, D&C-dominance threshold, coordination-cost threshold) rather than only producing a visual sweep. `plot_threshold_sweep()` in `R/plotting.R` keeps the sweep-and-plot style for the figures. |
| Plotting conventions | Yes -- `theme_journal()` (a `ggplot2::theme_minimal()` derivative), `scales::dollar_format()`/`percent_format()` axis labels, `ggplot2::scale_colour_brewer(palette = "Set1")`, `.jpeg` output at 300 dpi | **Ported directly** into `R/plotting.R`, including the exact `theme_journal()` definition. |
| Table generation | Informal -- `readr::write_csv()` of the strategy table and frontier table with a timestamped filename | **Adapted, simplified.** `R/tables.R::save_table()` keeps CSV-first, dependency-light output (no `gt`/`kableExtra`), but uses fixed filenames per analysis (`strategy_comparison.csv`, etc.) rather than timestamps, since `analysis/` scripts are meant to be re-run and diffed, not archived per-run. |
| Assertions / input validation | Yes -- `validate_probability()`, `validate_non_negative()`, `validate_positive()` were defined as closures *inside* the model function | **Ported and improved.** The same three validators (same logic, same error messages) were pulled out into standalone, individually testable functions in `R/utils_validation.R`, plus a new `validate_boolean()` and `validate_model_parameters()` (schema-level validation of the whole parameter table, which `colpocleisis_costeff` had no equivalent of, since it had no external parameter table). |
| Unit testing | No -- no `tests/` directory existed | **New.** `tests/testthat/` (8 files, run via `Rscript tests/testthat.R`) covers validation, parameter loading, inflation adjustment, strategy costing, comparison, threshold-finding, and model-identity/arithmetic sanity checks. |
| Provenance / source documentation | Yes, extensively -- `README.md`'s parameter table (parameter, default, source) and `ONBOARDING.md`'s literature-lineage section (Larose et al. 2020 / Robbins `costeff_lung_biom_public` as the methodological ancestor, Kandadai et al. 2014 as the directly competing prior publication) | **Adapted and expanded.** `config/model_parameters.csv`'s `source`/`dollar_year`/`provisional`/`notes` columns generalize the README table into a machine-readable form; `docs/data_sources.md` in this repository plays the role `ONBOARDING.md` played there, documenting where every number came from and what is still missing. |

## What was deliberately *not* ported

- **The efficiency-frontier / dominance-removal machinery** (`remove_strongly_dominated_strategies()`,
  `remove_extended_dominance()`, sequential ICERs, net monetary benefit) is specific to a
  cost-*utility* analysis with a QALY axis. This repository's base case is a **cost-minimization**
  analysis (see `docs/methods_notes.md` for why), so there is no second axis to build a frontier
  over. If a QALY-based extension is added later (as the repository's structure allows), this is
  the piece of `colpocleisis_costeff` most worth revisiting.
- **The single-giant-function architecture.** `colpocleisis_costeff`'s entire model lived in one
  ~870-line function with 25 arguments. `emb_colonoscopy` follows the user's explicit request to
  separate parameters from functions and keep functions small and testable, so the equivalent
  logic is spread across `R/parameters.R`, `R/strategy_costs.R`, `R/comparison.R`, etc.

## The one-cycle decision-tree structure inherited from `cost_lefort`

`cost_lefort` (the predecessor scaffold named in `colpocleisis_costeff/ONBOARDING.md`) frames its
model as "a one-cycle decision tree rather than a full Markov model," which is the same modeling
choice made here: `emb_colonoscopy` is a short-horizon, one-step decision tree (initial sampling
attempt -> success or escalation to D&C), not a lifetime or annual-cycle model. That framing choice
was reused conceptually even though no code was ported from `cost_lefort` directly.
