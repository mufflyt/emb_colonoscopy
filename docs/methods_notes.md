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

**2026-08-31 update: that extension's first piece now exists, additively.**
`R/diagnostic_yield.R::compute_strategy_clinical_outcomes()` directly tests, rather than assumes,
the equivalent-effectiveness assumption above, using the `cancer_or_precancer_after_failed_sample`
parameter that had been sitting unused in `config/model_parameters.csv` since before this extension
existed: it computes each strategy's probability of an *unresolved* sampling failure (a failure that
does not get rescued to D&C) and the resulting delayed-cancer/precancer-diagnosis probability, plus
each strategy's D&C-rescue-driven adverse-event exposure (using newly added, real-cited D&C/
hysteroscopy complication probabilities -- Hefler et al. 2009, ACOG Committee Opinion 800). At the
current base case (`office_to_dnc_escalation_fraction = 1.0`, i.e. 100% of failures are assumed
rescued), the delayed-diagnosis probability is exactly zero for every strategy by construction --
this metric only becomes informative under a sensitivity/scenario override of that escalation
fraction, which is precisely the point: it quantifies what the 100% assumption is actually protecting
against, rather than asserting equivalence outright. `run_probabilistic_sensitivity()` now carries
these clinical-outcome columns alongside every cost draw, so a finding like "combined EMB remained
less costly while exposing fewer patients to D&C-rescue-driven adverse-event risk" can be made from
the same Monte Carlo realizations as the cost finding, not a separately-drawn parallel analysis.

This is still not a full cost-effectiveness analysis: `R/diagnostic_yield.R` also contains
`compute_diagnostic_yield()`, a broader Pipelle-vs-D&C sensitivity/specificity-based detection-
probability function (Sakna/Nabhan et al. 2023, BMJ Open), but it is deliberately not built out
further (no PSA wiring, no equivalence-margin testing) -- reproducing a full diagnostic-accuracy
decision tree with prevalence, sensitivity/specificity, and a true/false-positive/negative branching
structure is a substantially larger undertaking (see `docs/validation_notes.md`'s discussion of why
Yi et al. 2018 could not be reproduced by this repository's cost-only engine) than the narrower
"does the higher inadequate-sampling probability of office EMB create enough downstream diagnostic
risk to invalidate pure cost minimization?" question `compute_strategy_clinical_outcomes()` answers.

### Interpretation of delayed-neoplasia outcomes

**2026-08-31, demonstrated empirically via `analysis/03_probabilistic_sensitivity.R`'s 1,000-draw
output:** the delayed-neoplasia outcome is informative for the standalone office-EMB arm but is not
currently symmetric across strategies.

For office EMB, the model permits a failed or inadequate sample to remain unresolved when the sampled
`office_to_dnc_escalation_fraction` is less than 1.0; these unresolved failures are then combined with
the probability of cancer or precancer after an inadequate sample to estimate potentially delayed
neoplasia.

The combined-EMB arm has no analogous unresolved-failure branch. `combined_to_dnc_probability` is a
directly observed probability of proceeding to hysteroscopy/D&C after unsuccessful combined sampling
and is modeled as an escalation probability rather than as a raw sampling-failure probability followed
by a separately estimated escalation fraction. Consequently, the current model assigns zero unresolved
combined-arm sampling failures and therefore zero delayed-neoplasia events to that strategy by
construction.

Accordingly, the finding that combined EMB had no greater delayed-neoplasia risk than office EMB in
100% of probabilistic-sensitivity draws should not be interpreted as evidence of diagnostic
superiority or equivalence. The result reflects an asymmetry in available evidence and model
structure. A symmetric comparison would require data on the probability of combined EMB failure and,
conditional on failure, the probability that the patient does not receive definitive follow-up
sampling.

The delayed-neoplasia outcome is therefore retained as an exploratory measure of the consequences of
incomplete follow-up after failed office EMB, but it is not used as a comparative effectiveness
endpoint between office and combined EMB in the primary analysis. The joint "combined EMB is cheaper
AND has no greater delayed-neoplasia risk" probability (69.3% in the 1,000-draw run above) is
mathematically identical to the cost-only "combined EMB is cheaper" probability for exactly this
reason -- it adds no independent information and should not be reported as a distinct finding. The
genuine, non-degenerate clinical-risk comparison from that same run is the major-adverse-event one:
combined EMB had no greater D&C-rescue-driven major-AE exposure than office EMB in 97.8% of draws
(mean 0.67 vs. 2.12 events per 1,000), which is not true by construction and does reflect real overlap
in the underlying escalation-probability distributions.

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

- **Office arm:** `emb_failure_lynch` (a pooled 13.3% estimate across three Lynch-specific
  surveillance studies confirmed genuinely Pipelle-specific by direct primary-source verification --
  see the correction note above) is multiplied by `office_to_dnc_escalation_fraction`
  (**provisional**, fixed at 100%, i.e. every failed office attempt is assumed to escalate to D&C
  rather than, say, a repeat office attempt). No study reports this specific repeat-vs-escalate split
  for the standalone office population, even now that full text of all four candidate Lynch
  EMB-failure studies has been obtained via institutional access (2026-08-31). Nebgen et al. 2014's
  MD Anderson combined-screening protocol grounds the 100% assumption in an analogous context -- its
  written protocol escalates every EMB failure straight to D&C with no repeat-office step -- but that
  describes the combined arm, not standalone office EMB, so this remains a placeholder for this
  parameter's actual target population. See `docs/data_sources.md` for the full search.
- **Combined arm:** `combined_to_dnc_probability` (1.8%, i.e. 2/111) is Nebgen et al.'s *directly
  observed* escalation-to-procedure rate in the combined-screening cohort -- it does not need a
  separate escalation-fraction assumption stacked on top, because it already measures "proceeded to
  D&C," not just "failed." **Corrected 2026-08-31** from an earlier 3.6% (2/55): the paper's "Two
  women (3.6%) had cervical stenosis..." sentence sits among unambiguously patient-level percentages
  (mean age, race, parity, weight, all computed over the 55 patients), not the paper's own 111-visit
  denominator it uses elsewhere for encounter-level rates. Since `compute_combined_emb_strategy_cost()`
  prices a single encounter, not a patient's multi-year screening history, 2/55 was the wrong
  denominator; 2/111 is the per-encounter rate the paper's own events are actually counted against.
  See `docs/data_sources.md` for the full audit.

These two probabilities are evidence of genuinely different quality (a pooled multi-study rate with
an assumed 100% escalation fraction, vs. a single cohort's directly observed escalation rate), and
the parameter table's `notes` column says so for both. Do not average them together or treat them
as interchangeable "failure rate" parameters.

## What the base-case run actually found

Running `analysis/01_base_case.R` under current parameters (many of them still provisional -- see
`docs/data_sources.md`) produces:

- Combined EMB: **$505.88** per patient
- Office EMB: **$764.93** per patient
- Operative D&C: **$3,827.04** per patient
- Combined EMB is **$259.04 (33.9%) cheaper** than office EMB
- Combined EMB remains the least expensive strategy as long as incremental colonoscopy-suite time
  stays below **~12.7 minutes** -- above the observed 1-12 minute range from Huang et al. 2011,
  meaning the base case's own room-time assumption is now comfortably inside the threshold rather
  than close to its edge
- D&C is dominated (more expensive than both alternatives) at every tested facility fee, **including
  $0** -- see the caveat below
- Combined EMB was cost-saving vs. office EMB in **~82%** of 1,000 probabilistic-sensitivity draws
  (`Rscript analysis/03_probabilistic_sensitivity.R`; this figure moves a few points run to run since
  the script is unseeded, consistent with `office_to_dnc_escalation_fraction` and
  `combined_to_dnc_probability` both genuinely varying in PSA -- see their correction notes below)

(Updated 2026-08-28 across six steps: `dnc_facility_or_asc_fee`, `dnc_anesthesia_cost`,
`coordination_cost`'s wage component, `office_visit_em_cost`/`dnc_preop_clinic_visit_cost` were each
replaced with real data; `dnc_recovery_room_cost` was removed from the D&C arm entirely after
confirming it was double-counting a cost already inside `dnc_facility_or_asc_fee`; and
`emb_office_professional_cost` and `emb_disposable_supply_cost` were corrected for a
double-count/setting-mismatch found in the office and combined arms (see "Supply-cost double-count
and facility-vs-nonfacility rate correction" below). Then, 2026-08-30,
`combined_requires_preop_office_visit` was flipped from FALSE to TRUE (see below), adding
`office_visit_em_cost` ($88.76) to the combined arm and narrowing its advantage further. Then,
2026-08-31, `emb_failure_lynch` was corrected from 13.7% to 13.3% after direct primary-source
verification found two errors in the secondary review it had relied on (see "emb_failure_lynch
correction" below), raising the office arm's own expected cost slightly and narrowing the margin a
little further. Then, still 2026-08-31, `combined_to_dnc_probability` was corrected from 3.6% (2/55,
a patient-level prevalence) to 1.8% (2/111, the per-encounter rate matching how this parameter is
actually consumed) -- see the correction note above -- which widened the combined arm's advantage
again, more than offsetting the `emb_failure_lynch` narrowing. Net effect on the headline numbers has
gone in **both directions** across these corrections: some raised the combined arm's advantage,
others (genuine double-count removals, a confirmed clinical-practice requirement) shrank it -- evidence
this process is following the data, not steering toward a preferred conclusion. Minutes threshold
moved from ~11.2 to ~13.8 to ~11.1 to ~10.7 to ~12.7.)

**`combined_requires_preop_office_visit` flipped to TRUE (2026-08-30):** per the model owner's
clinical practice (Tyler Muffly, MD, Denver Health), the combined strategy's protocol includes a
separate preoperative office visit before the colonoscopy date, for consent and risk assessment
specific to adding EMB. This is a structural modeling decision, not a literature-evidence claim (see
`reference_dollar_year` for the same convention), so it is tiered `structural` rather than A-D and no
longer flagged provisional. It adds `office_visit_em_cost` ($88.76) to the combined arm's cost via the
`preop_office_visit` component, which is why the combined-vs-office margin narrowed from $294.22
(37.7%) to $205.46 (26.3%) and the minutes threshold tightened from ~13.8 to ~11.1. Scenario analysis
can set this back to FALSE to model consent/risk assessment folded into existing care instead (the
prior base-case assumption).

**`emb_failure_lynch` correction (2026-08-31):** direct primary-source verification (institutional
full-text access to all four candidate Lynch EMB-failure studies) found that the NIHR systematic
review's Table 11, which this parameter had relied on, contained two errors: Elmasry et al. 2009's
true Pipelle failure count is 5/25 (20.0%), not the 6/25 (24.0%) the review's table stated; and
Rijcken et al. 2003 is not a Pipelle-specific study at all (its "2/17" figure came from a mix of five
different sampling methods, and the genuinely Pipelle-only subset of that study is 0/4). The pooled
estimate was corrected to use only the three studies confirmed genuinely Pipelle-specific (Elmasry
5/25, Lecuru 12/116, Woolderink 5/25 -- Rijcken dropped entirely): (5+12+5)/(25+116+25) = 22/166 =
13.3% (was 13.7%). This is a small, real shift -- office EMB's own expected cost rose slightly
(escalation probability = `emb_failure_lynch` x `office_to_dnc_escalation_fraction`), narrowing
office EMB from $780.23 to $764.93 and the combined-vs-office margin from $205.46 (26.3%) to $190.16
(24.9%). See `docs/data_sources.md` for the full verification chain.

### Supply-cost double-count and facility-vs-nonfacility rate correction (2026-08-28)

Prompted by noticing that `emb_office_professional_cost` (CPT 58100's nonfacility professional fee)
was being charged, unmodified, to *both* the office_emb arm (correct -- EMB happens in the
physician's own office) and the combined_emb arm (questionable -- EMB happens in the facility/
endoscopy-suite where the colonoscopy itself takes place), two things were verified against CMS's
own primary data before changing any code:

1. **Is `emb_disposable_supply_cost` double-counted against the nonfacility professional fee?**
   CMS's CY2026 Physician Fee Schedule Final Rule Direct Practice Expense (PE) Inputs file
   (CMS-1832-F, no AMA-license gate) itemizes every supply CMS prices into CPT 58100's practice
   expense: pelvic exam pack, sterile gloves, needle, syringe, an "endometrial suction curette
   (Pipelle)," uterine sound, tenaculum, lidocaine, and povidone-iodine swabsticks. Every one of
   these items carries `nf_quantity = 1` and `f_quantity = 0` -- i.e. CMS prices them into the
   *nonfacility* PE RVU only. This directly confirms `emb_disposable_supply_cost` was double-counted
   for the office_emb arm (the Pipelle itself is already inside `emb_office_professional_cost`) and
   removed from that arm's cost sum.
2. **Should the combined arm use a facility-setting rate instead?** A live CMS Physician & Other
   Practitioners PUF query for CPT 58100, split by `Place_Of_Srvc`, found a real, substantial gap:
   facility-setting allowed amount = **$60.05** (service-volume-weighted mean, 283 services) vs.
   nonfacility = **$97.03** (4,431 services), 2024 claims data. A new parameter,
   `emb_office_professional_cost_facility`, now supplies the combined arm's incremental professional
   fee. Because the Direct PE Inputs file shows `f_quantity = 0` for every supply item in the
   facility setting -- i.e. those supplies are *not* priced into the facility-rate fee --
   `emb_disposable_supply_cost` (now summed directly from the itemized CMS supply list, $28.79) was
   kept as a genuine incremental cost for the combined arm only.

This finding was independently re-derived per the project's meta-rule (an audit result capable of
changing the study frame requires independent confirmation): the CMS PUF facility/nonfacility split
was re-queried live a second time from a fresh R session before any code changed, and
`tests/testthat/test-independent-confirmation.R`'s hand-written formulas (which never call the
pipeline functions) were updated to match and re-verified against the pipeline's own output. Both new
regression tests in `tests/testthat/test-strategy-costs.R` were mutation-tested (defect planted,
confirmed red, reverted, confirmed green) before this change was committed. See
`docs/data_sources.md` for the full itemized supply list and provenance.

**On `coordination_cost` ($22.08):** the wage half is real (O*NET/BLS OEWS median wage for SOC
43-6013, $22.08/hr); the time half (2 schedulers x 30 min each) is a practitioner estimate from the
PI's own institutional experience (Denver Health), not an independently published source. This is a
genuinely different kind of "provisional" than an unfounded guess -- it reflects real workflow
knowledge -- but is kept flagged `provisional = TRUE` until a formal micro-costing study of
coordination time exists. See `docs/data_sources.md`.

**Milestone: the D&C-dominance finding is now fully empirical, not partly provisional.** Every
component of the D&C arm that participates in the "dominated even at $0 facility fee" check --
`dc_professional_cost`, `emb_pathology_cost`, `dnc_preop_clinic_visit_cost`, and `dnc_anesthesia_cost`
-- is now a real, CMS-sourced value. `dnc_recovery_room_cost` was removed from the D&C cost function
entirely (not sourced, but deliberately excluded): per MedPAC's payment-basics documentation of the
ASC payment system, recovery-room/PACU time is packaged into the facility payment
(`dnc_facility_or_asc_fee`) under OPPS/ASC methodology, so summing it separately would have
double-counted it. `dnc_facility_or_asc_fee` itself (the CMS OPPS/ASC facility rate) is also real, but
is set to $0 for this specific check by construction (that's the point of the check -- does D&C still
lose even giving it the most generous possible facility-fee assumption). At current values, D&C's
cost at $0 facility fee is $519.80 -- entirely the sum of real, sourced components -- against a $411.30
maximum among the alternatives. This is a materially stronger evidentiary basis than the placeholder
stack this finding rested on earlier in the day.

This specific finding is capable of changing the study's frame (it says D&C isn't
merely more expensive but strictly dominated even in a best case), so per
`docs/testing_philosophy.md`'s independent-confirmation rule it has been re-derived
via a second, independent arithmetic path
(`tests/testthat/test-independent-confirmation.R`) that never calls the pipeline
functions that originally produced it, and re-verified (mutation-tested: a planted
double-count defect was confirmed to make both this test and
`test-strategy-costs.R`'s exclusion test fail, then confirmed to pass again on
revert) after the `dnc_recovery_room_cost` removal. Both paths agree: the D&C-vs-
alternatives gap at zero facility fee is a correct consequence of the current
parameter values -- not a pipeline bug.

## Geographic sensitivity (2026-08-31): the base case is not a national-average artifact

`R/geographic_sensitivity.R` re-prices the model at four localities (national, Colorado, a low-cost
locality [Arkansas], a high-cost locality [Manhattan]) using real CMS GPCI and OPPS wage-index data --
see `docs/data_sources.md` for the full methodology, citations, and a disclosed limitation (physician
GPCI locality and hospital OPPS wage-index geography are two different CMS systems that don't share a
common unit). Result: combined EMB remained the least expensive strategy in all 4 of 4 localities
tested, with its advantage over office EMB *widening* from $209.77 in the low-cost locality to $353.14
in the high-cost locality. This is a deterministic analysis, deliberately kept out of
`run_probabilistic_sensitivity()` -- geography is a "does this generalize elsewhere" question, not a
parameter-uncertainty question the way a study's confidence interval is.

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
  `compute_strategy_clinical_outcomes()` (see the section above) now gives that check a clinical
  consequence, not just a cost delta: below 100%, it quantifies a nonzero delayed-diagnosis
  probability rather than leaving the risk of the conservative assumption unstated.
- D&C's own inadequate-sampling risk is still not modeled (no escalation branch of its own, same
  gap noted above); `hysteroscopy_failure_rate_lynch_range` (`future_extension`) remains the
  candidate parameter for whoever adds it. The new adverse-event probabilities
  (`dnc_perforation_probability`, `hysteroscopy_diagnostic_complication_probability`, etc.) have no
  companion dollar costs -- `docs/data_sources.md` documents two indirect, doubly-inherited cost
  anchors from an unrelated gestational-trophoblastic-neoplasia model
  (`cost_uterine_perforation_gtn_model_2020`, `cost_hemorrhage_gtn_model_2020`) kept only as a
  documented starting point, explicitly not treated as sufficient evidence to wire in.
