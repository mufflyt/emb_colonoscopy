# Validation notes

`R/literature_replication.R` implements the harness described below in code:
`validate_against_published_model()` runs this repository's cost engine against any
supplied parameter table and reports the percent difference from named target costs,
and `literature_replication_status()` tracks where each candidate published model
currently stands. Run `tests/testthat/test-evidence-extras.R` for the tests that
enforce this honestly (in particular, that Yi et al. 2018 and Havrilesky et al. 2009
are never marked as reproduced).

## Why this repository does not reproduce Yi et al. 2018's $1,897.80 / $2,999.11 numerically

Yi et al. 2018 (Gynecologic Oncology, PubMed 29747864) modeled office Pipelle vs. D&C from a U.S.
Medicare-payer perspective using 2017 reimbursement, explicitly incorporating sampling failure, and
reported total modeled costs of **$1,897.80 (Pipelle) vs. $2,999.11 (D&C)**, a difference of about
$1,101.

This is the single best available external validation target for this repository's office-EMB and
D&C arms: if this model's decision-tree structure is sound, plugging in Yi et al.'s 2017 inputs
should approximately reproduce their output. **That has not been done here**, because doing it
correctly requires the paper's actual internal parameters -- test sensitivity/specificity, Pipelle
and D&C failure probabilities, the cost of repeat sampling, and exactly how the paper handles the
pathway after an inadequate specimen -- not just its two headline totals.

Reverse-engineering internal parameters from a target output (i.e. picking failure probabilities and
costs until the model happens to produce $1,897.80 and $2,999.11) would be fabricating data to match
a result, which is exactly what the user's original instructions to this project prohibited ("Do not
invent probabilities" / every provisional value must be labeled as provisional). A fabricated match
would look like validation while providing none.

`config/model_parameters.csv` and `docs/data_sources.md` instead list Yi et al. 2018 as the top
priority item in "next literature to mine." A real replication would extract that paper's Table
2/3-equivalent parameter set into a documented alternate parameter file (e.g.
`config/model_parameters_yi2018_2017dollars.csv`), run this repository's existing
`compute_strategy_costs()` against it unmodified, and report how closely the reproduced totals track
$1,897.80 / $2,999.11. Because the decision-tree engine in `R/strategy_costs.R` already accepts an
arbitrary parameter table, this replication would not require new model code -- only the extracted
parameters and a small `analysis/06_validation_yi2018.R` script.

## A second, structurally similar external validation target

The University of Florida office-vs-OR hysteroscopy analysis (PMC4154435) models an office-first
strategy with OR rescue against an all-OR strategy ($3,448 vs. $4,946, saving $1,498, 95% CI
$1,051-$1,923) -- structurally the same "initial attempt, escalate on failure" shape used throughout
this repository. It is a second, independent replication target once its inputs are extracted,
alongside the Munro et al. 2022 CPT 58558 figures already recorded as reference-only values (see
`docs/data_sources.md`).

## What this repository's tests do instead

Rather than asserting equality to an external number, `tests/testthat/test-model-identity.R` checks
that the model behaves the way its documented economic logic says it should: costs are non-negative,
raising a failure probability increases the arm's expected cost, raising the D&C facility fee
increases all three arms' costs (via the escalation pass-through) but by less in the arms with lower
escalation probability, and the Ladabaum-historical scenario reproduces the documented 1.529x
inflation multiplier. These are arithmetic/structural sanity checks, not external validation --
external validation against Yi et al. 2018 and the University of Florida study remains the
highest-value next step for establishing this model's credibility.
