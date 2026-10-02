# samevisit's generic API: plugging in a different same-visit comparison

This repository's R/ (the `samevisit` package) was built for one specific comparison
(standalone office endometrial biopsy vs. operative D&C vs. biopsy combined with an
already-scheduled colonoscopy). This page documents the generic entry points that let a
*different* same-visit-vs.-separate-visit project reuse the same cost-engine,
sensitivity-analysis, and comparison machinery without copying files, the way
`mufflyt/iud_bariatric` (standalone vs. bariatric-surgery-combined LNG-IUD insertion)
currently does -- it independently reimplemented near-duplicate files (`strategy_costs.R`,
`comparison.R`, `sensitivity_deterministic.R`, `sensitivity_probabilistic.R`) because this
generic layer didn't exist yet when it was built. Confirmed directly against its code:
`compare_combined_vs_standalone()` is structurally identical to this package's
`compare_combined_vs_office()`, just hardcoded to different strategy names.

**Scope note:** this page documents the *generic* layer only. This repository's own
Lynch-specific functions (`compute_strategy_costs()`, `compute_office_emb_strategy_cost()`,
`compare_combined_vs_office()`, `run_probabilistic_sensitivity()`, etc.) are unchanged and
still the right functions to use for anything specific to this model -- they're now thin
wrappers over the generic layer, not replaced by it (see each one's own docs for which
generic function it wraps).

## The strategy-cost function contract

Every piece below operates on a `strategy_costs` tibble (`strategy`, `initial_cost`,
`escalation_probability`, `escalation_cost`, `expected_total_cost`) produced by a
*strategy-cost function* you write, one per strategy, each returning:

```r
list(
  components = tibble::tibble(strategy = "<name>", component = <chr>, amount = <dbl>),
  escalation_probability = <dbl scalar>,  # 0 if this strategy never escalates
  escalation_cost = <dbl scalar>,         # 0 if escalation_probability is 0
  initial_cost = <dbl scalar>,
  expected_total_cost = <dbl scalar>      # initial_cost + escalation_probability * escalation_cost
)
```

`R/strategy_costs.R`'s `compute_dnc_strategy_cost()` is a real, worked example of this
contract if you want to see it applied.

Your function's signature is either `function(model_parameters, price_index_table,
reference_year)` (a strategy with no escalation target), or
`function(model_parameters, rescue_cost, price_index_table, reference_year)` (a strategy
that may escalate to a shared "rescue" strategy -- see below).

## `compute_multi_strategy_costs()`: the generic cost engine

```r
compute_multi_strategy_costs(
  strategy_fns = list(standalone = compute_standalone_cost, combined = compute_combined_cost),
  model_parameters = model_parameters,
  price_index_table = price_index_table,
  reference_year = 2026,
  rescue_strategy = NULL  # or e.g. "dnc" if one strategy is a shared escalation target
)
```

Pass a **named list** of strategy-cost functions instead of this repository's hardcoded 3.
If your strategies are independent (no shared third arm the others may escalate to, the
shape `iud_bariatric`'s 2-arm comparison needs), leave `rescue_strategy = NULL` and every
function is called with just `(model_parameters, price_index_table, reference_year)`. If
one strategy *is* a shared escalation target (this repository's D&C arm, which both the
office and combined arms may escalate to on a failed sample), name it in `rescue_strategy`
-- it's computed first, and its `expected_total_cost` is passed as the second positional
argument to every other strategy function.

`compute_strategy_costs()` (this repository's own entry point) is now exactly:

```r
compute_multi_strategy_costs(
  strategy_fns = list(dnc = compute_dnc_strategy_cost,
                       office_emb = compute_office_emb_strategy_cost,
                       combined_emb = compute_combined_emb_strategy_cost),
  model_parameters = model_parameters, price_index_table = price_index_table,
  reference_year = reference_year, rescue_strategy = "dnc"
)
```

## `compare_two_strategies()`: generic head-to-head comparison

```r
compare_two_strategies(strategy_costs, "combined", "standalone")
# -> strategy_a, strategy_a_cost, strategy_b, strategy_b_cost,
#    incremental_cost, pct_difference, strategy_a_is_cost_saving
```

Works on any two `strategy` values present in a `strategy_costs` tibble -- not just this
repository's `office_emb`/`combined_emb`. `compare_combined_vs_office()` is a thin wrapper
that calls this and renames the output columns to its own established names.

`compare_strategies_to_cheapest()` and `build_pairwise_comparison_table()` (also in
`R/comparison.R`) were already generic before this page existed -- they operate on any
`strategy`/`expected_total_cost` tibble with no hardcoded strategy names at all.

## `run_one_way_sensitivity()` and `find_parameter_threshold()`: now pluggable

Both already accepted a caller-supplied `target_metric_fn`; they now also accept
`strategy_cost_fn` (defaulting to `compute_strategy_costs()`, so existing calls are
unaffected):

```r
run_one_way_sensitivity(
  model_parameters, parameter_names = c("standalone_fee", "combined_fee"),
  price_index_table = price_index_table,
  target_metric_fn = function(sc) compare_two_strategies(sc, "combined", "standalone")$incremental_cost,
  strategy_cost_fn = my_strategy_cost_fn
)
```

`evaluate_metric_at()` -- the shared perturb-and-reread helper both of the above call
internally -- took the same `strategy_cost_fn` addition.

## `run_probabilistic_sensitivity_generic()`: Monte Carlo over any strategy set

This repository's own `run_probabilistic_sensitivity()` hardcodes the three Lynch strategy
names as output columns and is paired to `compute_strategy_clinical_outcomes()`'s
Lynch-specific clinical-outcome columns (`neoplasia_delayed_per_1000`, `major_ae_per_1000`)
-- not reusable as a thin wrapper, and deliberately left untouched. A new, separate
function covers the generic case:

```r
run_probabilistic_sensitivity_generic(
  model_parameters,
  strategy_cost_fn = my_strategy_cost_fn,
  metric_fns = list(
    incremental_cost = function(sc) compare_two_strategies(sc, "combined", "standalone")$incremental_cost
  ),
  price_index_table = price_index_table,
  n_simulations = 1000,
  seed = 20260901
)
# -> one row per draw: draw, incremental_cost
```

Same Monte Carlo draw mechanics as the Lynch-specific version (same `draw_parameter_set()`
sampling, same `.Random.seed` save/restore behavior), but the output shape is entirely
defined by `metric_fns` -- no hardcoded strategy or outcome names.

## What's still missing for a project like `iud_bariatric` to fully adopt this

- `run_threshold_analyses()` and its 4 Lynch-parameter-named convenience wrappers
  (`threshold_combined_added_minutes()`, etc.) are not generalized -- compose your own
  equivalents directly from `find_parameter_threshold()` + `evaluate_metric_at(...,
  strategy_cost_fn = ...)`.
- Nothing here covers a cancer-prevention-style secondary estimate (`iud_bariatric`'s
  `cancer_prevention.R` has no analogue), a more developed opportunity-cost module, or a
  scenario-override convenience layer beyond the already-generic `override_model_parameters()`.
- This has only been smoke-tested against a synthetic toy 2-strategy model (see
  `docs/reuse_mapping.md`'s "Other mufflyt repositories evaluated" section) -- it has not
  yet been tried against `iud_bariatric`'s actual parameter table and real strategy
  functions. Porting that repository onto this API is a real next step, not done here.
