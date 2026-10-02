# Vignette 3: Interpreting evidence tiers and the three sensitivity analyses together

A reader of this model's output can ask two different questions that are easy to conflate:
"how sure is a *given parameter's value*?" and "how much does the model's *conclusion*
depend on that value?" This repository answers the first with the evidence-tier system and
the second with three distinct sensitivity analyses. Neither one substitutes for the
other.

## 1. Evidence tiers answer "how sure is this input?"

Every row in `config/model_parameters.csv` has an `evidence_tier`:

| Tier | Meaning | Example from this model |
|---|---|---|
| **A** | Directly observed data specific to Lynch syndrome surveillance populations | `emb_failure_lynch` (13.3%, pooled from three primary studies verified full-text, see `docs/clinical_coding_reference.md` Section 3.3) |
| **B** | Contemporary U.S. public cost/reimbursement data (CMS, real CPI anchors) | `emb_office_professional_cost` (CPT 58100, live CMS PUF query) |
| **C** | General or adjacent-population literature (not Lynch-specific) | `dnc_perforation_probability` (a general surgical-gynecology nonobstetric D&C cohort, not Lynch-specific) |
| **D** | Provisional placeholder with no source yet | the office-arm escalation-to-D&C fraction, currently fixed at 100% pending real data |
| **structural** | An analysis convention, not an evidence claim | `reference_dollar_year` |

As of the last full count (`docs/manuscript_methods_results.md`), 77 parameters split 10
tier A (13.0%), 32 tier B (41.6%), 27 tier C (35.1%), 6 tier D (7.8%), 2 structural (2.6%).
`summarize_evidence_tiers()` in `R/evidence_synthesis.R` recomputes this from the live CSV
-- re-run it rather than trusting this vignette's numbers once the parameter table changes.

A tier is not a verdict on whether a number is "good enough to use" -- it's a label on
*where the number came from*, so a reader can decide for themselves how much weight to put
on it, and so a future contributor knows which parameters most need a better source if one
becomes available. A tier-C parameter used instead of a tier-A one is always a deliberate,
documented tradeoff in this repository (see `docs/data_sources.md`'s "Corroborating
(non-Lynch) context" sections for examples of tier-C evidence used only as corroboration,
never to override a tier-A pooled estimate).

## 2. Three sensitivity analyses, each answering a different question

**Deterministic one-way sensitivity** (`analysis/02_deterministic_sensitivity.R`, Figure
2's tornado plot) answers: *if I move one parameter at a time between its low and high
bound, holding everything else at base value, how much does the result move?* This is the
right tool for identifying which individual parameters matter most -- the longest bars in
the tornado -- but it can't tell you about compounding effects between parameters.

**Probabilistic sensitivity analysis / PSA** (`analysis/03_probabilistic_sensitivity.R`,
Figure 4, 1,000 Monte Carlo draws) answers: *if every uncertain parameter varies
simultaneously according to its own probability distribution, how often does each
strategy come out cheapest, and what does the full distribution of the incremental cost
look like?* This is the right tool for a probabilistic claim like "combined EMB was the
least expensive strategy in 91.4% of draws" -- a one-way sensitivity analysis cannot
support a claim phrased that way, because it never varies more than one parameter at a
time.

**Geographic sensitivity** (`analysis/09_geographic_sensitivity.R`, Figure 6, 4 Medicare
payment localities: national, Colorado, a low-cost locality, a high-cost locality) answers
a third, different question: *is the base-case conclusion an artifact of using
national-average pricing, or does it hold under real local Medicare payment rates?* This
one is deliberately deterministic, not folded into the PSA -- see `docs/methods_notes.md`
for why combining geographic and probabilistic variation in one analysis would conflate
two conceptually different sources of uncertainty (parameter uncertainty vs. location).

## 3. Reading them together, not in isolation

A parameter can be tier A (well-sourced) and still show up with a wide low/high range if
the underlying studies disagreed -- `emb_failure_lynch`'s bounds (10.3%-20.0%) span the
three retained studies' individual rates, not an arbitrarily chosen margin. A parameter
can be tier D (no real source yet) and still have almost no effect on the tornado plot, in
which case its lack of sourcing is a documentation gap worth fixing eventually but not an
urgent threat to the conclusion. The combination that should draw real scrutiny is a tier
C/D parameter that *also* produces a long bar in the deterministic tornado -- that is where
getting better data would actually change what the model says, and is exactly the kind of
parameter worth prioritizing for a future tier-A replacement.

## 4. Where this gets reconciled in the manuscript

`manuscript/manuscript.qmd`'s Methods and Results sections, and
`docs/manuscript_methods_results.md`, are where the tier breakdown and all three
sensitivity results are reported together as a single coherent evidence picture --
`docs/CHEERS_2022_checklist.md` item 22 is the specific reporting-standard requirement
this satisfies. If you're drafting new text that cites a parameter's precision, cite its
tier in the same sentence; this repository's own convention (and the thing Reviewer #2
would ask about first) is never to state a number without saying how sure it is.
