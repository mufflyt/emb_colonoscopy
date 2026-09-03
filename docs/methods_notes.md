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
hysteroscopy complication probabilities -- Hefler et al. 2009, ACOG Committee Opinion 800).
`run_probabilistic_sensitivity()` carries these clinical-outcome columns alongside every cost draw, so
a finding like "combined EMB remained less costly while exposing fewer patients to D&C-rescue-driven
adverse-event risk" can be made from the same Monte Carlo realizations as the cost finding, not a
separately-drawn parallel analysis.

**2026-09-02 update: `office_unresolved_probability` is now 0, always, by design -- see below.**
Between 2026-08-31 and 2026-09-02 this repository's base case had `office_to_dnc_escalation_fraction =
1.0` (100% of failures assumed rescued), which made the delayed-diagnosis probability exactly zero in
the base case *but nonzero in PSA draws* whenever that parameter's `triangular(0.5, 1, 1)` distribution
drew below 1.0 -- a mechanically-generated "unresolved failure" outcome that no source actually
described as a distinct clinical pathway. On 2026-09-02, `office_to_dnc_escalation_fraction` was
superseded by a two-parameter repeat-attempt structure sourced directly from Yi et al. 2018's own
decision tree (a repeat office Pipelle attempt, which itself either succeeds or -- per Yi's own text,
"the physician will then move to the D&C route" -- proceeds to D&C). That structure has no branch
where a failure is simply left unresolved, so `office_unresolved_probability` (and therefore
`office_neoplasia_delayed_probability`) is now exactly 0 in every draw, for the same underlying reason
the combined arm's always was. See "Interpretation of delayed-neoplasia outcomes" below for what this
does and does not mean.

This is still not a full cost-effectiveness analysis: `R/diagnostic_yield.R` also contains
`compute_diagnostic_yield()`, a broader Pipelle-vs-D&C sensitivity/specificity-based detection-
probability function (Sakna et al. 2023, BMJ Open, manuscript reference 17) that is deliberately not
built out further (no PSA wiring, no equivalence-margin testing) -- reproducing a full
diagnostic-accuracy decision tree with prevalence, sensitivity/specificity, and a true/false-positive/
negative branching structure is a substantially larger undertaking (see `docs/validation_notes.md`'s
discussion of why Yi et al. 2018 could not be reproduced by this repository's cost-only engine) than
the narrower "does the higher inadequate-sampling probability of office EMB create enough downstream
diagnostic risk to invalidate pure cost minimization?" question `compute_strategy_clinical_outcomes()`
answers.

**2026-09-02 update: `compute_diagnostic_yield()` is now actually run and reported, though its scope
is unchanged.** The function itself existed and was unit-tested before this date, but no analysis
script ever called it and the manuscript never reported its output. `analysis/13_diagnostic_yield.R`
now calls it for both `disease = "cancer"` and `disease = "precancer"`, saving `tables/diagnostic_yield.csv`
(Supplemental Digital Content) and feeding a new Results paragraph and an expanded Discussion
"principal limitation" paragraph. This did NOT add PSA wiring, an equivalence-margin test, or any new
branching structure -- it is still exactly the point-estimate calculation described above, now
reported instead of sitting unused. The four sensitivity parameters it consumes
(`office_emb_cancer_sensitivity`, `dnc_cancer_sensitivity`, `office_emb_precancer_sensitivity`,
`dnc_precancer_sensitivity`) were recategorized in `config/model_parameters.csv` from
`future_extension`/`future_extension` to `probability`/`office_emb` or `probability`/`dnc` to reflect
that they are now genuinely consumed by a reported analysis; the two specificity companions
(`office_emb_cancer_specificity`, `dnc_cancer_specificity`) remain `future_extension` since
`compute_diagnostic_yield()` still does not use specificity at all (no false-positive branch exists in
this narrower calculation). The finding itself -- D&C's point-estimate detection probability exceeds
office and combined biopsy's for both cancer and AEH -- is real but should not be over-read: it is
indirect (general, symptomatic, non-Lynch population) evidence, D&C's own sensitivity estimate carries
an unusually wide 95% CI (28.1%-99.3%, pooled from only 5 studies), and the calculation has no PSA
uncertainty propagation of its own. See the manuscript's Discussion for the full caveat.

### Interpretation of delayed-neoplasia outcomes

**Revised 2026-09-02 -- this section previously described an asymmetric situation that no longer
exists.** Between 2026-08-31 and 2026-09-02, the office-EMB arm had a nonzero, PSA-varying
delayed-neoplasia estimate (mean 1.55 per 1,000 in the last run under that structure) while the
combined-EMB arm's was always exactly 0 "by construction" -- an asymmetry driven entirely by the two
arms' escalation logic being sourced differently (a single wide-uncertainty `office_to_dnc_escalation_fraction`
parameter for office EMB, vs. a directly-observed escalation rate with no unresolved branch for
combined EMB), not by any actual evidence that the two strategies' true risks differ.

**As of 2026-09-02, both arms have zero estimable delayed-neoplasia risk, for the same structural
reason.** `office_to_dnc_escalation_fraction` was superseded by a two-parameter repeat-attempt
structure (`office_repeat_attempt_fraction`, `office_repeat_attempt_success_probability`) built
directly from Yi et al. 2018's own decision tree, which -- like the combined arm's
`combined_to_dnc_probability` -- has no branch where a failed attempt is simply left unresolved: Yi's
own text states that a failed repeat Pipelle attempt always proceeds to D&C. Both arms' failure
pathways therefore account for essentially all failures, and `neoplasia_delayed_per_1000` is exactly
0.00 for both strategies in every one of 1,000 PSA draws (verified via
`analysis/12_independent_psa_verification.R`).

**This is a null result under current evidence, not a finding that either strategy's true risk is
zero.** None of the underlying studies -- Yi et al.'s Pipelle decision-tree model, the general
(non-Lynch) insufficient-sample literature it draws its repeat-success rate from (Kandil et al. 2014),
or the combined-screening cohort (Nebgen et al. 2014) -- was designed to detect or report a distinct
unresolved-failure outcome. A true difference between strategies could exist without being visible to
this analysis; what would resolve this is a study, in either population, that follows sampling
failures forward far enough to confirm whether every patient with a failed attempt eventually
received either an adequate repeat sample or D&C, rather than assuming or inferring it from aggregate
escalation rates.

**The major-adverse-event comparison remains the genuine, non-degenerate clinical-risk finding.**
Combined EMB had substantially lower D&C-rescue-driven major-AE exposure than office EMB (mean 0.36
vs. 2.48 events per 1,000 in the current run), which is not true by construction -- it reflects real
differences in each arm's probability of ultimately requiring D&C, and office EMB's mean AE exposure
rose further once the repeat-attempt structure's narrower escalation-probability range replaced the
old parameter's occasionally-generous PSA draws (see the update note above).

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

## Societal-perspective secondary analysis (2026-09-02): patient time and travel

The base case's healthcare-sector perspective deliberately excludes patient time, transportation,
and lost productivity (stated explicitly in the manuscript's Methods). `R/societal_costs.R` adds a
separate, deterministic secondary analysis (`compute_strategy_expected_encounters()`,
`compute_strategy_societal_costs()`, driven by `analysis/14_societal_perspective.R`) that
reintroduces this excluded cost category, using the same incremental-cost logic above: the
colonoscopy day itself is never counted for any arm, since the patient is assumed to be undergoing
it regardless of which EMB strategy is chosen. What IS counted is each strategy's expected number of
*dedicated* patient-borne encounters -- office_emb's initial visit plus its (small) repeat-attempt
probability of a second visit; combined_emb's separate preoperative office visit (`TRUE` in the base
case per `combined_requires_preop_office_visit`, `FALSE` in the existing alternate scenario); and
D&C's fixed 2 encounters (preop clinic visit + OR/procedure day) -- each weighted, where relevant, by
the exact same escalation probabilities `R/strategy_costs.R` already uses for dollar costs (a
consistency guard test in `tests/testthat/test-societal-costs.R` enforces this, mirroring the pattern
already used for `R/diagnostic_yield.R`). Every encounter is valued at a single published per-visit
opportunity-cost estimate (`patient_time_opportunity_cost_per_visit`, Ray et al. 2015, $43 in 2010
dollars, inflated to 2026 dollars using a NEW general CPI-U series, `data/cpi_all_items.csv` --
deliberately not the medical-care CPI series used elsewhere, since a wage-based cost should track
general price/wage inflation, not medical-service-price inflation).

**Result:** in the base case, this widens rather than narrows combined biopsy's cost advantage over
office biopsy ($243.06 healthcare-sector -> $257.94 societal-total), and widens it much further under
the alternate scenario where combined biopsy's preoperative visit is folded into the colonoscopy day
($331.83 healthcare-sector -> $412.32 societal-total). See the manuscript's Methods/Results/Discussion
for the reported numbers and `patient_time_opportunity_cost_per_visit`'s own notes in
`config/model_parameters.csv` for the full sourcing and disclosed limitations (dollar-year inferred
rather than primary-confirmed; captures time and travel-TIME opportunity cost only, not out-of-pocket
travel expense or caregiver time; every encounter valued at the same rate, which likely understates
D&C's true relative burden, since its OR/anesthesia-day encounter plausibly costs more patient time
than a routine office visit and no differentiated source was identified for that difference).

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

- **Office arm, superseded 2026-09-02:** `emb_failure_lynch` (a pooled 13.3% estimate across three
  Lynch-specific surveillance studies confirmed genuinely Pipelle-specific by direct primary-source
  verification -- see the correction note above) is combined with two sourced parameters,
  `office_repeat_attempt_fraction` (5%, an expert clinical estimate) and
  `office_repeat_attempt_success_probability` (75%, reconstructed 95% CI 70.73%-79.15%, from Kandil et
  al. 2014's 1,120-patient insufficient-sample cohort -- **replaced 2026-09-02**, same day as the
  structure below was wired in; originally sourced from Adambekov et al. 2017's n=8 subgroup, 25%,
  exact binomial 95% CI 3.2%-65.1%, superseded for a much larger and more directly relevant cohort --
  see that parameter's own notes in `config/model_parameters.csv` for the reconstruction methodology),
  reproducing Yi et al. 2018's own decision-tree structure for a failed Pipelle attempt: either a
  repeat office attempt (5% of failures, succeeding 75% of the time) or direct escalation to D&C. This
  replaces the single **provisional** `office_to_dnc_escalation_fraction` parameter (fixed at 100%,
  i.e. every failed office attempt assumed to escalate to D&C with no repeat-attempt pathway at all),
  which is now superseded and retained in `config/model_parameters.csv` only as a historical record --
  see that parameter's own notes for the full supersession rationale. No study directly measures this
  repeat-vs-escalate split in a Lynch-specific standalone-office population; Yi et al. 2018, Adambekov
  et al. 2017, and Kandil et al. 2014 are all general (non-Lynch) populations.
  See `docs/data_sources.md` for the full search and `docs/ae_cost_evidence_table.md`-style reasoning
  applied to these two parameters in `config/model_parameters.csv`'s own notes.
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

- Combined EMB: **$506.11** per patient
- Office EMB: **$749.18** per patient (includes the office repeat-attempt structure wired in
  2026-09-02, using the Kandil-et-al.-2014-sourced 75% repeat-success probability -- see
  "Interpretation of delayed-neoplasia outcomes" above)
- Operative D&C: **$3,839.81** per patient (includes a partial, management-pathway-weighted adverse-event
  cost for uterine perforation, wired in 2026-09-01 -- see `docs/ae_cost_evidence_table.md` for the
  full sourcing and what remains deliberately excluded)
- Combined EMB is **$243.06 (32.4%) cheaper** than office EMB
- Combined EMB remains the least expensive strategy as long as incremental colonoscopy-suite time
  stays below **~12.3 minutes** -- above the observed 1-12 minute range from Huang et al. 2011,
  meaning the base case's own room-time assumption is now comfortably inside the threshold rather
  than close to its edge
- D&C is dominated (more expensive than both alternatives) at every tested facility fee, **including
  $0** -- see the caveat below
- Combined EMB was cost-saving vs. office EMB in **~91%** of 1,000 probabilistic-sensitivity draws
  (`Rscript analysis/03_probabilistic_sensitivity.R`; `run_probabilistic_sensitivity()` is seeded by
  default as of 2026-09-01 -- see `docs/testing_philosophy.md` -- so this is reproducible run to run,
  not an unseeded estimate)

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
tested, with its advantage over office EMB *widening* from $195.62 in the low-cost locality to $333.44
in the high-cost locality. This is a deterministic analysis, deliberately kept out of
`run_probabilistic_sensitivity()` -- geography is a "does this generalize elsewhere" question, not a
parameter-uncertainty question the way a study's confidence interval is.

## Cost-consequence secondary analysis (2026-09-03): cost per additional case detected

This repository's base case is a cost-minimization analysis (see above). Turning it into a full
cost-utility analysis (QALYs, an ICER against a willingness-to-pay threshold) would require a
stage-shift/survival model (delayed detection -> later-stage diagnosis -> worse survival) and
health-state utility values -- a substantially larger undertaking, and one that would almost
certainly have to lean on general (non-Lynch) oncology literature for Lynch-specific stage-shift and
utility data that likely does not exist, extending rather than resolving this model's existing
evidence-tier-C pattern. `R/cost_effectiveness.R` instead adds a deliberately lighter alternative: an
incremental cost-effectiveness ratio (ICER) using data this repository already has, no new sourced
parameters required. `compute_diagnostic_yield_cost_effectiveness()` combines
`compute_strategy_costs()`'s healthcare-sector cost with `compute_diagnostic_yield()`'s detection
probability (see "Diagnostic-yield..." section above) into dollars per additional expected true case
detected -- no disease-prevalence parameter is needed for this interpretation, since dividing a cost
difference by a detection-*probability* difference already yields dollars per additional expected
case in a cohort of any size.

`compute_incremental_cost_effectiveness()` implements both standard health-economic dominance rules
(strict dominance and extended/weak dominance via monotonic stepwise-ICER checking along the cost-
sorted frontier) generically, tested against synthetic cases exercising both, not just this
repository's real three-strategy data (which -- as it happens -- triggers neither: cost and detection
probability rise together from combined_emb -> office_emb -> dnc for both cancer and precancer, so
all three remain on the frontier). Result: ICER(office_emb vs combined_emb) ~ $20,843 per additional
cancer case detected (~$36,823 for AEH); ICER(dnc vs office_emb) ~ $33,437 per additional cancer case
detected (~$59,073 for AEH). Like `compute_diagnostic_yield()` itself, this is a deterministic point
estimate, not integrated into the probabilistic sensitivity analysis, and inherits the same evidence
caveats (general, symptomatic, non-Lynch sensitivity data; D&C's own sensitivity estimate carries a
very wide 95% CI). See `analysis/15_cost_effectiveness.R` / `tables/cost_effectiveness.csv` for the
reproducible output. **Not yet added to the manuscript itself**: the journal's word limits (Discussion
<=750, total Intro+Methods+Results+Discussion <=3,000) were already at their cap after the
diagnostic-yield and societal-perspective secondary analyses were added; reporting this one in the
manuscript text will require either further trimming elsewhere or cutting something else to make
room -- a decision left to the author rather than made silently.

## Simplifying assumptions not yet relaxed

- Pathology cost (`emb_pathology_cost`) is assumed identical across all three strategies (one
  specimen, one CPT 88305 charge each time). If specimen complexity or handling differs by setting,
  this would need to be split into strategy-specific pathology parameters.
- The model does not yet distinguish "cannot access the endometrium" from "obtained tissue but
  inadequate/nondiagnostic" as separate failure modes, even though `emb_failure_general_adambekov_2017`
  in `config/model_parameters.csv` documents that distinction (8/201 access failures vs. 37/201
  inadequate specimens) for a future refinement.
- **RELAXED 2026-09-02** (previously listed here as not-yet-relaxed): the office arm's "no repeat
  attempts, every failure escalates to D&C" assumption is superseded by the
  `office_repeat_attempt_fraction`/`office_repeat_attempt_success_probability` structure -- see
  "Interpretation of delayed-neoplasia outcomes" above. This traded one simplifying assumption for a
  narrower one: the new parameters are sourced but from a small (n=8), general (non-Lynch) evidence
  base, and the structural assumption that a failed *repeat* attempt always escalates to D&C (rather
  than sometimes remaining unresolved) is itself unverified for either population -- it is simply what
  Yi et al. 2018's own decision tree assumes.
- D&C's own inadequate-sampling risk is still not modeled (no escalation branch of its own, same
  gap noted above); `hysteroscopy_failure_rate_lynch_range` (`future_extension`) remains the
  candidate parameter for whoever adds it. The new adverse-event probabilities
  (`dnc_perforation_probability`, `hysteroscopy_diagnostic_complication_probability`, etc.) have no
  companion dollar costs -- `docs/data_sources.md` documents two indirect, doubly-inherited cost
  anchors from an unrelated gestational-trophoblastic-neoplasia model
  (`cost_uterine_perforation_gtn_model_2020`, `cost_hemorrhage_gtn_model_2020`) kept only as a
  documented starting point, explicitly not treated as sufficient evidence to wire in.
