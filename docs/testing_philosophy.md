# Testing philosophy

Two rules adopted 2026-08-28, in response to project feedback. Both exist because a
test suite that has never been proven to fail is not evidence of correctness, and a
finding that could change the paper's conclusion deserves more scrutiny than a finding
that doesn't.

## Rule 1: every blocking scientific test must be proven to fail on a planted defect and pass when reverted

A "blocking" test here means any test in `tests/testthat/` that gates CI on `main`
and protects a scientific/correctness claim (as opposed to, say, a pure input-format
check). Passing without ever having been made to fail is not proof a test works --
it could be vacuously true, checking the wrong thing, or silently not exercising the
code path it claims to.

**Process:** when a blocking test is added or materially changed, temporarily plant
a realistic defect in the code it protects, confirm the test goes red, revert the
defect, confirm the test goes green again, and record the result. This is not
automated mutation-testing tooling (no `mutant`/`mutmut`-style framework is wired
into CI) -- it's a discipline applied by hand at the point a test is written, and
logged here so it isn't quietly skipped later.

### Log

| Test | Defect planted | Result |
| --- | --- | --- |
| `validate_cms_filter_field errors when the CMS API silently returns an unfiltered dataset` (`test-evidence-extras.R`) | Disabled the guard (early `return(TRUE)` before the check) | RED with defect (`Expected ... to throw a error` -- failed to throw) -> GREEN on revert |
| `combined EMB arm never includes the colonoscopy baseline anesthesia cost` (`test-strategy-costs.R`) | Added `colonoscopy_anesthesia_episode_cost` into the combined arm's `incremental_anesthesia_drug` component | RED with defect (`Expected ... to be FALSE`, got `TRUE`) -> GREEN on revert |
| `no adjacent pair of index years implies an implausible multi-year inflation multiplier` (`test-inflation.R`) | Reintroduced the original disconnected-scale 2014 CPI value (`100`) | RED with defect, reproducing the exact original bug signature (`ratio = 5.938 over 12 years`), with a **cascading failure** into `test-threshold.R`'s coordination-cost threshold (a live demonstration of how a single bad input can change a downstream conclusion) -> GREEN on revert |
| `raising dnc_facility_or_asc_fee increases all three strategies' costs (via the rescue branch)` (`test-model-identity.R`) | Severed the D&C-cost escalation pass-through in the combined arm (`escalation_cost <- 0`) | RED with defect -> GREEN on revert |
| `INDEPENDENT CONFIRMATION: D&C is dominated...` (`test-independent-confirmation.R`) | Inflated `dnc_recovery_room_cost` by 50% inside the pipeline only (not in the test's independent arithmetic) | RED with defect (all three cross-check assertions failed by the exact planted amount) -> GREEN on revert |
| `MONOTONICITY: lowering office_to_dnc_escalation_fraction increases...` and `INDEPENDENT CONFIRMATION: office EMB's delayed-neoplasia-per-1000...` (`test-diagnostic-yield.R`) | In `compute_strategy_clinical_outcomes()`, changed `office_unresolved_probability <- office_failure_probability * (1 - office_escalation_fraction)` to `office_failure_probability * office_escalation_fraction` (dropped the complement) | RED with defect on both tests (monotonicity: `full_delayed` no longer 0, `partial_delayed > full_delayed` false; independent confirmation: pipeline value diverged from the independently re-derived value by the exact planted-swap amount) -> GREEN on revert |
| `validate_model_parameters rejects a beta distribution with base_value exactly 0 or 1` (`test-validation.R`) | Disabled the boundary-beta guard (`if (FALSE && nrow(boundary_beta_rows) > 0)`) | RED with defect (`Expected ... to throw a error` -- failed to throw) -> GREEN on revert |
| `build_psa_summary_table joins cheapest-strategy probabilities without NAs` and `...reports 0 (not NA) for a strategy that was never cheapest` (`test-tables.R`) | Removed the `strategy = sub("_cost$", "", strategy)` mutate AND the trailing `coalesce(..., 0)` mutate simultaneously | RED with defect on both tests (join produced all-NA `n_draws_cheapest`/`pct_draws_cheapest`; the never-cheapest-strategy row disappeared entirely rather than reporting 0) -> GREEN on revert |
| `geographic inputs cannot adjust the same parameter twice` (`test-geographic-sensitivity.R`) | Disabled the duplicate-adjustment guard (`duplicated_adjustments <- character(0)`) | RED with defect (`Expected ... to throw a error` -- failed to throw) -> GREEN on revert |
| `facility wage index adjusts only the labor share`, `national facility wage index preserves national payment`, and `run_geographic_sensitivity ... reproduces the base case at the national row` (`test-geographic-sensitivity.R`) | In `compute_facility_geographic_multiplier()`, changed `labor_share * wage_index + (1 - labor_share)` to `labor_share * wage_index + labor_share` (dropped the complement) | RED with defect on all three tests (multiplier off by `2 * labor_share - 1` in each case; the national-row identity check diverged from the real base case by $12-$661 per strategy) -> GREEN on revert |
| `sample_triangular falls back to the mode instead of dividing by zero when min == max` (`test-parameters.R`) | Removed the `if (isTRUE(min_value == max_value)) return(mode_value)` early return | RED with defect (`sample_triangular(5, 5, 5)` threw `"missing value where TRUE/FALSE needed"` -- `(mode-min)/(max-min)` evaluated to `0/0 = NaN`, and `if (uniform_draw < NaN)` errors rather than returning a number) -> GREEN on revert |
| `D&C arm includes a partial adverse-event cost matching the sourced perforation-management formula` (`test-strategy-costs.R`) and `INDEPENDENT CONFIRMATION: D&C is dominated...` (`test-independent-confirmation.R`) | Hardcoded `adverse_event_cost_partial <- 0` in `compute_dnc_strategy_cost()`, bypassing the sourced formula | RED with defect on both (unit test: `ae_amount` 0 vs expected $12.77, `ae_amount > 0` false; independent confirmation: all three strategies' costs diverged from the pipeline by the exact $12.77/$1.70/$0.23 cascade -- D&C's own AE cost plus its pass-through into the office and combined arms' escalation-cost terms) -> GREEN on revert |
| `office EMB expected cost equals initial cost plus repeat-visit cost plus escalation cost` (`test-strategy-costs.R`) and `INDEPENDENT CONFIRMATION: office EMB's...` (`test-independent-confirmation.R`) | Hardcoded `repeat_attempt_probability <- 0; repeat_visit_cost <- 0` in `compute_office_emb_strategy_cost()`, bypassing the repeat-attempt formula | RED with defect on both (unit test: `repeat_attempt_probability`/`repeat_visit_cost` 0 vs expected 0.00665/$1.70; independent confirmation: `independent_office_cost` diverged from the pipeline by $1.70) -> GREEN on revert |
| `office EMB's delayed-neoplasia risk is 0 regardless of repeat-attempt parameter values`, `compute_strategy_clinical_outcomes has no unresolved-failure/delayed-neoplasia risk for any strategy`, and `MONOTONICITY: a higher office_repeat_attempt_success_probability decreases...` (`test-diagnostic-yield.R`) | Changed `office_unresolved_probability <- 0` to `office_failure_probability * 0.3` in `compute_strategy_clinical_outcomes()`, reintroducing the pre-2026-09-02 nonzero-unresolved mechanism | RED with defect on all four assertions checked (`unresolved_sampling_probability`/`neoplasia_delayed_probability` nonzero where 0 expected, both at base parameters and at the extreme override values) -> GREEN on revert |
| `adjust_for_inflation errors rather than dividing by a zero or negative index_value` (`test-inflation.R`) | Removed both new `source_index`/`reference_index` finiteness/positivity guards | RED with defect on both assertions (`Expected ... to throw a error` -- a `0` or `-1` `index_value` silently produced `Inf`/`-Inf` costs instead of erroring) -> GREEN on revert |
| `compare_combined_vs_office returns NA percent difference ... when office_cost is 0` and `build_pairwise_comparison_table returns NA percent difference ... when cost_b is 0` (`test-comparison.R`) | Removed the `office_cost == 0`/`cost_b == 0` guards from both functions, matching the guard already present in the sibling `compare_strategies_to_cheapest()` | RED with defect on both tests (`Expected is.na(...) to be TRUE`, got `FALSE` -- `50/0 = Inf`, and `is.na(Inf)` is `FALSE`). First attempt at the `compare_combined_vs_office` test used a `0/0` case, which is `NaN`; since `is.na(NaN)` is `TRUE` in R, that version of the test passed even with the guard removed and had to be rewritten with a nonzero numerator (`combined_cost = 50, office_cost = 0`) to actually distinguish "guarded" from "unguarded" -> GREEN on revert with the corrected test |

| `compute_strategy_expected_encounters returns one row per strategy with dnc fixed at 2` and four other tests in `test-societal-costs.R` (`INDEPENDENT CONFIRMATION`, the `compute_strategy_costs()` consistency guard, `dnc's societal_addon equals exactly 2x...`) | Changed `dnc_encounters <- 2` to `dnc_encounters <- 1` in `compute_strategy_expected_encounters()` (`R/societal_costs.R`) | RED with defect on 5 tests simultaneously (dnc's own encounter count, both office/combined formulas that multiply the escalation branch by `dnc_encounters`, the `compute_strategy_costs()` consistency check, and the `dnc_row$societal_addon == ... * 2` identity) -> GREEN on revert |

Each row above was executed for real during this session, not simulated -- see the
conversation history / commit that introduced this file for the exact defect-planting
commands.

## Rule 2: an audit result capable of changing the study frame requires independent confirmation

Some findings are just arithmetic bookkeeping. Others change what the paper can
claim -- e.g. "combined EMB is cheaper than office EMB" or "D&C is dominated by both
alternatives even before any facility fee is applied" (see `docs/methods_notes.md`).
A finding like that passing the same test suite that produced it is not independent
evidence; the pipeline and its own tests can share a bug.

**Process:** for a finding capable of changing the study's frame, re-derive it via a
path that does not call the functions that originally produced it -- different code,
ideally different reasoning, checked against the same raw parameter values. If both
paths agree, the finding is confirmed, not just internally consistent.

**Applied:** `tests/testthat/test-independent-confirmation.R` re-derives the
"D&C is dominated by both alternatives even at $0 facility fee" finding using
arithmetic written directly in the test file -- summing raw parameter values and
doing the inflation adjustment by hand -- and never calls
`compute_dnc_strategy_cost()`, `compute_office_emb_strategy_cost()`,
`compute_combined_emb_strategy_cost()`, or `metric_dnc_dominated()`. It passed on
first run (independently reproducing the $618.61 gap between the D&C cost and the
more expensive alternative at zero facility fee) and was itself mutation-tested (see
the log above): a pipeline-only defect that the shared test suite would have missed
if the independent path used the same code was caught.

This does **not** mean the finding is true in the world -- it means the finding is a
correct consequence of the current parameter values, several of which are still
provisional (see `docs/data_sources.md`). Independent confirmation checks the math,
not the inputs.

**Also applied, at the manuscript level:** the manuscript's PSA-derived clinical-outcome
claims (combined EMB cheaper in 81.4% of draws, 0.36-vs-2.15-per-1,000 adverse-event
exposure, 100% no-worse-delayed-neoplasia-risk) were re-derived by
`analysis/12_independent_psa_verification.R`, which reads only the saved
`tables/probabilistic_sensitivity_draws.csv` and never sources `R/00_source_all.R` or
calls `compute_strategy_clinical_outcomes()`/`run_probabilistic_sensitivity()`. Every
number it produces matched the manuscript's Results/Discussion text exactly on the
2026-09-01 re-run made after `compute_dnc_strategy_cost()` was wired to include a
partial adverse-event cost (see `docs/ae_cost_evidence_table.md` and CHANGELOG.md),
which changed the D&C cost every PSA draw is built from and therefore shifted every
PSA-derived number again -- this is the second time in the same day this exact
re-sync discipline was exercised for real (first for the PSA seed change, then for
this cost-model change), previously this check had been done ad
hoc and not preserved as a repository artifact.

**When to apply this rule going forward:** any new finding that would appear in a
manuscript's abstract or headline results -- a threshold value, a dominance claim, a
"strategy X is cheapest" statement -- before it's treated as established, not just
"the code that computed it passed its own tests."
