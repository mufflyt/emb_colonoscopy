# Validation notes

`R/literature_replication.R` implements the harness described below in code:
`validate_against_published_model()` runs this repository's cost engine against any
supplied parameter table and reports the percent difference from named target costs,
and `literature_replication_status()` tracks where each candidate published model
currently stands. Run `tests/testthat/test-evidence-extras.R` for the tests that
enforce this honestly (in particular, that Yi et al. 2018 and Havrilesky et al. 2009
are never marked as reproduced).

## Yi et al. 2018: parameters extracted, but its decision tree does not map onto this repository's engine (2026-08-31)

Yi et al. 2018 (Gynecologic Oncology 150:112-118, PubMed 29747864) modeled office Pipelle vs. D&C
from a U.S. Medicare-payer perspective using 2017 reimbursement, explicitly incorporating sampling
failure, and reported total modeled costs of **$1,897.80 (Pipelle) vs. $2,999.11 (D&C)**, a
difference of about $1,101. This paper's own internal parameter table (Table 1) was obtained via
institutional full-text access and is reproduced in full below. Having now seen it, this repository
does **not** attempt a numeric replication, for a different and more fundamental reason than the
prior "parameters not yet extracted" placeholder: **Yi et al.'s decision tree measures something
structurally different from what `compute_strategy_costs()` computes.**

### Yi et al. 2018's full internal parameter set (Table 1, 2017 USD, Medicare payer perspective)

| Parameter | Base value | Range | Source (Yi et al.'s own refs) |
| --- | --- | --- | --- |
| Prevalence of EC in women with PMB | 0.05 | 0.03-0.1 | Bachmann 2003; NHS guidance |
| P(successful sampling, 1st attempted Pipelle) | 0.58 | 0.5-0.77 | Adambekov et al. 2017 (PMID 27912906) |
| P(successful sampling, 2nd attempted Pipelle) | 0.25 | 0.2-0.5 | Adambekov et al. 2017, estimated range |
| P(moving to D&C if 1st attempted Pipelle failed) | 0.95 | 0.94-1 | "Estimated" -- the paper's own footnote states this reflects "expert clinical estimation," not a measured rate |
| Sensitivity of Pipelle | 0.94 | 0.84-0.99 | Dijkhuizen 2000; Clark 2006; Bachmann 2003; Clark 2002 |
| Specificity of Pipelle | 0.99 | 0.98-1 | same four refs |
| P(successful sampling, D&C) | 0.995 | 0.96-1.0 | Hefler et al. 2009 (nonobstetric D&C complication series, n=5,359) |
| Sensitivity of D&C | 0.96 | 0.82-1 | Clark 2006 |
| Specificity of D&C | 0.99 | 0.97-1 | Clark 2006 |
| Life expectancy, EC with timely treatment | 12.6 yr | 7-19 | stage I EC literature |
| Life expectancy, EC with delayed treatment | 11.97 yr | 6.65-18.05 | 5% discount of timely-treatment LE |
| Life expectancy, no EC / no treatment | 33.16 yr | 28.74-37.73 | SSA Actuarial Life Table 2013, age 50 |
| Life expectancy, no EC / unnecessary treatment | 31.5 yr | 27.30-35.84 | 5% discount of no-EC LE |
| Cost: Pipelle procedure | $244.41 | 228.4-361.46 | 2017 Medicare reimbursement (professional + facility) |
| Cost: D&C procedure | $2,310.47 | 2,272.47-2,600.47 | 2017 Medicare reimbursement (professional + facility) |
| Cost: laparoscopic hysterectomy + adnexectomy | $11,496 | 11,045-11,604 | 2017 Medicare reimbursement |

The two procedure-level cost anchors are now recorded in `config/model_parameters.csv` as
`cost_pipelle_yi2018` and `cost_dc_yi2018` (reference-only, not wired into the base case).

### The decision tree itself (their Fig. 1, described in their Methods 2.1-2.2)

Both arms share the same downstream structure once a sample is obtained: test result (+/-, governed
by the arm's own sensitivity/specificity against the 5% EC prevalence) -> true positives get
treatment (Rx = laparoscopic hysterectomy + adnexectomy, $11,496) -> false negatives get delayed
treatment after a revisit and a second same-procedure sample (cost of the initial procedure added
again) -> false positives get unnecessary treatment (full Rx cost, discounted life expectancy) -> true
negatives get nothing further. D&C sampling failure (0.5%) leads straight to the "revisit + repeat
D&C" branch. **Pipelle sampling failure (42%) is where the trees diverge**: 95% of failures move
straight to the D&C branch (reusing the entire D&C subtree); the remaining 5% get a second Pipelle
attempt (25% success rate), and only if that second attempt also fails does the patient move to D&C.
Effectiveness is remaining life expectancy, weighted across every terminal node by its probability.

### Why this cannot be reproduced by `compute_strategy_costs()`

This repository's cost engine has no representation of: diagnostic sensitivity/specificity, disease
prevalence, a "treat if test positive" cost branch, life-expectancy effectiveness, or a
false-negative delayed-treatment pathway. It computes procedure + pathology + facility/anesthesia
costs and a single failure-probability-weighted escalation to a deterministic D&C cost -- a much
narrower scope by design (this is a resource-cost model for a coordination-of-care question, not a
full cost-effectiveness model of EC diagnosis). Feeding Yi et al.'s Table 1 into
`compute_strategy_costs()` unmodified would not produce anything close to $1,897.80 / $2,999.11,
not because a parameter is missing, but because the two models answer different questions with
different math. Reverse-engineering this repository's formula (e.g. adding an ad hoc
prevalence-weighted treatment-cost term solely to force a match) would be fabricating structure to
hit a known target, which is exactly what the project's original instructions prohibit ("Do not
invent probabilities"). **Confirming this structural mismatch, rather than a numeric match, is the
real finding here** -- it is honest information about what this repository's engine does and does not
capture, not a failure to find the right inputs.

### The convergent comparison actually performed instead

What *is* legitimately comparable, apples-to-apples, is the procedure-level cost inputs alone, since
both models ultimately price the same two CPT-coded procedures (58100-equivalent Pipelle; 58120 D&C),
just via different Medicare years and combined vs. split professional/facility conventions:

- **Pipelle**: Yi et al. 2018 (2017 dollars) = $244.41 combined professional+facility. This
  repository's `emb_office_professional_cost` ($97.03, nonfacility professional only, 2024) +
  `emb_pathology_cost` ($70.14) + `emb_disposable_supply_cost` ($28.79) = $195.96 professional-side
  total, not directly comparable since Yi's figure is Medicare's *combined* nonfacility rate (which,
  per the CMS Direct PE Inputs finding documented above, already bundles supplies into the
  professional fee) -- so the closer comparison is `emb_office_professional_cost` alone ($97.03,
  2024) vs. Yi's $244.41 (2017). These are not close, which is plausible: Medicare's Pipelle
  reimbursement fell over 2017-2024 as CPT 58100's relative value units were revised, and Yi's figure
  may reflect a different nonfacility/facility mix than the pure `Place_Of_Srvc=O` CMS PUF query used
  here. This gap is flagged, not resolved -- it would need Yi's own CPT-code-level sourcing (their
  ref [39], a Medicaid.gov page, no longer specific enough to trace) to reconcile further.
- **D&C**: Yi et al. 2018 (2017) = $2,310.47 combined. This repository's `dc_professional_cost`
  ($209.76, 2026) + `dnc_facility_or_asc_fee` ($3,307.24, 2026) = $3,517.00 combined. The ~52% gap is
  directionally expected (7 years of Medicare payment updates, a genuinely major-procedure OPPS
  facility fee vs. Yi's more modest combined figure) but not independently reconciled here either.

Neither comparison is close enough to call "validated," and that is reported honestly rather than
minimized. The main value of this exercise was establishing, with real primary-source data, that
this repository's scope and Yi et al.'s scope are different models answering related-but-distinct
questions -- useful context for anyone citing this repository alongside Yi et al. 2018, not a
confirmation of either model's numbers.

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
inflation multiplier. These are arithmetic/structural sanity checks, not external validation. Yi et al. 2018 turned out not
to be a viable numeric-replication target (see above) -- the University of Florida study (PMC4154435)
is structurally closer to this repository's actual "initial attempt, escalate on failure" shape and
remains the highest-value next step for a genuine external replication.
