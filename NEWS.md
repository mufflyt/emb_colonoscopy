# NEWS

User-facing highlights. For the exhaustive technical log (every file added/changed/
fixed/removed), see [`CHANGELOG.md`](CHANGELOG.md).

## 2026-08-31 (an outside audit against a checklist -- most of it already stood up)

Ran the manuscript against CHEERS 2022, the standard 28-item reporting checklist for health-economic
evaluations (the health-economics equivalent of CONSORT for trials). Two things came out of it.

First, a collaborator's audit had flagged Title, Abstract, and Discussion as missing -- they weren't;
that audit was against an older snapshot, from before the last update added them. Worth remembering:
an outside review is only as current as the file it actually looked at.

Second, underneath that, eight real gaps were genuinely there and got fixed: the study's perspective
needed to be stated more precisely (it blends Medicare reimbursement rates with separately-sourced
resource costs, which isn't quite the same thing as a pure payer perspective, and now says so), plus
explicit statements on time horizon, discounting, the study's outcome-selection logic, what
heterogeneity was and wasn't examined, and whether patients or other stakeholders were formally
engaged in building the model (they weren't, beyond clinician input on specific workflow assumptions --
now stated plainly rather than left implicit).

Two items are genuinely left for the corresponding author to complete, on purpose: funding source and
conflicts of interest. Those aren't something to guess at.

## 2026-08-31 (a first complete draft, and a diagram that had to be fixed before it was honest)

Filled in the two sections that were placeholders: Introduction and Discussion. Both are first-pass
drafts, not final -- the clinical framing needs a human's read -- but the manuscript now has all six
sections a submission needs.

Built the decision-tree diagram the journal's economic-evaluation checklist requires. First version
had a real error worth naming: it labeled a branch's outcome with the strategy's overall
probability-weighted average cost, not the actual dollar amount a patient on that specific branch would
incur. A diagram is supposed to make the model's logic easier to check at a glance -- one that quietly
mislabels its own numbers does the opposite. Fixed before it went anywhere.

Also tracked down the two references left unverified last time. Both checked out exactly as drafted --
and reading one of them again confirmed, as a nice side effect, that this project's own per-minute
operating-room cost parameters match the source paper's numbers precisely.

## 2026-08-31 (does this hold up outside the national average? yes -- and more so)

Every number in this model up to now has been a national Medicare average. That's a reasonable
starting point, but it leaves an obvious question unanswered: does "combined EMB is cheaper" survive
contact with an actual place, or is it an artifact of averaging?

Priced the same three strategies in four real locations -- the national average, Colorado, a
low-cost area (Arkansas), and a high-cost one (Manhattan) -- using real CMS geographic adjustment
data (the same kind of locality-specific rate tables Medicare itself uses to pay providers
differently by region). No guessed multipliers; every adjustment factor traces back to a downloaded
CMS file.

The answer: combined EMB won in all four places, and its margin over office EMB actually widened in
the high-cost location ($353 saved per patient) compared to the low-cost one ($210). The base case
isn't hiding a location-dependent flip -- if anything, the advantage gets stronger exactly where
health care costs more.

## 2026-08-31 (a line in the sand: analysis-v1.0)

Tagged `analysis-v1.0`. After a day of real corrections -- a degenerate PSA distribution, a missing
join, a delayed-neoplasia number that looked too clean, a denominator that quietly halved a key
probability -- this is the point to stop tweaking and let the numbers hold still for a moment. The
tag captures exactly what the model says right now, with every correction this session found already
folded in, before the next planned addition (geographic sensitivity) moves anything further.

## 2026-08-31 (a citation we'd already used turned out to have been misread -- half the model's key)

A collaborator asked us to double-check something before changing anything: was `combined_to_dnc_probability`
(2 out of 55 patients, 3.6%) actually measuring what the model uses it for? The model prices a single
office visit, not a patient's whole multi-year screening history -- so a rate describing "2 of 55
patients, ever" isn't the same quantity as "how often does one combined-screening visit end in a
rescue D&C."

Reading the original paper's own sentence settled it: "3.6%" sits right next to the paper's patient
demographics (age, race, parity), computed over its 55 patients -- while the paper's own per-visit
statistics elsewhere use its 111-visit count. Recomputed against that visit count, the same two events
are 1.8%, not 3.6%.

That's a real, meaningful change: it roughly halves the combined arm's expected rescue-D&C cost,
widening its advantage over office EMB from about 25% to 34% cheaper. Worth sitting with for a moment
-- this is exactly the kind of quiet unit-mismatch that's easy to miss on a first read and easy to
propagate for a long time once it's in a spreadsheet.

## 2026-08-31 (a clean result that turned out to be too clean, caught before it went anywhere)

Digging into the new clinical-outcome PSA numbers surfaced something that looked great at first
glance: combined EMB had no greater delayed-cancer/precancer risk than office EMB in 100% of 1,000
simulated draws. That's the kind of sentence that ends up in an abstract.

It shouldn't. The 100% wasn't a finding -- it was a mechanical certainty. The model currently has no
way for a failed combined-EMB attempt to go unresolved (unlike the office arm, which does model that
pathway), so its delayed-diagnosis rate is exactly zero in every single draw by construction, not by
evidence. Once that's true, "combined is cheaper AND no worse on this metric" collapses to exactly
"combined is cheaper" -- the same 69.3% wearing a second label, adding nothing.

Documented this plainly in the methods notes and data sources before it could get cited as a real
result. The genuine clinical-risk finding from the same analysis survives the scrutiny: combined EMB's
exposure to rescue-D&C-driven adverse events was no worse than office EMB's in 97.8% of draws --
notably not 100%, which is exactly what makes it a real comparison rather than a structural one. No
model code changed; this was a documentation-only pass, on purpose, so a genuinely uncertain question
doesn't quietly read as settled.

## 2026-08-31 (a second bug found the same way: run it, read the output, don't trust it)

Same lesson as the PSA distribution fix earlier today, one script over. Running the manuscript-tables
script and actually opening Table 5 -- rather than assuming it worked because the script exited
cleanly -- showed every "probability this strategy is cheapest" value as blank. A column-name mismatch
in a join meant those numbers were never being attached to the cost summary at all.

Fixed, and pulled into its own tested function so a future change to either side of that join can't
silently reintroduce the same gap. Also caught, while fixing it: a strategy that's never the cheapest
in a given PSA run (D&C, essentially always) was showing up as blank rather than a real zero -- which
matters, because "blank" and "zero times" mean very different things in a table someone might cite.

## 2026-08-31 (a real bug found by actually running the new analysis, not by reading the code)

The clinical-outcome extension described below was written, tested, and passing -- and then produced
exactly 0 for its headline metric across all 1,000 draws of a probabilistic sensitivity run. Not "0 at
the base case" (expected), but 0 in every single simulated draw, which shouldn't happen for a
parameter explicitly given a 0.5-1.0 uncertainty range.

The cause: `office_to_dnc_escalation_fraction` sits at exactly 1.0, and the model's generic
probability-sampling machinery uses a beta distribution, which mathematically cannot have a mean of
exactly 1.0 -- it was silently rounding down to 0.999999 and drawing values indistinguishable from the
fixed base case every time. Switching that one parameter to a triangular distribution (which handles
a boundary mode correctly) fixed it, and a new validation check now catches this pattern automatically
for any parameter, so it can't recur unnoticed.

Once the parameter could actually vary, both halves of the model moved together: combined EMB's
share of cost-saving simulations dropped from 81.4% to 69.3% (the earlier figure had been implicitly
assuming near-100% D&C rescue every time), and the delayed-neoplasia metric -- silent before -- now
shows a real distribution (median about 1.4 per 1,000 patients). That's the tradeoff this whole
extension was built to surface, and it only appeared once the sampling bug was fixed.

## 2026-08-31 (the model can now show its work on whether "equal effectiveness" is safe to assume)

**The single biggest scientific gap in this model has always been the same one:** it compares three
strategies purely on cost, on the assumption that an adequate sample means the same thing regardless
of which strategy obtained it. That assumption was stated plainly in the docs, but never tested. It
now can be.

`compute_strategy_clinical_outcomes()` asks a narrow, answerable question: given office EMB's known
higher failure rate, and given the current (conservative) assumption that 100% of failures get
rescued to D&C, how much of that risk would actually reach patients as a delayed cancer or precancer
diagnosis if that 100% assumption turns out to be optimistic? At the base case, the answer is zero by
construction -- which is itself informative, since it shows exactly how much weight that single
assumption is carrying. Dial the assumption down in a sensitivity run, and the model now produces a
real number instead of silence.

This runs alongside the existing probabilistic sensitivity analysis rather than as a separate
Monte Carlo exercise -- cost and clinical-outcome findings now come from the same simulated draws, so
a statement like "combined EMB was cheaper AND exposed fewer patients to D&C-driven complication risk
in the same simulations" is possible, not just two separately-true facts.

Fifteen new parameters back this: real D&C and hysteroscopy complication rates (uterine perforation,
hemorrhage, infection), and real Pipelle-vs-D&C diagnostic sensitivity figures from a 2023 meta-
analysis. One near-miss is worth flagging: an early literature summary for this round (sourced from an
AI web search) reported "office EMB failure" numbers that turned out to be the exact pre-correction
error already caught and fixed in `emb_failure_lynch` last week. Every citation in this round was
re-verified against the actual paper before being trusted, which is what caught it.

What this round explicitly did NOT do: invent dollar costs for any of these adverse events. Two real
but weak, doubly-borrowed cost figures from an unrelated cancer-treatment cost model are recorded as
clearly-flagged reference values, not wired into anything -- monetizing these properly is future work,
not a placeholder to paper over now.

## 2026-08-31 (a literature-mining round that mostly confirmed what we already had)

**Four candidate papers, one real addition.** Following up on the "next literature to mine" list,
we tracked down PDFs for Munro et al. 2022, the NIHR review's own cost tables, ONCE 2025 (plus its
misidentified "companion" citation), and a University of Florida hysteroscopy cost study. Most of
this confirmed rather than changed anything: Munro's full text matches the three numbers already in
the model exactly, and ONCE 2025's 42-minute combined-procedure time is consistent with the Huang
2011 estimate already driving `combined_emb_added_minutes` (just less precise, so it didn't replace
it). The NIHR review's own detailed cost tables turned out to be UK NHS tariffs bundling hysteroscopy
with ultrasound and CA-125 testing -- a different currency, payer system, and procedure bundle than
this US-CMS, EMB-specific model, so they're documented but not converted into parameters.

One real gain: the University of Florida study (Moawad et al. 2014) added a second, independent
office-vs-OR cost comparison ($1,356 vs. $4,946) alongside Munro's, as reference-only benchmarks.

One correction worth flagging: a citation for a "Weill Cornell implementation framework" paper that
appeared earlier in this project's literature list turned out to be unconfirmed -- extensive
searching never located a real paper matching it. The paper actually obtained instead, Ahsan et al.
2022, is a real Weill Cornell commentary, but a qualitative one with no cost or time figures to
extract. No base-case numbers changed this round.

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

## 2026-08-31 (reading the primary sources found two real errors in a trusted secondary review)

**A base-case parameter got corrected because someone finally read the original papers.**
`emb_failure_lynch` -- the pooled Lynch-specific EMB failure rate driving the office arm's escalation
probability -- had been verified twice already this session, but only against the NIHR systematic
review's own summary table and a third-party evidence report, never the four primary studies
themselves. With institutional full-text access finally in hand, both were checked directly, and the
review's table turned out to have two real errors: Elmasry 2009's true failure count is 5 out of 25,
not the 6/25 the review reported, and Rijcken 2003 -- despite being cited as a "Pipelle failure rate"
study -- actually used five different sampling methods, with the two failures the review counted
coming from hysteroscopy attempts, not Pipelle at all. The genuinely Pipelle-specific rate in that
study is a clean 0 out of 4.

Corrected the pooled estimate to use only the three studies now individually confirmed
Pipelle-specific (Elmasry corrected, Lecuru and Woolderink both checked out exactly as before):
13.7% moves to 13.3%. Small shift, real effect: office EMB's own cost ticks up slightly, narrowing
its margin against the combined strategy from 26.3% to 24.9%. The bigger point isn't the number --
it's that "matches the cited secondary source" and "is actually true" turned out to be two different
questions, and only reading the original papers could tell them apart.

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
