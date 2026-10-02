# Figures reference: every file in `figures/`, and three different numbering schemes

This repository uses **three independent figure-numbering schemes** that all refer to the
same eight image files, for three different audiences. That is a real source of confusion
if you only look at one of them, so this file exists to make the mapping explicit in one
place rather than something a reader has to reconstruct from three separate documents.

1. **File name number** (`figure1_...` through `figure7_...`) -- the order the figures
   were created in, fixed once a file exists; not meaningful beyond "which script built
   this."
2. **README number** (`Figure 1`-`Figure 4` as captioned inline in `README.md`) -- a
   plain-language walkthrough order, covering only 4 of the 7 files, chosen for
   explaining the model to a general reader.
3. **Manuscript number** (`Figure 1`-`Figure 3` in `manuscript/manuscript.qmd`) -- the
   journal submission's main-text figures only, capped at what the target journal's
   Instructions for Authors allow; the remaining 4 files are proposed as Supplemental
   Digital Content (SDC), which that journal exempts from the main-text figure limit.

## The mapping

| File (`figures/`) | Built by | README number | Manuscript number | Status |
|---|---|---|---|---|
| `figure7_decision_tree.png` | `analysis/10_decision_tree_figure.R` | Figure 2 | **Figure 1** | Main-text manuscript figure. Satisfies CHEERS item 15 (a figure summarizing the model). Built directly from live model output, not hand-drawn. |
| `figure4_psa_incremental_cost.jpeg` | `analysis/03_probabilistic_sensitivity.R` | Figure 3 | **Figure 2** | Main-text manuscript figure. Distribution of the incremental cost of combined EMB vs. office EMB across 1,000 Monte Carlo draws. |
| `figure6_geographic_sensitivity.jpeg` | `analysis/09_geographic_sensitivity.R` | Figure 4 | **Figure 3** | Main-text manuscript figure. Expected cost per strategy at 4 Medicare payment localities. |
| `figure1_strategy_cost_comparison.jpeg` | `analysis/01_base_case.R` | Figure 1 | SDC candidate | Base-case bar chart; largely redundant with manuscript Table 2/Figure 1, kept as SDC for readers who want the simplest possible summary view. |
| `figure2_tornado.jpeg` | `analysis/02_deterministic_sensitivity.R` | *not shown* | SDC candidate | One-way deterministic sensitivity tornado plot. The manuscript's own draft notes flag this as the most likely swap-in for main-text Figure 3 if a reviewer or the author prefers it over the geographic figure. |
| `figure3a_threshold_minutes.jpeg` | `analysis/04_threshold_analysis.R` | *not shown* | SDC candidate | Threshold sweep on the combined-EMB added-time parameter. |
| `figure3b_threshold_office_failure.jpeg` | `analysis/04_threshold_analysis.R` | *not shown* | SDC candidate | Threshold sweep on the office-EMB failure-probability parameter. |
| `figure5_scenario_comparison.jpeg` | `analysis/05_scenario_analysis.R` | *not shown* | SDC candidate | Medicaid/commercial/historical payer-scenario comparison. |
| `figure8_hospital_mrf_map.jpeg` | `analysis/19_hospital_mrf_map.R` | Figure 5 | Not yet proposed | Point map of hospitals with usable price-transparency (MRF) payer-rate data (70 hospitals, 29 states), one jittered point per hospital at its home city's approximate Census Gazetteer coordinates (`data/gyn_onc_hospital_cities.csv`), colored by coverage. Documentation/transparency figure for a standalone sensitivity exercise -- not part of the base-case model, so not currently proposed for the manuscript's own 5-figure/table or SDC lists (see `manuscript/supplemental_hospital_mrf_sample.qmd` for that data's own manuscript-formatted table instead). |

The four figure2/figure3a/figure3b/figure5 files are not missing or broken -- they were deliberately left out
of the README's 4-figure walkthrough (which is curated for a general reader, not
exhaustive) and out of the manuscript's main text (which is capped by journal page/figure
limits). This table is where they're documented instead.

## Regenerating a figure

Every figure is rebuilt by exactly one `analysis/*.R` script (see the "Built by" column
above) from live model output -- none are hand-edited images. If you change a parameter in
`config/model_parameters.csv`, re-run the relevant script(s) rather than editing a figure
file directly; `docs/vignettes/01_running_the_base_case.md` has the full run order.
