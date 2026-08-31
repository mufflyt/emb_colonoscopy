# NEWS

User-facing highlights. For the exhaustive technical log (every file added/changed/
fixed/removed), see [`CHANGELOG.md`](CHANGELOG.md).

## 2026-08-30 (the combined arm now includes a preop office visit -- base case moves)

**A scenario toggle became a confirmed clinical-practice decision.** The model previously assumed, by
default, that the combined strategy needs no separate preoperative office visit -- consent and risk
assessment were assumed folded into existing care. Per the model owner's own clinical practice
(Tyler Muffly, MD, Denver Health), that's not how the combined protocol actually works: it does
require a separate preop visit before the colonoscopy date. Flipped the toggle to `TRUE`, cleared its
provisional flag (this is a protocol decision, not a literature claim, so it gets the same
"structural" designation as the model's dollar-year convention rather than an evidence grade), and
added the office-visit cost ($88.76) to the combined arm.

This is an honest cost increase, not a correction of an error -- the combined arm's advantage over
office EMB narrows from 37.7% to 26.3%, and the minutes threshold tightens from ~13.8 to ~11.1
minutes (still within, but closer to the edge of, the observed 1-12 minute range from the literature).
Three tests were updated to match the new default, including one that now explicitly compares the
toggle both ways instead of quietly depending on which state happened to be the default.

## 2026-08-31 (Yi et al. 2018, finally read in full -- and it doesn't say what we needed it to)

**The top-priority validation target for months turned out not to be a validation target at all --
and that's a useful thing to know.** After the Wayback Machine's own outage blocked one access route,
the model owner logged into PubMed with institutional credentials and pulled the full Gynecologic
Oncology paper directly. It's a genuinely excellent decision-tree study, with every internal
parameter now documented in this repository -- but reading the actual Methods section revealed that
Yi et al.'s model measures something different from what this repository measures: they build in
diagnostic test accuracy, disease prevalence, downstream cancer-treatment costs, and life-expectancy
effectiveness, none of which this repository's cost-only engine implements. Plugging their numbers
into our formula would never have reproduced their $1,897.80/$2,999.11, no matter how carefully the
parameters were transcribed -- the two models answer related but genuinely different questions.

That's not a failed validation; it's real information about the scope of this repository's model,
obtained by actually reading the primary source instead of assuming compatibility from the abstract.
Two real, useful things came out of it anyway: two procedure-level cost anchors for a partial
cross-check (not a close match yet, reported honestly), and a second independent citation supporting
`office_to_dnc_escalation_fraction`'s 100% assumption (Yi's own model estimates 95% for a comparable,
non-Lynch population).

## 2026-08-30 (a placeholder gets real, if incomplete, grounding)

**`office_to_dnc_escalation_fraction`'s 100% assumption is no longer just an unfounded default.**
Searched for Lynch-specific data on how often a failed office EMB gets repeated in-office versus
escalated straight to D&C. The four candidate primary studies are all hard-paywalled with no free
full text anywhere -- confirmed, not just assumed. But a paper already used elsewhere in this model,
Nebgen et al. 2014 (MD Anderson's combined colonoscopy+EMB Lynch program), turns out to spell out its
own protocol in plain language: any EMB failure gets scheduled straight for hysteroscopy and D&C, no
repeat office visit. That's real, quotable, Lynch-specific support for the 100% assumption -- just
not from the exact population (it describes the combined arm's protocol, not standalone office EMB).
Updated the citation, moved this parameter up a tier, left the value and the provisional flag alone.
Base case unchanged.

## 2026-08-30 (a citation scare, resolved -- the numbers were right all along)

**Good news for once: a suspected error turned out not to be one.** While chasing a different lead,
a possible citation mix-up surfaced on `emb_failure_lynch` (already in the base case): two
similarly-titled 2009 papers on Lynch endometrial screening sit back-to-back in the same journal
issue, and the one credited with a "6/25" biopsy failure count has an abstract that never mentions
it. Checked directly against the systematic review's own data table, which states the number
verbatim, and against an independent third-party evidence report that separately extracted the same
paper's results -- both confirm the number is correct, just reported in the paper's results rather
than its abstract. No change to any value; the parameter's provenance notes now document the
verification so this doesn't need re-litigating later.

## 2026-08-29 (CPT 58558 mystery solved)

**A data-quality flag from earlier this session is now resolved.** `hysteroscopy_dc_professional_cost`
(CPT 58558, hysteroscopy + D&C -- not used in the base case, a reference value for a future comparator
arm) had two conflicting numbers on file: $204.41 and $1,269.90, suspected to be a
professional-only-vs.-professional-plus-facility mixup. A live CMS claims query, split by place of
service, found the real answer: facility = $796.75, nonfacility = $1,310.79. Neither original number
was right, but the mystery makes sense now -- the $1,269.90 citation was very close to the real
nonfacility rate, not a facility-inclusive bundle. Updated to the real facility-setting value
($796.75, matching this parameter's own definition) and cleared the provisional flag. The base case
itself doesn't change (this parameter isn't wired into any cost function yet), but the
provisional-parameter count drops to 5 of 41.

## 2026-08-28 (supply-cost double-count found and fixed; combined arm now uses the right facility rate)

**Two real problems, found the same way: check CMS's own primary data before trusting a shared
parameter.** `emb_office_professional_cost` (CPT 58100's professional fee) was being charged,
unmodified, to both the office_emb arm (correct -- it happens in the physician's office) and the
combined_emb arm (a setting mismatch -- that EMB happens in the facility/endoscopy suite where the
colonoscopy itself takes place). And `emb_disposable_supply_cost` -- a $35 unsourced placeholder --
was being summed into *both* arms alongside it.

CMS's own Direct Practice Expense Inputs file settled both questions at once: it itemizes the exact
supplies (including the Pipelle device itself) priced into CPT 58100's *nonfacility* rate, and shows
they are explicitly excluded from the *facility* rate. That confirmed the supply cost was
double-counted for office_emb, and pointed to the fix for combined_emb: a live CMS claims query found
the real facility rate ($60.05) is ~38% lower than the nonfacility rate ($97.03) for this code.
Removed the double-counted supply line from office_emb; added a new facility-rate parameter for
combined_emb; replaced the $35 supply placeholder with the real CMS-itemized total ($28.79, kept for
combined_emb only, since the facility rate doesn't price supplies in).

Net effect: combined EMB $486.01 (was $530.37), office EMB $780.23 (was $816.40), still 37.7% cheaper
than office EMB (was 35.0%). Provisional-parameter count dropped to 6 of 41 (was 7 of 40).

## 2026-08-28 (D&C arm now fully empirical)

**The D&C arm's headline finding no longer rests on any placeholder.** Filled the last two D&C-arm
gaps with real CMS data -- the preop visit ($125.40, CPT 99214, OB/GYN-specific claims) and, as a
bonus using the same query, the office-EMB visit cost too ($88.76, was an unverified $110 guess). But
the more important fix was a subtraction, not an addition: `dnc_recovery_room_cost` ($250) turned out
to already be included inside the facility fee sourced earlier this session -- CMS packages recovery
room/PACU time into the ASC/OPPS facility payment by design (confirmed via MedPAC's official payment
documentation) -- so charging it separately was double-counting. Removed it, with a new regression
test (mutation-tested) enforcing the exclusion going forward.

Net effect: every input behind "D&C is dominated by both alternatives even at $0 facility fee" is now
real, sourced data -- and, honestly, this fix *narrowed* the combined arm's advantage rather than
widening it (35.0% vs. 38.3% before), which is exactly what should happen when a real double-count
gets corrected rather than a real gap gets filled in a favorable direction. Base case: combined EMB
$530.37, office EMB $816.40, D&C $3,827.04.

## 2026-08-28 (real coordination-cost wage)

**Coordination cost is now half-real, half-asked.** The wage component of `coordination_cost` --
what a GYN and colorectal scheduler actually earn per hour -- is now a real BLS-sourced figure
($22.08/hr, via O*NET OnLine, since bls.gov itself blocks automated retrieval). The time component
(30 minutes per scheduler) came from asking the PI directly about real Denver Health workflow, rather
than guessing -- a genuinely different kind of "provisional" than an unfounded number, though still
flagged as such since it isn't independently published. Base value: $22.08, barely moving the
headline result (combined EMB $540.26 vs. $543.18 before).

## 2026-08-28 (real D&C anesthesia cost)

**A second D&C-arm placeholder replaced with real data.** `dnc_anesthesia_cost` -- previously a $400
guess -- is now the real CMS PUF-derived professional anesthesia cost for CPT 00952: $114.50, from
118 real provider-service rows. Notably, this real number is *lower* than the placeholder it
replaced, so fixing it made the D&C-dominance finding more conservative, not less. The D&C arm now
has only two remaining provisional components (down from four this morning). Base case: combined EMB
$543.18 vs. office EMB $875.26 vs. D&C $4,101.64 -- a 37.9% saving, holding up to ~14.9 minutes of
added colonoscopy-suite time.

## 2026-08-28 (real D&C facility fee)

**The largest placeholder in the model is now real data.** The D&C facility fee --
~75% of that strategy's total cost, and previously an unsourced $1,800 guess -- is
now the actual CMS hospital-outpatient (OPPS) payment for CPT 58120: $3,307.24,
pulled directly from the current CMS payment addenda. The base case updated
accordingly: combined EMB is now $553.45 per patient vs. $914.38 for office EMB and
$4,387.14 for D&C, a 39.5% saving (was 29.5%), remaining the cheapest strategy up to
~15.8 minutes of added colonoscopy-suite time -- comfortably covering the entire
observed 1-12 minute range from the literature, not just brushing its upper edge.

## 2026-08-28 (national colonoscopy-setting analysis)

**A new national feasibility analysis, complementary to the cost model.** Beyond
what EMB-with-colonoscopy costs, `analysis/08_colonoscopy_setting.R` asks a related
question at national scale: what share of U.S. Medicare colonoscopy-coded services
actually happen in facility settings (ASC or hospital outpatient) where a coordinated
sedated biopsy would be structurally possible? Verified against real 2019-2024 CMS
data during integration -- and this was the first externally-generated delivery this
session that needed no bug fixes after full live verification. See
[`docs/evidence_layers.md`](docs/evidence_layers.md).

## 2026-08-28 (public-input acquisition)

**Public inputs can now be acquired reproducibly.** `analysis/00_get_public_inputs.R`
downloads and validates the real 2024 MEPS files and draws a frozen, fixed-seed
120-hospital sample for the commercial-price layer, instead of requiring hand
downloads. Verified against live data during integration -- and along the way, two
more real bugs turned up (another instance of the data-masking bug from the entry
below, and a CMS column-naming mismatch that the author's own test had shared the
same wrong assumption with, so it never caught it). See
[`docs/evidence_layers.md`](docs/evidence_layers.md).

## 2026-08-28

**CI added.** Every push and pull request now runs the full test suite automatically
(`.github/workflows/r-tests.yml`); status badge is on the README.

**Public-data cost benchmarking added.** Beyond the literature-parameterized model,
`analysis/06_evidence_layers.R` can now pull live CMS Medicare physician-fee
benchmarks, hospital commercial price-transparency data, and MEPS patient-burden
data. See [`docs/evidence_layers.md`](docs/evidence_layers.md) -- including three
real bugs caught and fixed during review before any of it was trusted, and two
layers (claims linkage, CMS facility costs) that were deliberately not shipped
because the data or crosswalk needed to do them correctly isn't available yet.

**New reporting: probability of being cheapest, budget impact, evidence tiers.**
The probabilistic sensitivity analysis now reports what fraction of simulations each
strategy was the least expensive strategy, not just a mean cost difference. A new
budget-impact calculator scales per-patient savings to a health system's annual
patient volume. Every model parameter is now labeled with an evidence tier
(A = Lynch-specific direct data ... D = provisional placeholder) so it's clear at a
glance which conclusions rest on strong versus weak inputs.

**External validation, honestly scoped.** `R/literature_replication.R` can check
this model's engine against a published study's own parameters. Right now that's
used to cross-check the Ladabaum et al. 2011 cost anchor; two other candidate
studies (Yi et al. 2018, Havrilesky et al. 2009) are explicitly tracked as pending
because their internal parameters haven't been extracted yet -- this repository will
not fabricate parameters to fake a match against a known headline number.

**Manuscript tables.** `analysis/07_manuscript_outputs.R` generates all nine
manuscript-ready tables (parameters, cost components, strategy comparison, one-way
sensitivity, PSA summary, thresholds, budget impact, evidence tiers, validation
status) in one run.

## 2026-08-28 (initial release)

First working version: a cost-minimization model comparing standalone office
endometrial biopsy, operative D&C, and biopsy coordinated with an already-planned
surveillance colonoscopy for patients with Lynch syndrome. Base case, deterministic
and probabilistic sensitivity analysis, threshold analysis, and scenario analysis are
all runnable end to end (`analysis/01`-`05`), backed by a fully sourced,
literature-cited parameter table (`config/model_parameters.csv`) and a testthat
suite. See the [README](README.md) for the current base-case result and
[`docs/reuse_mapping.md`](docs/reuse_mapping.md) for what was adapted from the prior
`colpocleisis_costeff` model.
