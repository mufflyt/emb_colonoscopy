# Onboarding guide: a walkthrough for a new resident

This is the "someone just handed me this repository, where do I even start" document. It
assumes you're clinically trained (you know what Lynch syndrome, an endometrial biopsy,
and a D&C are) but have little or no background in R, decision-analytic modeling, or
health economics -- and it's written to get you from zero to being able to explain this
study's logic and reproduce its headline result yourself, in roughly an hour of actual
work. Every other `docs/` file goes deeper than this one on some specific piece; this one
exists to tell you *which* file to go to, and *when*.

## 1. What this study actually asks (two minutes)

Read `README.md`'s "The clinical problem, in plain language" and "What 'cost-minimization'
means, in plain language" sections first (the first two sections after the title) -- don't
re-derive this yourself, it's already written for exactly this purpose. In one sentence:
patients with Lynch syndrome need both colonoscopy and periodic endometrial sampling, and
this model asks whether doing the biopsy *during* the already-scheduled colonoscopy costs
less than doing it as its own separate visit, or as an operative D&C -- under the
assumption that all three catch cancer equally well, which is what makes this a
*cost-minimization* analysis rather than a cost-effectiveness one (no benefit tradeoff to
weigh, just cost arithmetic).

## 2. Set up and run it yourself (fifteen minutes)

You do not need to understand any R code to do this step -- just run it and watch what
happens.

```sh
cd emb_colonoscopy
install.packages(c(
  "readr", "dplyr", "tibble", "tidyr", "purrr", "ggplot2", "scales",
  "forcats", "rlang", "testthat",
  "duckplyr", "httr2", "readxl", "stringr", "openssl"
))
Rscript tests/testthat.R          # should finish with every one of 18 files all-dots, no red Xs
Rscript analysis/01_base_case.R   # the core comparison -- watch the console messages as it runs
```

Open `tables/summary_sentence.txt` afterward -- it's one auto-generated sentence stating
the headline result, in plain English, built directly from the numbers the script just
produced (not typed by a person). Open `figures/figure1_strategy_cost_comparison.jpeg` next
to it -- same result, as a bar chart. `README.md`'s "What the base case currently shows"
section has the same sentence, kept in sync -- if what you see in your own
`tables/summary_sentence.txt` doesn't match the README, something in your setup is out of
date; ask before trusting either number.

**Do this before reading anything else.** Everything downstream in this guide refers back
to the output you just generated.

## 3. The one file that drives everything (five minutes)

Open `config/model_parameters.csv` (in Excel, or `readr::read_csv("config/model_parameters.csv")`
in R). This is the single source of truth for every number the model uses -- every
professional fee, every failure probability, every anesthesia cost. Nothing in the R code
hardcodes a dollar figure; it all comes from this one table. Each row has:

- a **base value**, plus **low/high bounds** and a probability **distribution** (used by
  the sensitivity analyses in step 5)
- a **source** citation and a long free-text **notes** field (often the most important
  column -- it's where the verification history lives)
- an **evidence_tier**: `A` (data observed directly in Lynch syndrome patients), `B` (real
  U.S. Medicare/CPI data, just not Lynch-specific), `C` (general/adjacent-population
  literature), `D` (a placeholder with no real source yet), or `structural` (a convention,
  not a claim). **This is the single most important column to learn to read** -- it tells
  you how much weight to put on any given number. See
  `docs/vignettes/03_interpreting_evidence_tiers_and_sensitivity.md` for the full
  breakdown and worked examples.

Find the row for `emb_failure_lynch` (the probability an office biopsy comes back
inadequate) and read its `notes` field in full. It's long on purpose -- it's the model's
most heavily re-verified parameter, and reading it once will teach you more about this
repository's standard of evidence than any summary could.

## 4. How a number turns into the headline result (ten minutes)

`R/strategy_costs.R` has three functions -- `compute_office_emb_strategy_cost()`,
`compute_combined_emb_strategy_cost()`, `compute_dnc_strategy_cost()` -- one per strategy.
Open any one and read it top to bottom; you don't need to be an R programmer to follow it,
it's mostly addition and multiplication by probabilities, with a comment or citation next
to anything non-obvious. `docs/clinical_coding_reference.md` Section 3.1 has a diagram of
the same logic as a flowchart if that's easier to follow than code, and Section 1 has a
table of every CPT/HCPCS code involved, mapped to the exact parameter it prices.

## 5. The three ways this model is stress-tested (ten minutes)

A single result isn't trustworthy on its own -- this model checks itself three different
ways, each answering a different question:

1. **One-way sensitivity** (`figures/figure2_tornado.jpeg`): if I wiggle *one* parameter at
   a time between its low and high bound, how much does the result move? Tells you which
   individual inputs matter most.
2. **Probabilistic sensitivity / PSA** (`figures/figure4_psa_incremental_cost.jpeg`): if
   *every* uncertain parameter varies at once (1,000 simulated draws), how often does each
   strategy actually come out cheapest? This is where a claim like "combined EMB won in
   91% of draws" comes from.
3. **Geographic sensitivity** (`figures/figure6_geographic_sensitivity.jpeg`): does the
   conclusion hold at real local Medicare payment rates, or only under a national average?

Full explanation, with the reasoning for why these are kept separate rather than combined:
`docs/vignettes/03_interpreting_evidence_tiers_and_sensitivity.md`.

## 6. Questions you'll probably be asked, and where to find the answer

| If someone asks you... | Go to... |
|---|---|
| "What does this actually cost and why?" | `README.md` "What the base case currently shows" + `tables/cost_components.csv` for the line-item breakdown |
| "How sure are we about that number?" | The `evidence_tier` column for that parameter in `config/model_parameters.csv`, and its `notes` field |
| "What CPT code is that billed under?" | `docs/clinical_coding_reference.md` Section 1 |
| "Does this hold up outside [X]?" | `docs/vignettes/03_interpreting_evidence_tiers_and_sensitivity.md` and the geographic-sensitivity figure |
| "Where did this number come from?" | `docs/data_sources.md` -- the exhaustive provenance log for every parameter, in the order it was investigated |
| "Has anyone checked this against a published study?" | `docs/validation_notes.md` and `tables/manuscript_table9_validation_status.csv` |
| "What would it take to get real Medicaid/commercial data here instead of Medicare?" | `docs/mrf_hospital_data_overview.md` for the what/why/which-hospitals summary; `docs/data_sources.md`'s hospital payer-rate sections for the full provenance log; `docs/vignettes/02_adding_a_new_hospital_payer_rate.md` if you want to extend that sample |
| "Can I see the full manuscript?" | `manuscript/manuscript.qmd` (render with `quarto render manuscript/manuscript.qmd`); `manuscript/manuscript_slides.pptx` for a slide-deck version with speaker notes |
| "What does this figure/table actually mean?" | `docs/figures_reference.md` and `docs/tables_dictionary.md` |

## 7. A short glossary

Plain-English definitions for terms you'll see throughout the repository's documentation,
in the order they come up above:

- **Cost-minimization analysis**: a health-economics study design that assumes all
  compared options work equally well, so the only question is which costs less. Contrast
  with *cost-effectiveness analysis*, which weighs cost against a difference in benefit.
- **Decision-analytic model** / **decision tree**: a structured "if this happens, then
  that" map of a clinical pathway (here: sample succeeds, or fails and escalates to D&C),
  with a cost or outcome attached to each branch. `figures/figure7_decision_tree.png` is
  this model's actual decision tree, generated from live model output.
- **Base case**: the model's main, central-estimate result, using every parameter's base
  value (as opposed to a sensitivity analysis, which deliberately varies them).
- **Deterministic sensitivity analysis / one-way sensitivity / tornado plot**: varying one
  parameter at a time to see how much the result moves; named "tornado" for the shape of
  the resulting horizontal bar chart.
- **Probabilistic sensitivity analysis (PSA) / Monte Carlo simulation**: varying *every*
  uncertain parameter at once, many times (here, 1,000 times), each according to its own
  probability distribution, to see how often each conclusion holds.
- **Evidence tier**: this repository's A/B/C/D/structural grading of how directly a
  parameter's source applies to this exact clinical population (see Section 3 above).
- **ICER (incremental cost-effectiveness ratio)**: additional cost divided by additional
  benefit, comparing one strategy to the next-best alternative. Appears in this model's
  secondary cost-effectiveness analysis, not the cost-minimization base case (which has no
  benefit difference to divide by).
- **Dominated**: a strategy is dominated if another option is both cheaper and at least as
  effective -- there's never a reason to choose it.
- **GPCI (Geographic Practice Cost Index)**: the real CMS adjustment factor that makes the
  same CPT code pay a different Medicare amount in different parts of the country; used by
  the geographic sensitivity analysis.
- **CHEERS 2022**: the standard reporting checklist for health-economic evaluations that
  this manuscript is written to satisfy (`docs/CHEERS_2022_checklist.md`).
- **MRF (machine-readable file)**: the hospital-specific payer-rate file every U.S.
  hospital must publish under the CMS Hospital Price Transparency Rule; the source of the
  real-world payer-rate data in `data/gyn_onc_hospital_payer_rates.csv`.

## 8. Ground rules before you touch anything

- **Never hand-type a number into the manuscript, a slide, or a table.** Every number this
  repository reports is generated by a script from `config/model_parameters.csv`. If a
  number needs to change, change the parameter and re-run the relevant `analysis/*.R`
  script -- see `docs/vignettes/01_running_the_base_case.md` for the exact run order.
- **Never average a facility and nonfacility rate together**, or treat Medicare Advantage
  and true fee-for-service Medicare as interchangeable. Both distinctions are deliberate
  and explained in `docs/clinical_coding_reference.md`.
- **If you can't verify a clinical or coding fact directly, say so explicitly** rather than
  filling it in from memory -- this is the single most consistently enforced convention
  across every file in `docs/`, and the fastest way to lose a reviewer's trust is to break
  it.
- **Run `Rscript tests/testthat.R` before and after any change.** If it was green before
  your change and red after, you broke something -- fix it before moving on, don't work
  around it.

## 9. Where to go next

You now know enough to be useful. For anything deeper than this guide covers:
`README.md`'s "Documentation" section is the full index of every `docs/` file, with a
one-line description of each.
