# Methods notes

## This is a cost-minimization analysis, not a cost-effectiveness analysis

The model assumes that an adequate endometrial biopsy specimen provides equivalent diagnostic
information regardless of which strategy obtained it. Under that assumption, the three strategies
are being compared on cost alone, so this is a **cost-minimization analysis** (or "cost analysis"),
not a cost-effectiveness or cost-utility analysis -- there is no QALY axis, willingness-to-pay
threshold, or efficiency frontier in the base case. This is a deliberate departure from
`colpocleisis_costeff`, which *was* a cost-utility analysis (see `docs/reuse_mapping.md`).

If a future extension adds differences in adequate-sampling probability *combined with* differences
in downstream diagnostic consequences (cancer detection, time-to-diagnosis, QALYs), the analysis
would become a true cost-effectiveness analysis at that point -- the repository's structure
(parameters separated from functions, `future_extension`-tagged rows already sitting in
`config/model_parameters.csv`) is intended to make that extension additive rather than a rewrite.

## The incremental-cost principle

The central conceptual choice in this model is that patients with Lynch syndrome are assumed to be
undergoing surveillance colonoscopy **regardless of whether endometrial biopsy is added to it**.
The relevant economic question is therefore not

> cost(colonoscopy + EMB) vs. cost(office EMB)

but

> cost(**adding** EMB to an already-planned colonoscopy) vs. cost(arranging EMB separately)

Concretely, `compute_combined_emb_strategy_cost()` in `R/strategy_costs.R` never charges:

- the baseline colonoscopy professional fee,
- the GI/endoscopist's fee,
- the baseline procedural sedation/anesthesia cost for the colonoscopy itself
  (`colonoscopy_anesthesia_episode_cost` is retained in `config/model_parameters.csv` only as a
  reference value, and `tests/testthat/test-strategy-costs.R` enforces that it is never summed into
  the combined-arm cost).

Only costs *incremental* to that already-planned colonoscopy are counted: the incremental
gynecologic professional time, biopsy supplies, pathology, incremental room/anesthesia minutes, any
incremental anesthetic drug cost, and coordination overhead.

## Decision-tree structure: initial attempt, then escalation to D&C

Each strategy is modeled as a one-step decision tree rather than three isolated point-costs:

```
E(cost) = initial_cost + P(escalation to D&C) * E(cost_D&C)
```

This mirrors how the combined-screening literature actually describes practice: Nebgen et al. 2014
(the MD Anderson long-term combined colonoscopy+EMB cohort, PMC4389779) explicitly report that
patients with cervical stenosis or inadequate tissue were scheduled for hysteroscopy/D&C. Modeling
office EMB and combined EMB with the same structural shape (initial attempt -> success or D&C
rescue) makes them directly comparable and lets the D&C arm's own cost function double as the
"rescue" cost for the other two arms -- so a change in D&C cost (e.g. `dnc_facility_or_asc_fee`)
correctly propagates into the office and combined arms' expected costs too, weighted by each arm's
own escalation probability. `R/threshold_analysis.R`'s `threshold_dnc_dominated_facility_fee()`
depends on this pass-through: see the note below on what it found.

D&C itself is modeled as **deterministic**, with no escalation branch of its own -- a simplifying
assumption. In practice a small fraction of D&C procedures are themselves nondiagnostic or
complicated; this is not currently modeled (there is no data source for a Lynch-specific D&C
failure rate in this repository), and `hysteroscopy_failure_rate_lynch_range` is retained in
`config/model_parameters.csv`, tagged `future_extension`, for whoever adds this later.

## Two escalation probabilities, and why they are not the same parameter

- **Office arm:** `emb_failure_lynch` (a pooled 13.7% estimate across four Lynch-specific
  surveillance studies) is multiplied by `office_to_dnc_escalation_fraction` (a **provisional**
  placeholder currently fixed at 100%, i.e. every failed office attempt is assumed to escalate to
  D&C rather than, say, a repeat office attempt).
- **Combined arm:** `combined_to_dnc_probability` (3.6%, i.e. 2/55) is Nebgen et al.'s *directly
  observed* escalation-to-procedure rate in the combined-screening cohort -- it does not need a
  separate escalation-fraction assumption stacked on top, because it already measures "proceeded to
  D&C," not just "failed."

These two probabilities are evidence of genuinely different quality (a pooled multi-study rate with
an assumed 100% escalation fraction, vs. a single cohort's directly observed escalation rate), and
the parameter table's `notes` column says so for both. Do not average them together or treat them
as interchangeable "failure rate" parameters.

## What the base-case run actually found

Running `analysis/01_base_case.R` under current parameters (many of them still provisional -- see
`docs/data_sources.md`) produces:

- Combined EMB: **$499.19** per patient
- Office EMB: **$707.89** per patient
- Operative D&C: **$2,879.90** per patient
- Combined EMB is **$208.69 (29.5%) cheaper** than office EMB
- Combined EMB remains the least expensive strategy as long as incremental colonoscopy-suite time
  stays below **~11.2 minutes** -- notably close to, but comfortably above, the upper end of the
  observed 1-12 minute range from Huang et al. 2011
- D&C is dominated (more expensive than both alternatives) at every tested facility fee, **including
  $0** -- see the caveat below
- Combined EMB was cost-saving vs. office EMB in **85.8%** of 1,000 probabilistic-sensitivity draws

**Caveat on the D&C-dominance finding:** several D&C-arm cost components
(`dnc_facility_or_asc_fee`, `dnc_preop_clinic_visit_cost`, `dnc_recovery_room_cost`,
`dnc_anesthesia_cost`) are still provisional placeholders, not literature- or CMS-sourced values.
The finding that D&C is dominated even before any facility fee is added is therefore driven partly
by stacked placeholder assumptions and should be treated as illustrative until those four parameters
are replaced with real data (see `docs/data_sources.md`'s priority list).

## Simplifying assumptions not yet relaxed

- Pathology cost (`emb_pathology_cost`) is assumed identical across all three strategies (one
  specimen, one CPT 88305 charge each time). If specimen complexity or handling differs by setting,
  this would need to be split into strategy-specific pathology parameters.
- The model does not yet distinguish "cannot access the endometrium" from "obtained tissue but
  inadequate/nondiagnostic" as separate failure modes, even though `emb_failure_general_adambekov_2017`
  in `config/model_parameters.csv` documents that distinction (8/201 access failures vs. 37/201
  inadequate specimens) for a future refinement.
- `office_to_dnc_escalation_fraction`'s 100% base case is conservative in one direction (it assumes
  no repeat office attempts) but its effect on the model's conclusion has not been separately
  quantified -- it is included in the one-way sensitivity set precisely so this can be checked.
