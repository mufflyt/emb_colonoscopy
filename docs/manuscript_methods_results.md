# Methods and Results (draft)

Drafted 2026-08-31 directly from the model's live output (`analysis/01`-`analysis/09`, `docs/data_sources.md`,
`docs/methods_notes.md`). Every number below was pulled from the currently committed table files, not
retyped from memory -- re-run the numbered analysis script to regenerate any of them. Table/figure
numbers 1-9 match `analysis/07_manuscript_outputs.R`'s existing numbering; the geographic and
clinical-outcome sensitivity results are new and not yet folded into that script's numbered output --
they are referenced below by filename until that integration is done (see the note at the end of this
document).

**This is a draft for the model owner to edit, not a finished manuscript section.** It follows the
target journal's structure only loosely and needs a human pass for tone, citation formatting, and any
journal-specific requirements (e.g., CHEERS checklist language) before submission.

---

## Methods

### Study design and perspective

We conducted a cost-minimization analysis comparing three strategies for endometrial cancer
surveillance in women with Lynch syndrome: (1) standalone office endometrial biopsy (EMB), (2)
operative dilation and curettage (D&C), and (3) EMB performed during an already-scheduled surveillance
colonoscopy ("combined EMB"). The analysis takes a U.S. health-system/payer perspective, using
Medicare-anchored allowed amounts (CMS Physician Fee Schedule and Physician & Other Practitioners by
Provider and Service Public Use Files) rather than hospital charges. All costs are reported in 2026
U.S. dollars; costs originally reported in an earlier year were inflation-adjusted using the BLS
Consumer Price Index for Medical Care.

A cost-minimization design assumes equivalent clinical effectiveness across strategies -- specifically,
that an adequate endometrial specimen provides equivalent diagnostic information regardless of which
strategy obtained it. We did not extend the base case to a full cost-effectiveness or cost-utility
analysis (no quality-adjusted life-year axis, willingness-to-pay threshold, or efficiency frontier).
Instead, we conducted two supplementary clinical-outcome sensitivity analyses that directly test,
rather than merely assume, this equivalence (see *Clinical-outcome sensitivity analysis* below).

### Model structure

Each strategy was modeled as a one-step decision tree: an initial sampling attempt, which either
succeeds or fails and escalates to operative D&C.

> E(cost) = initial cost + P(escalation) x E(cost of D&C)

D&C itself was modeled as a deterministic reference arm with no escalation branch of its own in the
base case (a simplifying assumption discussed further below).

The combined-EMB arm was modeled under an **incremental-cost principle**: because the Lynch patient is
assumed to be undergoing the surveillance colonoscopy regardless of whether EMB is added, no
colonoscopy base cost, gastroenterology professional fee, or baseline procedural sedation cost was
charged to this arm. Only costs incremental to the already-planned colonoscopy (the EMB professional
fee at the facility/endoscopy-suite rate, pathology, disposable supplies, incremental procedure-room
and anesthesia time, and scheduling coordination) were included.

### Parameters and evidence hierarchy

Cost parameters were drawn from CMS administrative data: the Physician Fee Schedule and
Physician/Provider Service Public Use Files (2024 and 2026), the Hospital Outpatient Prospective
Payment System (OPPS) and Ambulatory Surgical Center (ASC) payment addenda (July 2026), and the CY2026
Physician Fee Schedule Final Rule Direct Practice Expense Inputs file. Clinical probabilities were
drawn from the published literature, prioritizing Lynch-syndrome-specific data where available: the
office EMB failure probability was pooled from three primary studies confirmed genuinely Pipelle-specific
by direct full-text verification (22/166 = 13.3%), and the combined-arm escalation-to-D&C probability
was the directly observed rate from a 10.5-year, 111-visit MD Anderson combined-screening cohort
(2/111 = 1.8%).

Every parameter was assigned an evidence tier: **A** (Lynch-specific direct data), **B** (contemporary
U.S. public cost/reimbursement data), **C** (general or adjacent-population literature), **D**
(provisional placeholder with no source yet), or **structural** (an analysis convention, not an
evidence claim, e.g. the 2026 reference dollar year). Of 66 parameters in the current model, 10 (15.2%)
are tier A, 24 (36.4%) tier B, 24 (36.4%) tier C, 6 (9.1%) tier D, and 2 (3.0%) structural (Table 8).
Four provisional (tier D or otherwise unresolved) parameters remain in the base case: the
coordination-cost time estimate, the office-arm escalation-to-D&C fraction (fixed at 100%, discussed
below), and two documented exclusions retained only to enforce a regression test against double-counting.

### Sensitivity and uncertainty analyses

We conducted five complementary sensitivity analyses:

1. **Deterministic one-way sensitivity** across the ten parameters expected to most influence the
   combined-vs-office cost difference, varying each individually across its low/high bound while
   holding all others at base case (Table 4, Figure 2).
2. **Probabilistic sensitivity analysis (PSA):** 1,000 Monte Carlo draws, with each parameter sampled
   from a distribution matched to its evidence type -- beta for probabilities, gamma for costs
   (using an explicit shape/rate when the source reported one), and triangular for parameters whose
   uncertainty is a structural/plausibility range rather than a formal confidence interval (Table 5,
   Figure 4).
3. **Threshold analysis:** solving for the parameter value at which the combined strategy's cost
   advantage over office EMB is lost, for four candidate parameters (Table 6, Figure 3a-3b).
4. **Scenario analysis:** illustrative Medicaid (70% of Medicare) and commercial (175% of Medicare)
   reimbursement scenarios, and a structural scenario in which the combined arm's separate preoperative
   office visit is removed (Figure 5).
5. **Budget impact analysis:** annualized cost savings across illustrative cohort sizes of 10 to 1,000
   patients per year (Table 7).

### Geographic sensitivity analysis

To test whether the base-case conclusion is an artifact of national-average Medicare pricing, we
re-priced all three strategies at four localities: the national average, Colorado, a low-cost locality
(Arkansas), and a high-cost locality (Manhattan, NY). Professional-fee components were adjusted using
the real CMS Geographic Practice Cost Index (GPCI) for the relevant CPT code and setting, applying the
standard Medicare relative-value formula (work RVU x work GPCI + practice-expense RVU x PE GPCI +
malpractice RVU x MP GPCI, divided by the unadjusted total RVU). The D&C facility fee was adjusted
using the real CMS Hospital Outpatient Prospective Payment System (OPPS) wage index for the relevant
core-based statistical area, applying the CMS labor-related-share formula (labor share x wage index +
[1 - labor share]) with the actual CY2026 OPPS labor-related share of 60%. Three professional-fee
parameters with a directly verified CPT/setting relative-value-unit match were adjusted this way;
pathology, evaluation-and-management visit costs, and anesthesia costs were not adjusted, as their
exact Medicare payment/setting treatment for geographic adjustment had not yet been independently
verified. This analysis was deliberately kept deterministic rather than folded into the PSA: geography
is a question of whether the conclusion generalizes to a different practice location, not a source of
parameter uncertainty in the way a study's confidence interval is.

### Clinical-outcome sensitivity analysis

We conducted two analyses that directly test the cost-minimization design's implicit
equivalent-effectiveness assumption, computed from the same PSA draws as the cost outputs so that cost
and clinical-outcome findings could be compared within identical simulated realizations.

**Adverse-event exposure.** For each strategy, we estimated exposure to D&C-related adverse events
(a composite of uterine perforation, cervical false passage, and severe hemorrhage, pooled from a
5,359-patient nonobstetric D&C cohort) as a function of that strategy's probability of ultimately
requiring D&C, either as the primary procedure or as a rescue procedure after a failed sampling attempt.

**Delayed cancer/precancer diagnosis.** For the office-EMB arm, we estimated the probability of a
failed sampling attempt that is not rescued to D&C (a function of the office failure probability and
the assumed escalation fraction), combined with the probability of cancer or precancer among women
with a failed or insufficient sample (drawn from a general, non-Lynch postmenopausal-bleeding
meta-analysis). We were unable to construct a symmetric estimate for the combined-EMB arm: the
available combined-screening literature reports a directly observed escalation-to-D&C probability but
does not separately report the fraction of combined-EMB failures, if any, that go unresolved without
any follow-up sampling. This limitation is disclosed explicitly in the Results and Discussion, and the
delayed-neoplasia metric is reported as an exploratory, office-arm-specific measure rather than a
head-to-head comparative-effectiveness endpoint.

### External validation

We compared the model's cost estimates against three independently published analyses: Ladabaum et al.
(2011), a historical (2010-dollar) office-EMB cost anchor, used as a cross-check of the model's own
inflation-adjustment methodology; Yi et al. (2018), a Medicare-payer-perspective decision-tree
comparing Pipelle sampling and D&C, whose full parameter set was extracted from the primary source but
found to be structurally incomparable to this model's cost-only engine (Yi et al.'s model incorporates
diagnostic sensitivity/specificity, disease prevalence, and life-expectancy effectiveness, none of
which this model implements); and Munro et al. (2022), an independent U.S. economic model of office
versus institutional hysteroscopic surgery, whose reported cost figures were used as reference
benchmarks (Table 9).

### Software and reproducibility

All analyses were implemented in R and are version-controlled in a public repository
(github.com/mufflyt/emb_colonoscopy), tagged `analysis-v1.0` for the frozen snapshot underlying this
draft. Model parameters are stored separately from model logic in a single, fully cited CSV file. The
test suite (412 assertions at the time of this draft) is required to pass before any result is
reported; every test protecting a scientific or correctness claim has been proven, by deliberately
planting a realistic defect in the code it protects, to fail when that defect is present and pass when
it is reverted (a discipline logged in full in `docs/testing_philosophy.md`). Any single finding capable
of changing the study's conclusions (e.g., that D&C is dominated by both alternatives, or the corrected
combined-arm escalation probability) was independently re-derived via a second code path that never
calls the function that originally produced it, before being treated as established.

---

## Results

### Base case

In the base case, combined EMB cost an estimated **$506.11** per patient, compared with **$761.94**
for standalone office EMB and **$3,839.81** for operative D&C (Table 3, Figure 1). Combined EMB was
**$255.83 (33.6%)** less expensive than office EMB, and both office-based strategies were substantially
less expensive than D&C, which was dominated by both alternatives at every facility fee tested,
including a facility fee of $0 (i.e., D&C's professional fee, pathology, preoperative visit, and
anesthesia costs alone already exceed either office-based strategy's total cost).

Cost components (Table 2) show the combined arm's cost is driven primarily by the facility-setting EMB
professional fee ($60.05), incremental procedure-room time ($143.67 for 5 minutes at the marginal
per-minute rate), pathology ($70.14), and a required separate preoperative office visit ($88.76, per
the model owner's confirmed clinical practice). The office arm's cost is driven by its office visit
($88.76), professional fee ($97.03), and pathology ($70.14), plus an escalation-weighted contribution
from the 13.3% probability of a failed attempt -- now split, as of 2026-09-02, between a repeat office
attempt (5% of failures, succeeding 25% of the time) and direct D&C escalation (see "Office repeat-attempt
structure" below).

### Deterministic sensitivity

The combined-vs-office cost difference was most sensitive to the office EMB failure probability
(`emb_failure_lynch`, range: -$141.69 to -$510.74 across its 10.3%-20.0% bound) and the combined arm's
incremental added minutes (`combined_emb_added_minutes`, range: -$389.57 to -$21.78 across its
observed 1-12 minute range), followed by the D&C facility fee, the combined-arm escalation probability,
and the per-minute room and anesthesia rates (Table 4, Figure 2). At the upper end of the observed
added-minutes range (12 minutes), the combined arm's advantage over office EMB narrows to $21.78 but
does not reverse.

### Probabilistic sensitivity analysis

Across 1,000 Monte Carlo draws, combined EMB had a mean cost of $541.57 (SD $116.63; 95% range
$362.88-$812.06) and office EMB a mean cost of $759.34 (SD $117.35; 95% range $553.09-$1017.76) (Table 5).
Combined EMB was the least expensive strategy in **90.5%** of draws; office EMB was least expensive in
the remaining 9.5%. D&C was never the least expensive strategy in any of the 1,000 draws. Office EMB's
PSA mean rose noticeably from the pre-repeat-attempt-structure figure despite the base case falling
slightly -- see "Office repeat-attempt structure" below for why.

### Threshold analysis

Combined EMB remained the least expensive strategy as long as the incremental colonoscopy-suite time
stayed below approximately **12.7 minutes** (base case: 5 minutes; observed range: 1-12 minutes) and
as long as the office EMB failure probability stayed above approximately **6.6%** (base case: 13.3%).
The maximum coordination cost the combined arm could absorb before losing its advantage over office EMB
was approximately **$278**, well above the base-case estimate of $22.08. No D&C facility fee within the
tested range ($0-$20,000) caused D&C to stop being dominated by both alternatives (Table 6).

### Budget impact

At illustrative cohort sizes of 10, 25, 50, 100, and 1,000 patients screened annually, adopting
combined EMB over standalone office EMB was projected to save $2,558, $6,396, $12,791, $25,583, and
$255,829 per year, respectively (Table 7).

### Office repeat-attempt structure (wired in 2026-09-02)

`office_to_dnc_escalation_fraction` (a single "fraction of failures escalating to D&C," fixed at 100%
in the base case) is superseded by two sourced parameters reproducing Yi et al. 2018's own
decision-tree logic: `office_repeat_attempt_fraction` (5%, range 0-6%, an expert clinical estimate --
the complement of Yi's "P(moving to D&C if 1st attempted Pipelle failed) = 0.95") and
`office_repeat_attempt_success_probability` (25%, exact binomial 95% CI 3.2%-65.1%, from Adambekov et
al. 2017's Table 1: 2 of 8 patients with a documented history of prior Pipelle failure succeeded on
the attempt studied -- independently confirmed as the exact subgroup Yi et al. cite for the identical
purpose). `compute_office_emb_strategy_cost()` now models: on failure, either a repeat office visit
(costing the same $255.93 as the initial visit, since it is billed as an established-patient
encounter) that succeeds 25% of the time, or direct escalation to D&C. This lowered the office arm's
**base-case** cost slightly ($766.62 -> $761.94, since some failures now resolve via a successful
repeat instead of always paying the full D&C cost) but *raised* its **PSA mean** substantially ($683.44
-> $759.34): the old `office_to_dnc_escalation_fraction`'s `triangular(0.5, 1, 1)` distribution let PSA
draws cut the D&C-escalation probability by as much as half, while the new, better-sourced structure's
maximum possible reduction is bounded by `repeat_attempt_fraction x repeat_attempt_success_probability`
(at most ~3.9% even at the upper 95% CI bounds) -- a much narrower, more disciplined range that no
longer lets office EMB look artificially cheap in PSA draws the way the old single wide-uncertainty
parameter did.

**This also eliminates the office arm's delayed-neoplasia estimate.** Yi et al. 2018's decision tree
has no branch where a failed repeat attempt is left unresolved -- their own text: "If there is a
sampling failure in the second Pipelle attempt, the physician will then move to the D&C route." Under
this structure, `office_unresolved_probability` is exactly 0 in every draw, not a residual PSA
artifact of a parameter dipping below 1.0. See "Clinical-outcome sensitivity" below for what this
changed.

### Clinical-outcome sensitivity

Across the same 1,000 PSA draws used above, D&C-rescue-driven major-adverse-event exposure was
substantially lower for combined EMB (mean 0.35 events per 1,000 patients; SD 0.31) than for office EMB
(mean 2.51 per 1,000; SD 0.54) -- office EMB's mean AE exposure rose along with its rescue probability
under the new repeat-attempt structure (see above). D&C itself carried a mean adverse-event exposure of
19.18 per 1,000 (SD 1.94), the direct adverse-event probability observed in the underlying 5,359-patient
nonobstetric D&C cohort.

**Neither arm retained an estimable delayed-neoplasia risk, as of 2026-09-02.** Before the repeat-attempt
structure was wired in, the office-EMB arm's estimated delayed-neoplasia risk (a failed sample that is
not rescued to D&C, and that turns out to represent cancer or precancer) had a mean of 1.55 per 1,000
patients, driven by draws in which the old `office_to_dnc_escalation_fraction` fell below 100% -- a
mechanism this repository has since determined was not actually evidence-based (no source described a
distinct "unresolved, no further action" pathway; see "Office repeat-attempt structure" above). Under
the current structure, both arms' failure-resolution pathways account for essentially all failures, so
`neoplasia_delayed_per_1000` is exactly 0.00 for combined EMB *and* office EMB in all 1,000 draws. This
is a **null result under current evidence, not a finding that either arm's true risk is zero** -- see
*Limitations*. This also changes the earlier framing: the delayed-neoplasia asymmetry previously
described as "an office-arm-specific exploratory finding" no longer exists as a reportable difference
between the two office-based strategies.

### Geographic sensitivity

Combined EMB remained the least expensive strategy in all four localities tested (Figure 6). Its
advantage over office EMB ranged from $207.12 per patient in the low-cost locality (Arkansas) to
$270.95 in Colorado to $348.75 per patient in the high-cost locality (Manhattan) -- i.e., the
combined-arm cost advantage widened, rather than narrowed or reversed, at the high-cost extreme. The
national-locality estimate ($506.11 / $761.94 / $3,839.81 for combined / office / D&C) exactly
reproduced the base case, confirming the geographic-adjustment methodology introduces no distortion at
the reference locality.

### External validation

The model's inflation-adjustment methodology reproduced the expected ~1.53x multiplier when
cross-checked against Ladabaum et al.'s (2011) historical office-EMB cost anchor. Yi et al.'s (2018)
full decision-tree parameter set was extracted from the primary source but confirmed structurally
incomparable to this model's cost-only engine, which has no diagnostic-accuracy, prevalence, or
effectiveness machinery; no numerical reproduction was attempted or claimed. Munro et al.'s (2022)
office/ASC/OR hysteroscopy cost figures are retained as reference benchmarks but were not independently
reproduced by this model, which prices a structurally different procedure (Table 9).

---

## Note for the model owner: what this draft does not yet include

- **Table/figure numbering for the geographic and clinical-outcome sensitivity results.** These are
  currently referenced by description and filename (`tables/geographic_sensitivity_summary.csv`,
  `figures/figure6_geographic_sensitivity.jpeg`) rather than a formal manuscript table number, because
  `analysis/07_manuscript_outputs.R` has not yet been extended to include them in its numbered output.
  If you want them as, e.g., Table 10 and an explicit clinical-outcome summary table, I can extend that
  script.
- **STALE (superseded):** the two bullets that followed here described a not-yet-drafted Limitations
  section and Discussion. Both have since been drafted directly in `manuscript/manuscript.qmd`'s
  Discussion section (as of 2026-09-02, that section covers: the office-arm repeat-attempt structure's
  small, non-Lynch evidence base; the now-symmetric absence of an estimable delayed-neoplasia risk for
  *either* arm -- revised 2026-09-02 from an earlier, asymmetric "office-arm-only" framing once the
  office arm's old escalation-fraction mechanism was replaced; D&C's own unmodeled failure/escalation
  branch; the D&C adverse-event cost, partially monetized for perforation managed by laparoscopy, with
  laparotomy-involving management and severe hemorrhage still unmonetized; and general-population
  rather than Lynch-specific sensitivity/specificity data). This file's own dollar figures/percentages
  below were kept in sync with that manuscript through the 2026-09-02 office repeat-attempt wiring, but this
  particular planning note was not deleted at the time and should not be read as current status.
- All dollar figures and percentages above are exact values from the currently committed table files as
  of this draft (2026-08-31); PSA-derived figures (probabilistic sensitivity, clinical-outcome
  sensitivity) will shift slightly on any future unseeded re-run, since `run_probabilistic_sensitivity()`
  does not currently accept a fixed seed. Re-verify against the live tables before final submission.
