# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project does not use
semantic version numbers (there is no `DESCRIPTION`/package version), so entries are
grouped by date.

## 2026-09-02 (stated explicitly what NCCN does and doesn't specify)

### Changed
- `manuscript/manuscript.qmd`, Introduction: added "This guideline specifies timing and eligibility,
  not delivery method." right after the NCCN citation, making explicit that NCCN governs *when* to
  screen (interval, starting age) but takes no position on *how* to deliver the biopsy
  (standalone office visit vs. combined with colonoscopy vs. operative D&C as a fallback) -- the
  question this model exists to answer. Introduction now 241/250 words.

## 2026-09-02 (cited the current NCCN guideline in the Introduction)

### Added
- `manuscript/manuscript.qmd`: reference 16, National Comprehensive Cancer Network's *Genetic/Familial
  High-Risk Assessment: Colorectal, Endometrial, Esophageal, and Gastric Cancer* guideline, Version
  1.2026 (released June 16, 2026). Resolves a DRAFT comment flagged since the Introduction was first
  drafted ("cite current NCCN guideline version/year explicitly once confirmed"). The Introduction's
  surveillance sentence now states the specific recommendation (endometrial biopsy every 1-2 years
  beginning at age 30-35, alongside interval colonoscopy) rather than the vaguer "regular intervals
  beginning in the third or fourth decade of life." Verified via a genetic-counseling organization's
  professional summary of the guideline update and cross-checked against a January 2026 peer-reviewed
  review's independent description of the same Lynch-derived surveillance interval -- explicitly NOT a
  direct read of the primary NCCN PDF, which is gated behind a free-account login this session did not
  create; flagged in-file for a direct primary-source check before submission if institutional NCCN
  access is available.

## 2026-09-02 (office arm's escalation fraction replaced with a real repeat-attempt structure)

### Added
- `config/model_parameters.csv`: two new parameters -- `office_repeat_attempt_fraction` (5%, range
  0-6%, triangular, Yi et al. 2018's own decision-tree logic: the complement of their "P(moving to
  D&C if 1st attempted Pipelle failed) = 0.95") and `office_repeat_attempt_success_probability` (25%,
  exact binomial 95% CI 3.2%-65.1%, beta, from Adambekov et al. 2017's Table 1: 2 of 8 patients with a
  documented history of prior Pipelle failure succeeded on the attempt studied -- independently
  confirmed as the exact subgroup Yi et al. 2018 cite for the identical purpose in their own methods
  text, not merely a similar number from a different source).

### Changed
- `R/strategy_costs.R::compute_office_emb_strategy_cost()`: replaced the single-parameter
  `office_to_dnc_escalation_fraction` (fixed at 100%, i.e. every failure assumed to escalate straight
  to D&C) with the two-parameter repeat-attempt structure above. On failure: either a repeat office
  visit (5% of failures, costing the same $255.93 as the initial visit since it bills as an
  established-patient encounter) that succeeds 25% of the time, or direct escalation to D&C. New
  return fields `repeat_attempt_probability`/`repeat_visit_cost`.
- `R/diagnostic_yield.R::compute_strategy_clinical_outcomes()`: `office_unresolved_probability` is now
  hardcoded to 0, not derived from `office_to_dnc_escalation_fraction`. Yi et al. 2018's own decision
  tree has no branch where a failed repeat attempt is left unresolved ("the physician will then move
  to the D&C route"), so `office_neoplasia_delayed_probability` is 0 in every draw now, matching the
  combined arm -- **this eliminates what was previously an asymmetric finding** (office arm: mean 1.55
  delayed-neoplasia events per 1,000 in the prior run; combined arm: always 0 "by construction"). Both
  arms are now 0.00 for the same structural reason: a genuine null result under current evidence, not
  proof either arm's true risk is zero -- see `docs/methods_notes.md`'s "Interpretation of
  delayed-neoplasia outcomes" for the full account.
- `R/diagnostic_yield.R::compute_diagnostic_yield()`: added a `office_repeat_success_probability`
  detection-probability branch (a successful repeat attempt is still detected at
  `office_sensitivity`, not `dnc_sensitivity`) -- this branch did not exist before.
- `office_to_dnc_escalation_fraction`: marked SUPERSEDED in its own notes and recategorized to
  `reference_only` (no longer consumed by any function); retained in the parameter table as a
  historical record rather than deleted, per this project's convention.
- Updated `tests/testthat/test-strategy-costs.R`, `test-independent-confirmation.R`, and
  `test-diagnostic-yield.R` for the new structure; replaced two tests that specifically exercised the
  old escalation-fraction mechanism (a monotonicity test and an independent-confirmation test, both
  built around "lower escalation fraction -> nonzero delayed-neoplasia") with equivalent tests for the
  new mechanism. Mutation-tested: (1) zeroed `repeat_attempt_probability`/`repeat_visit_cost`,
  confirmed the expected test failures, restored; (2) reintroduced a nonzero
  `office_unresolved_probability`, confirmed all four affected assertions failed with the expected
  signature, restored.
- Regenerated the entire analysis pipeline and re-synced every changed number across
  `manuscript/manuscript.qmd` (Abstract, Methods -- added reference 15 for Adambekov et al. 2017 --
  Results, and a substantially rewritten Discussion "principal limitation" paragraph reflecting the
  now-symmetric null result instead of an office-arm-specific one), `manuscript/cheers_checklist.qmd`,
  `docs/manuscript_methods_results.md`, `docs/methods_notes.md` (rewrote "Interpretation of
  delayed-neoplasia outcomes" and "Two escalation probabilities" sections), `docs/data_sources.md`,
  `docs/CHEERS_2022_checklist.md`, and `README.md` (new "Office repeat-attempt structure" section):
  base case ($506.11/$761.94/$3,839.81, office arm cheaper by $4.68 from the prior run), one-way
  sensitivity ranges, thresholds (12.7 min, 6.6% failure, $278 coordination cost), budget impact,
  geographic sensitivity ($207.12-$348.75), and PSA (90.5% cheapest, up from 81.4% -- office EMB's PSA
  mean cost rose substantially, from $759.34 vs. the prior $683.44, because the old
  `office_to_dnc_escalation_fraction`'s wide `triangular(0.5, 1, 1)` distribution let PSA draws cut
  escalation probability by up to half, while the new structure's maximum reduction is under 4% even
  at its 95% CI bounds -- a narrower, better-disciplined range, not a bug).
- Flagged (not fixed, out of scope for this change): references 12 (Yi et al. 2018) and 15 (Adambekov
  et al. 2017) are now cited in the Methods "Clinical probabilities" paragraph before their
  validation-paragraph/first-numbered-list appearance later in Methods, adding to the pre-existing
  reference-6-before-references-1-5 citation-ordering issue already flagged 2026-09-01.

## 2026-09-01 (wired the sourced portion of the AE-cost evidence table into compute_dnc_strategy_cost())

### Added
- `config/model_parameters.csv`: four new parameters --
  `dnc_perforation_management_observation_fraction` (0.4423, exact binomial 95% CI 0.3047-0.5867),
  `dnc_perforation_management_laparoscopy_only_fraction` (0.2115, CI 0.1106-0.347), both from
  Ben-Baruch et al. 1982 (PMID 6212675); `dnc_perforation_laparoscopy_professional_cost` ($316.30,
  CPT 49320 professional fee) and `dnc_perforation_laparoscopy_facility_cost` ($6,176, CPT 49320 OPPS
  facility fee), both from the live CY2026 CMS RVU26C/OPPS Addendum B files. `dnc_perforation_probability`
  recategorized from `future_extension` to `probability`/`dnc` since it is now actually consumed by a
  cost function.

### Changed
- `R/strategy_costs.R::compute_dnc_strategy_cost()`: now includes an
  `adverse_event_cost_partial_perforation_only` component = `dnc_perforation_probability x
  [P(observation)x$0 + P(laparoscopy-only)x(laparoscopy professional + facility fee)]`, per
  `docs/ae_cost_evidence_table.md`. Deliberately a lower-bound partial estimate: immediate laparotomy,
  laparoscopy-converted-to-laparotomy, the unspecified 5.8%, and severe hemorrhage are excluded,
  because CPT 49000 (laparotomy) carries OPPS status indicator C (inpatient-only, no facility rate) and
  no hemorrhage management-pathway source was found. Raised D&C's base-case cost from $3,827.04 to
  $3,839.81 (+$12.77), with a small pass-through increase to the office ($764.93 -> $766.62) and
  combined ($505.88 -> $506.11) arms via their escalation-cost terms. Added
  `tests/testthat/test-strategy-costs.R::"D&C arm includes a partial adverse-event cost..."` and updated
  `tests/testthat/test-independent-confirmation.R` to re-derive the new component via its own arithmetic.
  Mutation-tested: hardcoded the component to 0, confirmed both tests failed with the exact expected
  cascade (D&C's own $12.77, office's $1.70, combined's $0.23), restored, confirmed green.
- Regenerated the entire analysis pipeline (`analysis/01` through `12`) and re-synced every changed
  number across `manuscript/manuscript.qmd` (Abstract, Methods, Results, Discussion, References --
  added reference 14 for Ben-Baruch et al. 1982), `manuscript/cheers_checklist.qmd`,
  `docs/manuscript_methods_results.md`, `docs/methods_notes.md`, `docs/data_sources.md`, and
  `README.md`: base case ($506.11/$766.62/$3,839.81), one-way sensitivity ranges, thresholds
  (12.8 min, $283 coordination cost), budget impact, geographic sensitivity ($211.24-$354.61), and PSA
  (81.4% cheapest, mean costs $540.65/$683.44, AE means 0.36/2.15/19.18, delayed-neoplasia 1.55).
  Total parameter count is now 66 (was 62); evidence-tier and provisional-parameter counts in
  README.md and docs/manuscript_methods_results.md updated accordingly (still 7 of 66 provisional).
  Discussion's adverse-event-cost limitation sentence rewritten to describe what is now partially
  monetized versus what remains excluded and why, rather than stating nothing was monetized.
- `docs/ae_cost_evidence_table.md`: status section updated from "not wired in" to "partially wired in,"
  with the exact before/after cost impact.
- Flagged (not fixed, out of scope for this change): a pre-existing citation-ordering issue in
  `manuscript/manuscript.qmd` -- reference 6 (CMS PFS) is cited in Methods before references 1-5 first
  appear later in the same section, predating today's changes. Documented in a comment for a dedicated
  fix before submission.

## 2026-09-01 (seeded the PSA for reproducibility; built an AE-cost evidence table, not yet wired in)

### Added
- `R/sensitivity_probabilistic.R::run_probabilistic_sensitivity()`: new `seed` parameter, default
  `20260901`. The RNG state is saved before seeding and restored on exit (via `on.exit()`), so calling
  this function no longer affects unrelated random draws elsewhere in the caller's session. Pass
  `seed = NULL` for a genuinely unseeded run. This closes the root cause behind two prior real bugs
  where a manuscript quoted PSA statistics from one run and clinical-outcome statistics from a
  different run (see the "Draft Methods and Results sections" and CHEERS-checklist entries above):
  `analysis/03_probabilistic_sensitivity.R` and `analysis/07_manuscript_outputs.R` both call
  `run_probabilistic_sensitivity()` independently against the same `config/model_parameters.csv` and
  `n_simulations = 1000`, and now produce byte-identical draws. Regenerated every PSA-dependent
  artifact under the new seed and re-synced every number that changed (manuscript.qmd's Abstract and
  Results, cheers_checklist.qmd, docs/manuscript_methods_results.md, README.md, the independent
  verification script's output, figure4): 82.0% -> 82.3% cheapest, mean costs $536.50/$678.20 ->
  $537.34/$676.60, AE means 0.34/2.11/19.16 -> 0.36/2.12/19.21, delayed-neoplasia mean 1.52 -> 1.54.
  Added `tests/testthat/test-parameters.R` tests: identical seeds give identical draws, different
  seeds give different draws, `seed = NULL` gives different draws each call, and the RNG state is not
  leaked to the caller. Mutation-tested (removed the seeding block; both reproducibility tests and the
  RNG-leak test correctly failed; restored, confirmed green).
- `docs/ae_cost_evidence_table.md` and `tables/ae_cost_evidence_table.csv`: a management-pathway-based
  adverse-event costing evidence table for `dnc_perforation_probability` and
  `dnc_severe_hemorrhage_probability`, per explicit instruction not to insert a single generic
  "$X per event" placeholder. For perforation: verified Hefler et al. 2009's abstract directly (no
  management detail in that paper); found and verified a distinct, later paper by an overlapping
  author group -- Ben-Baruch, Menczer, Frenkel, Serr, "Laparoscopy in the management of uterine
  perforation," J Reprod Med 1982;27(2):73-76 (PMID 6212675) -- reporting a management-state
  distribution across 52 curettage perforations (44.2% observation, 21.2% laparoscopy-only, 15.4%
  immediate laparotomy, 13.5% laparoscopy converted to laparotomy, 5.8% unspecified in the abstract).
  Sourced CY2026 CMS costs for the two procedure codes involved: CPT 49320 (diagnostic laparoscopy)
  professional fee $316.30 (RVU26C) + OPPS facility fee $6,176 (Addendum B, APC 5361) = fully sourced;
  CPT 49000 (exploratory laparotomy) professional fee $728.81, but its facility component is
  UNSOURCEABLE -- confirmed directly that CPT 49000 carries OPPS status indicator C (inpatient-only,
  no APC/payment) and is absent from the ASC Addendum AA, meaning laparotomy-involving management
  states are only partially costed (professional fee only) pending an MS-DRG inpatient-costing
  methodology this repository does not have. Independently verified an external plausibility check
  (PMC10776262, a US commercial-claims IUD study: 4.5 perforation-management events per 100 enrolled,
  $31 mean cost per enrolled individual, implying ~$689/event) and explicitly did NOT use it as a
  base-case value, per instruction -- population/mechanism differ, and the ~9x gap versus the
  CMS-priced total is itself informative (flagged in the evidence table). For hemorrhage: the event
  probability is already sourced (Hefler et al. 2009); no management-pathway source (transfusion rate,
  etc.) was located this session (a targeted search was interrupted by a bot-check), so it remains
  entirely unmonetized, exactly per instruction not to substitute obstetric/peripartum hemorrhage cost
  literature for a different clinical event. **Not wired into `compute_dnc_strategy_cost()` or any
  other cost function** -- per instruction, only once every nonzero term has a traceable source.
  Cross-referenced from `dnc_perforation_probability`'s and `dnc_severe_hemorrhage_probability`'s
  notes in `config/model_parameters.csv`.
- `articles/cms_source_data/`: consolidated every CMS source package referenced this session
  (RVU26C, OPPS Addendum B, ASC Addendum AA, FY2026 IPPS wage tables, CMS-1832-F Direct PE Inputs) out
  of scratch/temp locations into the repository's local (gitignored) reference-materials folder,
  alongside the literature PDFs already organized there.

## 2026-09-01 (assessed Adambekov et al. 2017 for relevance; cited as corroborating context, not wired in)

### Added
- `config/model_parameters.csv`: `emb_failure_lynch`'s notes field now cites Adambekov et al. 2017
  (Gynecol Oncol 144:324-328, PMID 27913154) as corroborating context. Read in full: a general
  (non-Lynch) retrospective cohort of 201 women, overall Pipelle failure rate 46/201 = 22.89%. Not
  used to change the base value -- tier C (general population) relative to the tier-A Lynch-specific
  pool -- but cited because Adambekov's own introduction places the general Pipelle-failure
  literature at 8%-33% (meta-analytic estimates 8-10.4%, individual studies up to 33%), and this
  model's 13.3% Lynch-specific rate sits comfortably within that range, closer to the meta-analytic
  end. Also checked and confirmed NOT relevant to `office_to_dnc_escalation_fraction`: the paper
  reports predictors of Pipelle failure (postmenopausal bleeding OR 7.41, prior failure OR 23.87,
  non-physician provider OR 9.15) but nothing about the post-failure pathway (repeat attempt vs.
  D&C), so it has no bearing on that parameter despite the surface-level topical overlap.
- `docs/data_sources.md`: new "Corroborating (non-Lynch) context for `emb_failure_lynch`: Adambekov
  et al. 2017" section with the full relevance assessment (what it does and doesn't support, and
  why). Regenerated `tables/manuscript_table1_parameters.csv` to pick up the updated notes field.

## 2026-09-01 (fixed title/precis over the journal's character/word limits; verified abstract has no limit)

### Fixed
- `manuscript/manuscript.qmd`, `manuscript/title_page.qmd`, `manuscript/cheers_checklist.qmd`: the
  title was 109 characters against the journal's 100-character limit -- dropped the
  ": A Decision-Analytic Model" suffix (82 characters now); the Abstract's Objective already names
  all three compared strategies, so the title doesn't need to. The précis was 29 words against the
  25-word limit -- trimmed to exactly 25 while keeping both the "already-scheduled colonoscopy"
  framing and the "range of assumptions and locations" robustness claim. Neither had actually been
  counted before now; both were previously flagged `[DRAFT, count words/characters before
  finalizing]` rather than verified.

### Verified (no code/content change needed)
- Abstract word count (301 words): fetched the live Instructions for Authors directly and confirmed
  Original Research's "1) Abstract" section states only the structural requirement (headings
  Objective/Methods/Results/Conclusion[/Funding Source]) -- no numeric word limit is given anywhere
  on the page for the abstract itself. Resolves the uncertainty the manuscript's own comment had
  flagged ("some LWW journals cap structured abstracts at 300-350 words").
- Discovered a real, previously-undocumented constraint on the same fetch: "The Introduction should
  not exceed 250 words; the Discussion should not exceed 750 words" (a sub-limit within the overall
  3,000-word body cap). Current draft: Introduction 234 words, Discussion 673 words -- both already
  compliant. Documented in the manuscript's top comment block so a future edit doesn't silently
  cross it.
- Body text (Introduction+Methods+Results+Discussion): 2,517 / 3,000 words. Short running title:
  33 / 45 characters. References: 13 / 30. All within limits, no change needed.

## 2026-09-01 (fixed three Inf/NaN guard gaps found by review; all mutation-tested)

### Fixed
- `R/sensitivity_probabilistic.R::sample_triangular()`: added an early return of `mode_value` when
  `min_value == max_value`. A degenerate triangular range (`low_value == high_value`) is explicitly
  allowed by `validate_model_parameters()` (same design as an allowed degenerate beta/gamma range,
  see `test-validation.R`'s "allows a beta row ... when low_value == high_value"), but unlike beta/
  gamma -- which already fall back to `base_value` via `draw_parameter_sample()`'s
  `approx_sd <= 0` check -- `sample_triangular()` had no equivalent guard: `(mode_value -
  min_value)/(max_value - min_value)` evaluated to `0/0 = NaN`, and `if (uniform_draw < NaN)` throws
  "missing value where TRUE/FALSE needed" instead of gracefully returning the fixed value. No
  currently-configured `triangular` parameter is degenerate today (checked both:
  `combined_emb_added_minutes` and `office_to_dnc_escalation_fraction`), so this was latent, not live.
- `R/inflation.R::adjust_for_inflation()`: added finiteness/positivity checks on `source_index` and
  `reference_index` before dividing, mirroring the equivalent guards already present in
  `R/geographic_sensitivity.R` (`national_rvu <= 0`, `wage_index <= 0`). Previously a `0`, negative,
  or non-finite `index_value` in the price-index table would have silently produced `Inf`/`-Inf`/`NaN`
  costs rather than erroring. Not live with the current `data/cpi_medical_care.csv` values (388.436/
  431.9/593.781), but a future edit or corrupted CSV could have hit it silently.
- `R/comparison.R`: `compare_combined_vs_office()` and `build_pairwise_comparison_table()` now guard
  their percent-difference divisions (`office_cost == 0` / `cost_b == 0` -> `NA_real_`), matching the
  guard `compare_strategies_to_cheapest()` already had for the structurally identical
  `cheapest_cost == 0` case in the same file. Not reachable with real strategy costs today (no
  strategy's `expected_total_cost` is ever exactly `$0`), but the three sibling functions are now
  consistently guarded instead of one of the three being silently unsafe.

All three fixes were mutation-tested per `docs/testing_philosophy.md` Rule 1 (temporarily reverted
each guard, confirmed the new test failed with the exact expected failure signature, restored the
fix, confirmed green) -- see the updated log table there. New tests added to `test-parameters.R`,
`test-inflation.R`, and `test-comparison.R`. Found during a code review covering statistical/code
correctness and numeric provenance (see conversation); none of the three were live bugs against
current data, all three were real robustness gaps against future/corrupted input.

## 2026-08-31 (fixed broken CI: workflow's hardcoded package list drifted from required_packages)

### Fixed
- `.github/workflows/r-tests.yml`: CI had been failing on `main` for the last two pushes
  ("Required packages not installed: DiagrammeR, DiagrammeRsvg, rsvg") because the workflow's
  `Install R package dependencies` step hardcodes its own package list rather than reading
  `R/00_source_all.R`'s `required_packages`, and that list was never updated when `openssl`
  (evidence-layer work) and `DiagrammeR`/`DiagrammeRsvg`/`rsvg` (decision-tree figure work) were
  added there. Local `Rscript tests/testthat.R` runs never caught this because the local R library
  already had those packages installed from working on the features that needed them. Added all
  four missing packages to the workflow's list; the two now match.

## 2026-08-31 (README refresh, independent PSA verification script formalized, appendix updates)

### Added
- `analysis/12_independent_psa_verification.R`: formalizes, as a repository artifact, the
  independent re-derivation of the manuscript's PSA-derived clinical-outcome claims (82.0%
  probability combined EMB is cheaper; 0.34-vs-2.11-per-1,000 adverse-event exposure; 100%
  no-worse-delayed-neoplasia-risk claim). Reads only `tables/probabilistic_sensitivity_draws.csv`
  using base R; never sources `R/00_source_all.R` and never calls
  `compute_strategy_clinical_outcomes()` or `run_probabilistic_sensitivity()`, per the
  independent-confirmation meta-rule (`docs/testing_philosophy.md`, Rule 2). This check had
  previously been performed ad hoc in a scratch location and not preserved; re-running it against
  the current `tables/probabilistic_sensitivity_draws.csv` reproduced every manuscript number
  exactly, with 0/1,000 mismatches on the cheapest-strategy sanity cross-check.
- `docs/appendix.md`: new "Independent PSA verification script" section and new "Raw CMS source
  files (not committed)" section inventorying the RVU26C, FY2026 IPPS wage-index, and
  CMS-1832-F Direct PE Inputs packages consulted while building the geographic-sensitivity and
  Direct-PE-sourced parameters, with the reasoning for not vendoring the raw multi-megabyte CMS
  packages into the repository (already distilled into `data/cms_geographic_indices_2026.csv`,
  `data/cms_pfs_rvus_2026.csv`, and individually cited parameter values; re-downloadable from the
  URLs already in `docs/data_sources.md`).
- `docs/testing_philosophy.md`: cross-referenced `analysis/12_independent_psa_verification.R`
  under Rule 2 as the manuscript-level application of the independent-confirmation pattern,
  alongside the existing `test-independent-confirmation.R` test-level application.

### Changed
- `README.md`: fixed a stale base-case blockquote left over from before the
  `combined_to_dnc_probability` denominator correction (2/55 to 2/111, see the "corrected
  combined_to_dnc_probability's denominator" entry below) -- it still read "$574.77 per
  patient... $190.16 less... 24.9%... 10.7 minutes," which no
  longer matched either the live model output or the manuscript's Results text. Re-ran
  `analysis/01_base_case.R` and confirmed the correct current numbers ($505.88, $259.04, 33.9%,
  12.7 minutes) match `tables/summary_sentence.txt` and `manuscript/manuscript.qmd`'s Results
  paragraph exactly. Added three more embedded figures (decision tree, PSA incremental-cost
  histogram, geographic sensitivity), a new "Independent verification" section, a new "Manuscript
  and reporting" section (this file had never mentioned `manuscript/`, the Green Journal format,
  or the CHEERS checklist despite that work already being complete), updated the repository
  structure diagram and quick-start commands for `analysis/09`-`12`, and aligned the "Perspective
  and extending this model" section's language with the CHEERS-fixed "U.S. healthcare-sector
  perspective" phrasing used in the manuscript.

## 2026-08-31 (CHEERS checklist: quote the proving sentence for each item, not just the section)

### Changed
- `manuscript/cheers_checklist.qmd`: the far-right column ("Reported in section") previously named only
  a manuscript section (e.g., "Methods"), which required a reviewer to search the text to confirm each
  item was actually satisfied. Replaced with the actual verbatim sentence(s) from `manuscript.qmd` (or
  `title_page.qmd` for items 27-28, funding/conflicts of interest) that satisfy each of the 28 CHEERS
  2022 items, so the checklist is independently verifiable without cross-referencing the manuscript.
  Items 27-28 quote the title page's placeholder disclosure fields and explicitly state no sentence can
  yet be marked satisfied, since the author has not supplied the actual funding/COI content.
- `docs/CHEERS_2022_checklist.md`: added a pointer noting the submission-ready file now carries the
  verbatim proving text; left this internal working document's "Where addressed" column as section
  names only, to keep it short.

## 2026-08-31 (CHEERS 2022 checklist audit; fixed 8 real reporting gaps in Methods)

### Added
- `docs/CHEERS_2022_checklist.md`: detailed internal audit of all 28 CHEERS 2022 items against the
  current manuscript, with specific manuscript-section citations and reasoning for each determination.
  Explicitly follows ISPOR's own guidance that CHEERS is a reporting-completeness checklist, not a
  methodological quality score. Supersedes an earlier stale audit performed by a collaborator against
  a prior manuscript snapshot (before Title, Abstract, Introduction, Discussion, and the decision-tree
  figure existed) -- several items that audit marked "Missing" were already "Reported" once checked
  against the live file.
- `manuscript/cheers_checklist.qmd`: the clean, submission-ready version of the same checklist,
  intended as Supplemental Digital Content (the format most economic-evaluation journals request).
  Renders to `cheers_checklist.docx`.

### Changed
- `manuscript/manuscript.qmd`'s Methods section: fixed 8 real, substantive CHEERS reporting gaps
  identified by the audit (not just manuscript polish):
  - **Perspective (item 8):** revised from "U.S. health-system/payer perspective" to an explicit
    "U.S. healthcare-sector perspective," distinguishing Medicare-reimbursement-valued inputs from
    resource-cost-valued inputs (incremental room/anesthesia time, coordination labor) that Medicare
    does not separately reimburse, and explicitly excluding patient time/transportation/productivity
    costs. The prior framing risked implying every dollar in the model was a Medicare payer
    expenditure, which is not accurate.
  - **Time horizon and discount rate (items 9-10):** added an explicit statement (single surveillance
    episode through any rescue D&C; not discounted, horizon <1 year).
  - **Health economic analysis plan (item 4):** added an explicit statement that none was
    prespecified.
  - **Outcome selection and valuation (items 11, 13):** added explicit rationale for the primary
    outcome and the two secondary outcomes, and an explicit statement that secondary outcomes were
    not converted to utilities or dollars.
  - **Heterogeneity and distributional effects (items 18-19):** added explicit statements that only
    setting-level (geographic) heterogeneity was characterized, not patient-level heterogeneity, and
    that distributional/equity effects were outside scope.
  - **Patient/stakeholder engagement (items 21, 25):** added an explicit statement that no formal
    engagement process occurred, naming the specific structural assumption (the combined arm's
    preoperative visit) that clinician-investigator input did affect.
  - **Study population (item 5):** refined to explicitly state which patient characteristics are not
    modeled as subgroups.
  - A pointer to the CHEERS checklist as Supplemental Digital Content was added to the end of Methods.
  - Word count after all additions: 2,517 of the journal's 3,000-word limit.

### Audit result
26 of 28 CHEERS items are now reported in the manuscript. The remaining 2 (funding source, conflicts
of interest) have their reporting structure already in place on the title page but require the
author's actual disclosure content -- not something an AI assistant should state on an author's
behalf.

## 2026-08-31 (manuscript submission materials: Introduction, Discussion, decision-tree figure, finalized figures/tables, verified references)

### Added
- Full Introduction and Discussion sections drafted in `manuscript/manuscript.qmd` (previously
  placeholders). Both flagged as a reasonable first-pass draft pending the author's clinical/policy
  framing, not asserted as final.
- `analysis/10_decision_tree_figure.R`: builds `figures/figure7_decision_tree.png`, a schematic
  decision-tree diagram (Graphviz via `DiagrammeR`) satisfying CHEERS item 15, with every probability
  and dollar value pulled live from `compute_strategy_costs()`. An initial version conflated
  path-specific terminal costs with strategy-level expected costs; caught and corrected (terminal
  nodes now show `initial_cost + dnc_cost` for escalation paths, not the overall expected total, which
  is instead annotated at the chance node).
- `analysis/11_manuscript_table10_summary.R`: builds `tables/manuscript_table10_summary.csv`,
  combining base-case cost with PSA-derived clinical-outcome means. Deliberately reads the
  already-saved PSA draws file rather than re-running `run_probabilistic_sensitivity()`, to avoid
  reintroducing the same-document numeric inconsistency already caught once while drafting the earlier
  Methods/Results document.
- `DiagrammeR`, `DiagrammeRsvg`, `rsvg` added to `R/00_source_all.R`'s `required_packages`.
- Figure/table selection finalized at 5 of 5 slots (Original Research's combined limit): 2 tables
  (parameters/assumptions; base-case + clinical-outcome summary) + 3 figures (decision tree, PSA,
  geographic sensitivity). Remaining analyses proposed for Supplemental Digital Content.
- Both flagged `[VERIFY]` references independently confirmed against primary sources: Ladabaum et al.
  2011 (Ann Intern Med 155(2):69-79, exactly as drafted) and Childers/Maggard-Gibbons 2018 (JAMA Surg
  153(4):e176233, exactly as drafted) -- the latter's primary-source read also cross-validated this
  repository's own `direct_room_cost_per_minute`/`procedure_room_cost_per_minute` parameters against
  the abstract's reported figures.

## 2026-08-31 (geographic sensitivity analysis, post analysis-v1.0 tag)

### Added
- `R/geographic_sensitivity.R` (new file): `compute_pfs_geographic_multiplier()` (RVU-weighted GPCI
  multiplier), `compute_facility_geographic_multiplier()` (labor-share-weighted OPPS wage-index
  multiplier), `validate_geographic_inputs()`, `build_geographic_overrides()`,
  `run_geographic_sensitivity()`, `summarize_geographic_sensitivity()`, `save_geographic_sensitivity()`.
  A thin layer around the existing `override_model_parameters()` + `compute_strategy_costs()`, not a
  new cost engine. Deliberately deterministic, not part of `run_probabilistic_sensitivity()`.
- `data/cms_geographic_indices_2026.csv` and `data/cms_pfs_rvus_2026.csv`: real CMS data for 4
  localities (national, Colorado, low-cost [Arkansas], high-cost [Manhattan]) -- GPCI from
  `GPCI2026.csv` (RVU26C package), RVUs from `PPRRVU2026_Jul_nonQPP.csv` (same package), OPPS wage
  index from the FY2026 IPPS Final Rule Table 3, OPPS labor-related share (0.60) verified directly
  from the Federal Register CY2026 OPPS/ASC final rule (document 2025-20907). No value invented; see
  `docs/data_sources.md`'s new "Geographic sensitivity analysis" section for every citation and a
  disclosed limitation (physician GPCI locality and hospital OPPS wage-index geography are different
  CMS systems without a shared geographic unit).
- `analysis/09_geographic_sensitivity.R`: runs the analysis, saves
  `tables/geographic_strategy_costs.csv`, `tables/geographic_adjustment_audit.csv`,
  `tables/geographic_sensitivity_summary.csv`, and `figures/figure6_geographic_sensitivity.jpeg`.
- `tests/testthat/test-geographic-sensitivity.R`: unit tests for both multiplier functions and the
  validation guards, plus an INDEPENDENT-CONFIRMATION-flavored test that the real, shipped CMS
  locality/RVU tables reproduce `compute_strategy_costs()`'s base-case output exactly at the
  `national` locality (all GPCIs/wage index = 1.0 by construction). Two mutation-tested defect pairs
  logged in `docs/testing_philosophy.md`.
- The raw CMS RVU26C package and the FY2026 IPPS wage-index tables were also archived to
  `~/Dropbox/emb_colonoscopy_cms_reference/` (not part of this git repo) and loaded into a DuckDB
  database (`cms_reference.duckdb`, tables `gpci_2026` and `pprrvu_2026_jul`) at the user's request,
  for reuse outside this repository.

### Result
- Combined EMB remained the least expensive strategy in all 4 of 4 localities tested. Combined-vs-
  office savings ranged from $209.77 (Arkansas, low-cost) to $353.14 (Manhattan, high-cost) per
  patient -- the base case's qualitative conclusion strengthens, not weakens, at the high-cost extreme.

## 2026-08-31 (tagged analysis-v1.0)

Tagged `analysis-v1.0` (annotated, pushed) at this commit -- the frozen base case ($505.88 combined
EMB / $764.93 office EMB / $3,827.04 D&C, 33.9% margin, ~12.7-minute threshold) after every
primary-source-verified correction from this session's literature-mining and audit work. Full test
suite green (406 assertions). Marks a deliberate stopping point before geographic sensitivity, the
next planned addition, so the tagged snapshot stays unambiguous. See the tag message for the full
list of what's frozen and what remaining gaps require new evidence rather than more engineering.

## 2026-08-31 (corrected combined_to_dnc_probability's denominator: 2/55 -> 2/111; base case changes)

### Changed
- `combined_to_dnc_probability` corrected from 3.6% (2/55, patient-level) to 1.8% (2/111,
  per-encounter), after a collaborator flagged the possible mismatch and it was audited directly
  against Nebgen et al. 2014's primary text before changing anything (per this project's
  independent-confirmation meta-rule). Confirmed: "Two women (3.6%) had cervical stenosis..." sits
  among unambiguously patient-level percentages in the paper's Demographics section (2/55 = 3.636%,
  matching "3.6%" exactly; the same paper uses its 111-visit denominator explicitly elsewhere, for
  encounter-level rates). `compute_combined_emb_strategy_cost()` consumes this parameter as a
  per-encounter escalation probability, so the patient-level prevalence was the wrong denominator.
  `low_value`/`high_value` also updated to the exact binomial 95% CI for 2/111 (0.0022-0.0636),
  replacing an unsourced 0.01-0.10 band.
- Base case: combined EMB **$505.88** (was $574.77), combined-vs-office margin **$259.04 (33.9%)**
  (was $190.16, 24.9%), minutes threshold **~12.7** (was ~10.7). PSA cost-saving frequency now ~82%
  (rerun, unseeded). All `analysis/01`-`05` and `07` outputs regenerated.
- Two documentation updates carried this correction: `docs/data_sources.md`'s new "CORRECTED:
  combined_to_dnc_probability's denominator" section (full audit writeup, including what this does
  NOT resolve -- the paper reports no separate insufficient-tissue count and no unresolved-failure
  data), and `docs/methods_notes.md`'s "Two escalation probabilities" and "What the base-case run
  actually found" sections.
- `tests/testthat/test-model-identity.R`: updated a stale comment (0.036 -> 0.018); no test logic
  changed, since existing tests read the parameter dynamically via `get_parameter_value()`.

## 2026-08-31 (documented a structural asymmetry the PSA output demonstrated -- no code changed)

### Added
- `docs/methods_notes.md`: new "Interpretation of delayed-neoplasia outcomes" subsection.
  `combined_emb_neoplasia_delayed_per_1000` was found to be exactly 0.000 (SD 0) across all 1,000
  draws of `analysis/03_probabilistic_sensitivity.R`'s saved PSA output -- not by construction at the
  base case only, but structurally: the combined arm has no modeled "failed and not escalated"
  pathway at all (`combined_to_dnc_probability` is a directly-observed escalation rate, not a raw
  failure probability paired with a separately estimated escalation fraction the way the office arm
  is). Documents that the resulting "combined EMB had no greater delayed-neoplasia risk than office
  EMB in 100% of draws" finding is a structural artifact, not evidence of diagnostic superiority or
  equivalence, and that the joint "cheaper AND no greater delayed-neoplasia risk" probability (69.3%)
  is therefore mathematically identical to the cost-only "cheaper" probability and adds no independent
  information. Identifies the genuine, non-degenerate clinical-risk comparison from the same PSA run
  instead: combined EMB's no-greater-major-AE-exposure probability (97.8%, not 100%, reflecting real
  overlap in the escalation-probability distributions rather than a structural zero).
- `docs/data_sources.md`: companion evidence-gap note under "Diagnostic-yield and clinical-outcome
  extension" -- what data would be needed to build a symmetric combined-arm unresolved-failure branch
  (an overall combined-EMB failure probability, and the fraction of those failures that never receive
  definitive follow-up sampling), currently absent from the evidence base.

No model code or parameter values changed in this entry -- purely documentation, written before this
finding could leak into a manuscript table or claim as though it were evidence. See the prior session
turn's independent verification (computed directly from `tables/probabilistic_sensitivity_draws.csv`,
not by calling any repository function) for the full numeric analysis this documents.

## 2026-08-31 (Table 5's cheapest-strategy probabilities were NA; extracted and fixed)

### Fixed
- `analysis/07_manuscript_outputs.R`'s Table 5 (`manuscript_table5_psa_summary.csv`) had
  `n_draws_cheapest`/`pct_draws_cheapest` equal to `NA` for every row: the inline
  `tidyr::pivot_longer()` produced a `strategy` column with a `"_cost"` suffix (`"office_emb_cost"`)
  that never matched `summarize_probability_cheapest()`'s bare strategy names (`"office_emb"`), so the
  subsequent `dplyr::left_join()` matched nothing. Found by actually running the script and reading
  its output, not by code review.
- Extracted the join logic into a new, tested function, `build_psa_summary_table()`
  (`R/tables.R`), rather than leaving it duplicated and unverified inline. It strips the `"_cost"`
  suffix before joining, and also `coalesce()`s a second, related gap the extraction surfaced: a
  strategy that was cheapest in 0 draws (e.g. D&C, in a small or skewed PSA sample) is absent from
  `summarize_probability_cheapest()`'s output entirely, which the join previously turned into `NA`
  rather than the correct `0`.
- `analysis/07_manuscript_outputs.R` now calls `build_psa_summary_table()` instead of duplicating the
  pivot/join logic inline.
- Two new regression tests in `tests/testthat/test-tables.R` (mutation-tested together, logged in
  `docs/testing_philosophy.md`): one confirming no `NA`s appear in a normal run, one confirming a
  never-cheapest strategy reports `0`, not `NA` or a missing row.
- Rerunning `Rscript analysis/07_manuscript_outputs.R` after the fix: Table 5 now correctly shows
  `combined_emb` cheapest in 68.2% of 1,000 draws, `office_emb` in 31.8%, `dnc` in 0% (0 draws) --
  consistent with the `office_to_dnc_escalation_fraction` distribution fix earlier today. All other
  manuscript tables (1-4, 6-9) were reviewed after this run and are unaffected.

## 2026-08-31 (fixed a degenerate boundary-beta distribution in PSA; PSA results change)

### Fixed
- `office_to_dnc_escalation_fraction`'s `distribution` changed from `beta` to `triangular` (min=0.5,
  mode/base=1.0, max=1.0). Running `analysis/03_probabilistic_sensitivity.R` surfaced that this
  parameter never actually varied across 1,000 PSA draws: `draw_parameter_sample()` clamps a beta
  mean of exactly 1.0 to `1 - 1e-6` before moment-matching, producing a near-point-mass distribution
  despite the parameter's declared 0.5-1.0 range. `sample_triangular()` handles min=0.5/mode=1.0/
  max=1.0 correctly, so 1.0 remains the base-case assumption while PSA now genuinely explores the
  full range. The base-case value itself is unchanged.
- `validate_model_parameters()` (`R/utils_validation.R`) now rejects any `beta`-distributed parameter
  with `base_value` exactly 0 or 1 and a non-degenerate `low_value`/`high_value` range, so this class
  of bug cannot recur silently. Mutation-tested (guard disabled -> RED -> reverted -> GREEN, logged in
  `docs/testing_philosophy.md`).
- Two new regression tests: `tests/testthat/test-parameters.R` (1,000 draws of the real parameter
  span most of 0.5-1.0, `sd > 0.01`) and `tests/testthat/test-validation.R` (the new guard, plus a
  companion test confirming a genuinely-degenerate `low_value == high_value` beta row is still
  allowed).

### PSA results changed as a direct, intended consequence
- Combined EMB cheapest in 69.3% of 1,000 draws (was 81.4%); office EMB mean cost $680 (was $766);
  combined EMB mean cost $598 (was $616). `office_emb_neoplasia_delayed_per_1000` is now nonzero in
  all 1,000 draws (median 1.41, range 0.002-5.42), versus exactly 0 in every draw before the fix. See
  `docs/data_sources.md`'s new section for the full before/after table and interpretation.

## 2026-08-31 (diagnostic-yield/clinical-outcome extension: additive, no base-case cost change)

### Added
- `R/diagnostic_yield.R` (new file): `compute_strategy_clinical_outcomes()`, the primary addition --
  uses the previously-unwired `cancer_or_precancer_after_failed_sample` parameter to compute each
  strategy's unresolved-sampling-failure probability, resulting delayed-cancer/precancer-diagnosis
  probability, and D&C-rescue-driven adverse-event exposure. At the current base case
  (`office_to_dnc_escalation_fraction = 1.0`) the delayed-diagnosis probability is exactly 0 by
  construction for every strategy -- the metric is designed to activate under a sensitivity/scenario
  override of that escalation fraction, not to change the base case itself. Also adds
  `compute_diagnostic_yield()`, a secondary Pipelle-vs-D&C sensitivity/specificity-based
  detection-probability function, deliberately not built out further this round (no PSA wiring).
- 15 new `future_extension` parameters (D&C/hysteroscopy adverse-event probabilities from Hefler et
  al. 2009 and ACOG Committee Opinion 800; Pipelle/D&C cancer and precancer sensitivity/specificity
  from Sakna/Nabhan et al. 2023's BMJ Open meta-analysis; a further-workup-fraction estimate derived
  from Slaager et al. 2025; a provisional office-EMB serious-infection placeholder documenting the
  total absence of incidence data) and 2 `reference_only`, `provisional = TRUE` adverse-event
  dollar-cost anchors borrowed, with an explicit doubly-inherited-and-wrong-population caveat, from an
  unrelated gestational-trophoblastic-neoplasia cost model (Batman et al. 2020). See
  `docs/data_sources.md`'s new "Diagnostic-yield and clinical-outcome extension" section for full
  citations -- every one independently verified against its primary source directly, after an initial
  AI-generated literature summary supplied by a collaborator turned out to reproduce the exact
  pre-correction `emb_failure_lynch` error already fixed above.
- `tests/testthat/test-diagnostic-yield.R`: 13 new tests, including a consistency guard (diagnostic
  yield and cost engine must use identical escalation probabilities), two monotonicity tests, an
  INDEPENDENT CONFIRMATION test per `docs/testing_philosophy.md`'s Rule 2, and a mutation-tested
  blocking-test pair (logged in `docs/testing_philosophy.md`).
- `run_probabilistic_sensitivity()` (`R/sensitivity_probabilistic.R`) now computes and retains
  clinical-outcome columns (`*_neoplasia_delayed_per_1000`, `*_major_ae_per_1000` per strategy) from
  the SAME per-draw sampled parameters used for cost, rather than a separate Monte Carlo loop -- so a
  cost finding and a clinical-outcome finding can be reported from the same PSA draws. An earlier
  draft of this extension proposed a fully separate `make_emb_psa_draws()`/`run_emb_psa()` framework;
  this was deliberately not built, since `draw_parameter_set()` already samples every parameter row
  generically and a second framework would have decoupled cost and clinical-outcome draws.

### Fixed
- `R/scenarios.R`: the `base_case_medicare` scenario description and the file's own docblock still
  said "no separate preop visit for the combined arm," stale since `combined_requires_preop_office_visit`
  flipped to `TRUE` on 2026-08-30. The `combined_requires_preop_visit` scenario (which had become a
  no-op restating the new default) was renamed `combined_without_preop_visit` and now represents the
  FORMER base case instead, so the model's sensitivity to this structural assumption stays checkable.

### Explicitly not added
- Adverse-event dollar costs invented without citation (an earlier draft proposed
  $5,000/perforation, $3,000/hemorrhage, $1,000/infection, $1,500/anesthesia-AE placeholders). Per
  `docs/validation_notes.md`'s norm against fabricating structure to hit a target number, no
  `expected_adverse_event_cost` component exists yet in any strategy's total.

## 2026-08-31 (five candidate papers reviewed; two new reference-only benchmarks added)

### Added
- `cost_hysteroscopy_office_moawad_2014` ($1,356) and `cost_hysteroscopy_or_moawad_2014` ($4,946) --
  reference-only office-vs-OR procedure-charge figures from Moawad et al. 2014 (JSLS, PMID 25392671),
  a University of Florida audit of diagnostic hysteroscopy for abnormal uterine bleeding. A second,
  independent office-vs-institutional cost differential alongside the existing Munro 2022 values.

### Changed
- Corrected a stale/unconfirmed citation in `docs/data_sources.md`'s `coordination_cost` entry: the
  "Weill Cornell implementation framework, ScienceDirect S1048891X2401017X" citation could not be
  located by any search method and is now flagged as unconfirmed. The paper actually obtained is a
  different, real Weill Cornell source: Ahsan et al. 2022 (Int J Gynecol Cancer 32:818-819), a
  qualitative implementation commentary with no extractable cost/time figures.

### Reviewed, not incorporated
- Munro et al. 2022's full text (previously known only via its three already-extracted reference
  values) now obtained directly; Table 1 confirms all three figures exactly. Its per-vendor
  instrumentation/depreciation tables (2A-2D) answer a hysteroscope-purchasing question, not this
  repository's EMB-vs-D&C setting comparison, and were not mined further.
- The 2024 NIHR Lynch review's own gynaecological-surveillance cost tables (UK NHS HRG tariffs, GBP,
  2021-2 prices) were located and read in full but not converted into parameters: different
  currency/payer system than this repository's US CMS basis, and the costs are bundled procedures
  (hysteroscopy+TVUS+CA-125) rather than a standalone EMB Pipelle cost. See `docs/data_sources.md`
  for the specific figures found.
- ONCE 2025 (Frissora et al., Proc BUMC 2025;38(5):646-649) reports a mean 42-minute combined
  procedure duration, converging directionally with (but less granular than) the Huang et al. 2011
  estimate already used for `combined_emb_added_minutes`. No cost or failure-rate data. Not used to
  change any parameter.
- Ahsan et al. 2022's implementation commentary (see "Changed" above) -- qualitative only, no
  extractable figures.

See `docs/data_sources.md`'s "Next literature to mine" section for the full writeup of all four
items reviewed this round.

## 2026-08-30 (combined_requires_preop_office_visit flipped to TRUE -- base case changes)

### Changed
- Per the model owner's clinical practice (Tyler Muffly, MD, Denver Health): the combined strategy's
  protocol includes a separate preoperative office visit before the colonoscopy date, for consent and
  risk assessment specific to adding EMB. `combined_requires_preop_office_visit` flipped from `FALSE`
  to `TRUE`, `provisional` cleared, re-tiered from D to `structural` (matches `reference_dollar_year`
  -- a modeling convention, not a literature-evidence claim).
- This adds `office_visit_em_cost` ($88.76) to the combined arm's cost via the `preop_office_visit`
  component in `compute_combined_emb_strategy_cost()`. Scenario analysis can still set this back to
  `FALSE` to model consent/risk assessment folded into existing care (the prior base-case assumption).
- Three tests updated for the new default: `test-parameters.R`'s boolean-parsing test now expects
  `TRUE`; `test-strategy-costs.R`'s preop-visit test rewritten to explicitly compare FALSE vs. TRUE
  overrides rather than relying on the (now-changed) default, and now also asserts the
  `preop_office_visit` component's presence/absence directly; `test-independent-confirmation.R`'s
  hand-derived combined-arm formula updated to include the preop visit cost when the toggle is TRUE.
- Base case updated: combined EMB **$574.77** (was $486.01), office EMB unchanged at $780.23, D&C
  unchanged at $3,827.04. Combined EMB is **26.3%** cheaper than office EMB (was 37.7%); minutes
  threshold **~11.1** (was ~13.8); PSA cost-saving frequency **79.7%** (was 92.3%). Provisional count
  down to 4 of 41 (was 5 of 41).

## 2026-08-31 (emb_failure_lynch corrected: two errors found in the NIHR review's Table 11)

### Changed
- Obtained full-text institutional access to all four candidate Lynch EMB-failure studies underlying
  `emb_failure_lynch` (Elmasry 2009, Lecuru 2008, Rijcken 2003 -- via institutional SSO;
  Woolderink 2020 -- genuinely open access). This parameter's numbers had previously been verified
  only against the NIHR systematic review's own extraction table (Table 11) and a third-party German
  HTA evidence report, never against the primary sources directly.
- **Found two errors in the review's Table 11**, both now corrected:
  1. Elmasry et al. 2009's true Pipelle failure count is **5/25 (20.0%)**, not 6/25 (24.0%) as the
     review's table stated. Verified directly from the paper's Table 3 ("Pipelle done" column: 20
     Yes, 5 No), recounted twice to confirm.
  2. Rijcken et al. 2003 is **not a Pipelle-specific study** -- its own Table 2 shows 5 different
     sampling methods were used (Pipelle, VABRA, hysteroscopy, curettage, hysteroscopy+curettage),
     and the 2 failures the review attributed to "Pipelle" were actually hysteroscopy and
     hysteroscopy+curettage attempts. All 4 genuinely Pipelle-labeled samples in this study succeeded
     (0/4 failures). Dropped from the pool entirely rather than corrected to 0/4, since a 4-patient
     Pipelle-only subset within an otherwise mixed-method study is not a meaningful independent
     replicate.
- Lecuru 2008 (12/116, confirmed Pipelle-specific via its Methods section) and Woolderink 2020 (5/25)
  both verified exact matches to the existing citation -- no correction needed for either.
- `emb_failure_lynch` updated: base value 0.137 -> **0.133** (pooled proportion (5+12+5)/(25+116+25) =
  22/166), low/high 0.103-0.24 -> 0.103-0.20 (now spanning three studies, not four). Source/notes
  rewritten to document the full verification chain; evidence tier stays A.
- One hardcoded test value updated (`test-parameters.R`, a boolean-override test using this
  parameter as its example, not testing its scientific content).
- Base case updated: office EMB **$764.93** (was $780.23; combined EMB unchanged at $574.77, since
  `emb_failure_lynch` only affects the office arm's own escalation probability). Combined EMB is
  **24.9%** cheaper than office EMB (was 26.3%); minutes threshold **~10.7** (was ~11.1); PSA
  cost-saving frequency **83.5%** (was 79.7%).
- This is a study-frame-relevant correction (per this project's meta-rule, independently verified
  against primary sources rather than re-derived from the same secondary review that produced the
  original error) -- see `docs/data_sources.md` for the full verification chain, study by study.

## 2026-08-31 (Yi et al. 2018 full text obtained; validation target confirmed non-viable, real findings extracted anyway)

### Changed
- Obtained full-text access to Yi et al. 2018 (Gynecol Oncol 150:112-118, PubMed 29747864) via
  institutional login (Wayback Machine access to the Pitt MPH thesis version remained down; PubMed's
  own proxy parameter did not carry authentication to Elsevier automatically, but manual institutional
  SSO login through "Access through your institution" succeeded).
- Extracted Yi et al.'s complete Table 1 parameter set (16 parameters: sampling success/failure
  probabilities, Pipelle/D&C sensitivity/specificity, EC prevalence, life expectancy by outcome,
  procedure/treatment costs) into `docs/validation_notes.md`.
- **Confirmed this is not a viable numeric-replication target**, and documented why: Yi et al.'s
  decision tree models diagnostic sensitivity/specificity, disease prevalence, treatment cost, and
  life-expectancy effectiveness, none of which `compute_strategy_costs()` implements (this repository
  is a cost-only resource model, not a full cost-effectiveness model of EC diagnosis). Plugging Yi's
  inputs into this repository's engine would not reproduce $1,897.80/$2,999.11 -- not from a missing
  parameter, but from a genuine scope mismatch. Forcing a match would require fabricating ad hoc
  structure, which the project's standing instructions prohibit.
- `literature_replication_status()`'s Yi et al. row updated from `pending_parameter_extraction` to
  `extracted_structurally_incomparable`; `test-evidence-extras.R` updated to match (still enforces
  Yi/Havrilesky are never marked "reproduced").
- Two real procedure-level cost anchors added as reference-only values:
  `cost_pipelle_yi2018` ($244.41, 2017) and `cost_dc_yi2018` ($2,310.47, 2017), for cross-checking
  against this repository's own CMS-sourced procedure costs (not a close match currently -- gap
  documented honestly in `docs/validation_notes.md`, not resolved).
- **Bonus finding**: Yi et al.'s Table 1 reports "P (moving to D&C if 1st attempted Pipelle failed) =
  0.95 (range 0.94-1)," based on the authors' own expert clinical estimation for a general (non-Lynch)
  PMB population -- a second real, converging citation for `office_to_dnc_escalation_fraction`,
  alongside the existing Nebgen et al. 2014 protocol citation. Added to the parameter's source; value
  (100%) and tier (C) unchanged, since neither citation directly measures the standalone-office Lynch
  population.
- Base case unchanged (no wired-in parameter values changed).

## 2026-08-30 (office_to_dnc_escalation_fraction grounded with an analogous real citation)

### Changed
- Searched for Lynch-specific data on `office_to_dnc_escalation_fraction` (fraction of failed office
  EMB attempts that proceed to D&C vs. a repeat office attempt), currently a 100% placeholder.
- The four Lynch EMB-failure studies underlying `emb_failure_lynch` (Elmasry 2009, Lecuru 2008,
  Rijcken 2003, Woolderink 2020) are all confirmed hard-paywalled with no free full text found
  anywhere -- a genuine access barrier, not an unsearched gap.
- Checked the two MD Anderson combined-screening papers already used elsewhere in this model: Huang
  et al. 2011 has no mention of escalation pathways anywhere in its full text. Nebgen et al. 2014
  (already the source of `combined_to_dnc_probability`) states its protocol explicitly: "If cervical
  stenosis or insufficient endometrial tissue was encountered, hysteroscopy and dilation and
  curettage were scheduled" -- real, quotable evidence that this Lynch-surveillance program's own
  protocol escalates 100% of EMB failures straight to D&C with no repeat-office step.
- `office_to_dnc_escalation_fraction`'s source/notes updated to cite this quote; re-tiered from D
  (unfounded placeholder) to C (general/adjacent Lynch-surveillance evidence). **Base value stays at
  100% and `provisional` stays `TRUE`** -- Nebgen describes the combined arm's own protocol, not
  standalone office EMB, so this is real analogous grounding, not a direct measurement of this
  parameter's target population. Base case is unchanged (no numeric value changed).

## 2026-08-30 (citation-integrity check on emb_failure_lynch, resolved -- no error found)

### Changed
- While researching `office_to_dnc_escalation_fraction`, flagged a possible citation mismatch on the
  already-in-the-base-case `emb_failure_lynch` parameter: Fam Cancer 2009 vol. 8 contains two
  similarly-themed Lynch endometrial-screening papers back-to-back (Elmasry et al., a
  patient-acceptability study, pp. 431-9; Gerritzen et al., an EMB-vs-TVUS study, pp. 391-7), and
  Elmasry's own PubMed abstract makes no mention of the "6/25" failure count attributed to it.
- Checked directly against the NIHR review's own Table 11 (NBK606812/table/table11): confirmed
  verbatim that all four pooled numerators/denominators (Elmasry 6/25, Lecuru 12/116, Rijcken 2/17,
  Woolderink 5/25) match `emb_failure_lynch`'s existing sourcing exactly. No citation error --
  Elmasry's 6/25 is reported in the paper's results, not its abstract. Independently corroborated by
  a German HTA evidence report's own full-text extraction of Elmasry 2009.
- `emb_failure_lynch`'s notes updated to document this verification chain and close the "verify
  against primary studies" open item (verified against the review's authoritative table and a
  third-party independent extraction; all four primary papers remain hard-paywalled with no free full
  text found anywhere, so direct primary-source confirmation is still not possible).
- **No base_value or evidence-tier change** -- this was a provenance-integrity check, not a data
  update. Base case is unchanged.

## 2026-08-29 (CPT 58558 data-quality flag resolved)

### Changed
- Resolved the `hysteroscopy_dc_professional_cost` data-quality flag: the recorded $204.41 and a
  conflicting $1,269.90 citation for CPT 58558 were both superseded by a live CMS Physician & Other
  Practitioners PUF query, split by `Place_Of_Srvc`: facility = $796.75 (383 rows, 6,393 services,
  2024), nonfacility = $1,310.79 (89 rows, 1,752 services, 2024). The $1,269.90 citation turns out to
  be close to the real nonfacility figure, not a professional-plus-facility bundle as originally
  suspected.
- `hysteroscopy_dc_professional_cost` updated to the real facility-setting value **$796.75**
  (matching its own description), low/high set to the real p25/p75 ($221.61 / $1,460.92), distribution
  switched from `fixed` to `gamma`, `provisional` set to `FALSE`, evidence tier upgraded from D to B.
- This parameter is still not wired into any strategy cost function (it is a reference/scenario
  parameter for a not-yet-implemented hysteroscopy-guided D&C comparator), so **the base case is
  unchanged** by this fix. Only the evidence-tier distribution shifted: Tier D 6->5, Tier B 17->18.
- Provisional count down to 5 of 41 parameters (was 6 of 41).

## 2026-08-28 (supply-cost double-count and facility-vs-nonfacility rate correction)

### Changed
- Investigated whether `emb_disposable_supply_cost` ($35 placeholder) was double-counted against
  `emb_office_professional_cost` (CPT 58100's nonfacility professional fee, charged unmodified to
  both office_emb and combined_emb), and whether the combined_emb arm should use a facility-rate
  professional fee instead, since the EMB portion of that arm is performed in the facility/
  endoscopy-suite setting where the colonoscopy itself takes place, not the physician's own office.
- Confirmed via CMS's CY2026 Physician Fee Schedule Final Rule Direct Practice Expense (PE) Inputs
  file (CMS-1832-F, no AMA-license gate): every disposable-supply line item CMS prices into CPT
  58100 -- pelvic exam pack, sterile gloves, needle, syringe, an "endometrial suction curette
  (Pipelle)," uterine sound, tenaculum, lidocaine, povidone swabsticks -- carries `nf_quantity = 1`
  (priced into the nonfacility PE RVU) and `f_quantity = 0` (excluded from the facility-setting PE
  calculation). This confirms `emb_disposable_supply_cost` was double-counted for office_emb (the
  Pipelle itself is already inside `emb_office_professional_cost`) and that the facility setting
  does not price these supplies in at all.
- Confirmed via a live CMS Physician & Other Practitioners PUF query for CPT 58100, split by
  `Place_Of_Srvc`: facility allowed amount = **$60.05** (283 services, 2024) vs. nonfacility =
  **$97.03** (4,431 services, 2024), a real ~38% gap.
- **`emb_disposable_supply_cost` removed from `compute_office_emb_strategy_cost()`** (double-count).
- **New parameter `emb_office_professional_cost_facility` ($60.05)** added and wired into
  `compute_combined_emb_strategy_cost()`'s `incremental_professional_fee` component, replacing
  `emb_office_professional_cost`. `emb_disposable_supply_cost` remains in the combined arm (genuine
  incremental cost there, since the facility-rate fee does not price supplies in) and its value was
  replaced with the real CMS-itemized sum, **$28.79** (was the $35 placeholder).
- `emb_office_professional_cost` itself switched from a 2026 fee-schedule-aggregator source to the
  live 2024 PUF nonfacility figure ($97.03, was $98.20), for methodological consistency with the new
  facility-rate parameter (both now come from the identical query/methodology).
- Two new regression tests added to `test-strategy-costs.R` (office_emb never includes a supplies
  component; combined_emb uses the facility rate, never the nonfacility rate); both mutation-tested
  (planted each defect back in, confirmed the relevant tests in `test-strategy-costs.R` and
  `test-independent-confirmation.R` fail, reverted, confirmed all pass again).
- `test-independent-confirmation.R`'s hand-derived arithmetic updated to match (removed the supply
  term from the office formula, switched the combined formula to the facility-rate parameter).
- Base case updated: combined EMB **$486.01** (was $530.37), office EMB **$780.23** (was $816.40),
  D&C unchanged at $3,827.04. Combined EMB is **37.7%** cheaper than office EMB (was 35.0%); minutes
  threshold **~13.8** (was ~13.6); PSA cost-saving frequency **92.3%** (was 90.2%). Provisional count
  dropped to 6 of 41 parameters (was 7 of 40) -- `emb_disposable_supply_cost` is no longer a
  placeholder.

## 2026-08-28 (D&C arm fully empirical; real E/M costs; recovery-room double-count removed)

### Changed
- `dnc_preop_clinic_visit_cost` replaced with a real, sourced value: CMS PUF 2024, CPT 99214
  (established patient, moderate complexity), filtered to `Rndrng_Prvdr_Type = 'Obstetrics &
  Gynecology'` specifically (7,642 real provider-service rows, 515,741 observed services),
  **$125.40** (service-weighted mean; low/high are the real p25/p75). Before pricing this, checked
  whether it might already be bundled: CMS's 90-day global-surgery period bundles the preoperative
  day into a major procedure's own payment, which would make a separate line item a double-count.
  Verified directly against the live CMS PFS Relative Value File (RVU26C, no AMA license gate) that
  CPT 58120's `GLOB DAYS` field is **010**, not 090 -- a minor-procedure period where the 1-day-before
  bundling rule does not apply, so this cost is genuinely separate.
- `office_visit_em_cost` replaced with a real, sourced value: CMS PUF 2024, CPT 99213, same OB/GYN
  filter (12,739 rows, 686,012 observed services), **$88.76**, replacing the earlier unverified $110
  national-all-specialty guess.
- `dnc_recovery_room_cost` **removed** from `compute_dnc_strategy_cost()` entirely (not priced --
  excluded). Per MedPAC's Ambulatory Surgical Center Services Payment System documentation: "Medicare
  pays for facility services provided in ASCs -- such as nursing, recovery care, anesthetics, drugs,
  and other supplies -- using a payment system that is primarily linked to [OPPS]... Within each APC,
  CMS packages most ancillary items and services with the primary service." Recovery-room/PACU time
  was already inside `dnc_facility_or_asc_fee`; summing it separately was a genuine double-count that
  had been inflating the D&C arm (and therefore inflating the combined-vs-office savings estimate) by
  ~$250 per patient. `dnc_recovery_room_cost` is kept in the parameter table only as a documented,
  explicitly-excluded reference value, matching the `colonoscopy_anesthesia_episode_cost` pattern.
- New regression test (`test-strategy-costs.R`) enforces the exclusion; mutation-tested (planted the
  double-count back in, confirmed both this test and `test-independent-confirmation.R` fail, reverted,
  confirmed both pass again).
- `test-independent-confirmation.R`'s hand-derived arithmetic updated to match the corrected D&C
  structure (it had gone stale relative to the pipeline after the recovery-room removal, which is
  exactly the kind of divergence that test exists to catch).
- **Milestone:** every component feeding the "D&C dominated even at $0 facility fee" finding
  (`dc_professional_cost`, `emb_pathology_cost`, `dnc_preop_clinic_visit_cost`,
  `dnc_anesthesia_cost`) is now a real, CMS-sourced value -- this finding no longer rests on any
  provisional placeholder.
- Base case updated: combined EMB $530.37 (was $540.26), office EMB $816.40 (was $875.26), D&C
  $3,827.04 (was $4,101.64). Combined EMB is 35.0% cheaper than office EMB (was 38.3%); minutes
  threshold ~13.6 (was ~15.0, still comfortably above Huang et al.'s entire 1-12 minute range); PSA
  cost-saving frequency 90.2% (was 93.9%). This is the first fix this session to *narrow* rather than
  widen the combined arm's advantage -- expected, since it corrected a double-count that had been
  inflating D&C's cost, not filled a gap that happened to favor one arm.

## 2026-08-28 (real coordination-cost wage component)

### Changed
- `coordination_cost`'s wage component replaced with a real, sourced value: the O*NET OnLine (BLS
  OEWS) median hourly wage for SOC 43-6013 Medical Secretaries and Administrative Assistants,
  **$22.08/hour** (2025) -- also added as its own citable reference parameter,
  `scheduler_hourly_wage_onet_2025`. bls.gov itself returns HTTP 403 to automated retrieval with an
  explicit stated bot policy; O*NET OnLine is the DOL/BLS-funded site that republishes the same OEWS
  data and does not block this.
- The time component (2 schedulers -- GYN and colorectal -- x 30 minutes each) is a practitioner
  estimate from the PI's own Denver Health institutional experience, obtained by asking rather than
  guessing, and remains flagged `provisional = TRUE` since it is not independently published. Base
  value: 2 x 0.5hr x $22.08 = **$22.08** (coincidentally close to the $25 placeholder it replaced,
  but now traceable and defensible rather than an unfounded guess).
- Caught and fixed a second small mistake before committing (this time unrelated to CSV quoting: the
  new notes text used lowercase "provisional" where `test-parameters.R`'s own-provenance check
  requires the uppercase `PROVISIONAL` keyword) via the same immediate-test-run discipline.
- Base case updated: combined EMB $540.26 (was $543.18), office EMB unchanged $875.26, D&C unchanged
  $4,101.64. Minutes threshold ~15.0 (was ~14.9); PSA cost-saving frequency 93.9% (was 94%, both
  within Monte Carlo noise of the small $2.92 base-case shift).

## 2026-08-28 (real D&C anesthesia cost)

### Changed
- `dnc_anesthesia_cost` replaced with a real, sourced value: the CMS PUF (Physician & Other
  Practitioners by Provider and Service) service-weighted mean allowed amount for CPT 00952 (the ASA
  crosswalk anesthesia code for CPT 58120), **$114.50** (2024, 118 real provider-service rows, 1,936
  observed services; low/high are the real p25/p75, $77.84/$139.10). Previously a $400 unsourced
  placeholder -- notably, the real value is far *below* the placeholder, so this fix makes the
  D&C-dominance finding more conservative, not less, correcting an assumption that had been inflating
  it. Represents only the anesthesia provider's separately-billed professional fee; routine anesthesia
  drugs/supplies are packaged into `dnc_facility_or_asc_fee` under OPPS/ASC methodology, so this does
  not double-count facility-side anesthesia costs.
- Base case updated: combined EMB $543.18 (was $553.45), office EMB $875.26 (was $914.38), D&C
  $4,101.64 (was $4,387.14). Combined EMB is 37.9% cheaper than office EMB (was 39.5%); minutes
  threshold ~14.9 (was ~15.8, still comfortably above Huang et al.'s entire 1-12 minute range); PSA
  cost-saving frequency 94% (was 93.4%). The D&C arm now has only two remaining provisional
  components (`dnc_preop_clinic_visit_cost`, `dnc_recovery_room_cost`), down from four at the start
  of this session.

## 2026-08-28 (real D&C facility fee)

### Changed
- `dnc_facility_or_asc_fee` replaced with a real, sourced value: the CMS OPPS (hospital outpatient)
  facility payment for CPT 58120, **$3,307.24** (July 2026 Addendum B, status indicator J1, APC 5414,
  relative weight 36.1783), downloaded directly from cms.gov. Previously a $1,800 placeholder with no
  source -- the largest-magnitude provisional input anywhere in the model (~75% of the D&C arm's
  total cost). Low sensitivity bound is now the real CMS ASC facility rate ($1,738.07, July 2026
  Addendum AA, payment indicator A2), also added as its own named parameter
  (`dnc_facility_fee_asc_2026`) for a "D&C in ASC" scenario. Both files required a POST-based
  workaround for CMS's AMA-license click-through gate -- documented in `docs/data_sources.md` for
  future quarterly refreshes.
- Added `cost_hysteroscopy_or_opps_2026` ($3,307.24) -- CPT 58558's own OPPS rate, confirmed identical
  to 58120's since both group into APC 5414; a same-methodology cross-check distinct from the earlier
  Munro et al. 2022 comparison (which now compares against the facility-fee component specifically,
  not the whole D&C arm total, since that total changed).
- Base case updated accordingly: combined EMB $553.45 (was $499.19), office EMB $914.38 (was
  $707.89), D&C $4,387.14 (was $2,879.90). Combined EMB is now 39.5% cheaper than office EMB (was
  29.5%); the minutes threshold rose to ~15.8 (was ~11.2, now comfortably above Huang et al.'s entire
  1-12 minute observed range rather than just its upper end); PSA cost-saving frequency rose to 93.4%
  (was 85.8%). The independent-confirmation test's premise (D&C dominance driven by its three
  *remaining* provisional components) is unaffected, since it explicitly zeroes this exact parameter.
- `docs/methods_notes.md`'s D&C-dominance caveat updated: the largest D&C-arm cost driver is no longer
  provisional, though three smaller components (`dnc_preop_clinic_visit_cost`,
  `dnc_recovery_room_cost`, `dnc_anesthesia_cost`) still are.

## 2026-08-28 (national colonoscopy-setting analysis)

### Added
- `R/colonoscopy_setting.R`, `analysis/08_colonoscopy_setting.R`: a national analysis,
  complementary to the cost model, of what fraction of U.S. Medicare colonoscopy-coded
  services occur in facility settings where coordinated sedated EMB is structurally
  feasible. Queries CMS for 2019-2024 across all 11 diagnostic/screening/therapeutic
  colonoscopy HCPCS codes, with per-year timestamped caching
  (`data-raw/cms_colonoscopy/`). Reports facility vs. nonfacility share by year/state/
  RUCA/specialty, HCPCS code mix, Medicare allowed amounts by setting, provider
  concentration (HHI), a named ASC directory, a conservative base/screening-code
  encounter-proxy sensitivity check (using CMS's beneficiary-day service counts to
  reduce within-day line-service duplication), and a dynamically-generated trend
  sentence with a fitted linear trend and p-value.
- Correctly separates ASC organizational billing from physician/supplier "facility"
  billing (`claim_role`) so the two are never summed into a double-counted facility
  total; the unidentified residual is reported as "other facility residual," not
  assumed to be hospital outpatient.
- `tests/testthat/test-colonoscopy-setting.R`: 8 test blocks, all passing on first run
  with no fixes needed -- the first externally-generated delivery this session that
  required no bug fixes after full live verification.

### Verified against live data during this integration
- All six years (2019-2024) independently confirmed to resolve to distinct CMS
  dataset UUIDs via the already-verified `cms_find_dataset_uuid()`.
- Full standardization -> ASC/professional separation -> place-of-service/RUCA/
  specialty classification -> facility-type-share/HHI/ASC-directory chain run
  end-to-end against real 2024 data for CPT 45378 (8,237 rows): 94.1% facility share,
  43.7% ASC share of facility services, HHI 0.000236 (6,815 unique providers), a
  real named ASC directory (verified plausible facility names/addresses), and a
  nonfacility/facility Medicare-payment differential ($305.70 vs. $170.70) consistent
  with Medicare's known site-of-service payment policy -- a strong signal the
  place-of-service classification is correct, not inverted.
- The full 11-code x 6-year pull (66 queries) was not run end-to-end during
  integration (some codes likely return tens of thousands of rows per year); left as
  a deliberate run via `analysis/08_colonoscopy_setting.R`.

## 2026-08-28 (public-input acquisition)

### Added
- `R/meps_download.R`, `R/hpt_hospital_discovery.R`, `R/public_input_config.R`,
  `analysis/00_get_public_inputs.R`: a reproducible pipeline that downloads and
  validates the real 2024 MEPS office-visit and Jobs files, downloads the current CMS
  hospital list, and draws a fixed-seed (`20260828`), stratified (4 Census regions x
  3 ownership types x 10 hospitals) sample of 120 hospitals for the HPT layer.
- `R/cms_benchmarks.R` rewritten with year-aware CMS dataset resolution (walks the
  catalog's `distribution` array by format/year/`accessURL` rather than regex-parsing
  the top-level `identifier`), verified against live data to resolve the same UUID as
  the previous approach.
- `R/hpt_prices.R` rewritten to handle both CMS v3 tall and wide MRF CSV layouts
  (metadata rows before the real header, `code|1`/`code|2`/... columns, payer-pivoted
  wide columns), with per-hospital failure auditing instead of silent drops.
- `tests/testthat/test-public-inputs.R`: 13 test blocks (23 assertions) covering MEPS
  column validation, `cms-hpt.txt` parsing, domain normalization, Census
  region/ownership classification, deterministic stratified sampling, config writing,
  CMS year-resolution, and tall/wide HPT parsing.

### Fixed (all found by actually running the code against real or realistic data)
- **Data-masking name collision**, again, in a fresh delivery of `R/evidence_codes.R`
  (`sampling_code_vector()`) -- same bug as 2026-08-28 (evidence layer), reintroduced
  in a later delivery of the same file. Fixed the same way.
- **Data-masking name collision in `hpt_wide_metric_column()`** (`R/hpt_prices.R`):
  `dplyr::filter(.data$payer_name == payer_name, .data$plan_name == plan_name,
  .data$metric == metric)` had all three arguments colliding with same-named columns,
  making the filter always match every row and always return the first payer's price
  column regardless of which payer was requested. This one was caught by the author's
  own test on first execution (`Expected: 140, 110`, `Actual: 140, 140`) -- the test
  was right, it had simply never been run. Fixed with `.env$` on all three comparisons.
- **Real-vs-assumed CMS column name mismatch** (`download_cms_hospital_frame()`):
  code and the author's own synthetic test fixture both assumed a normalized column
  named `citytown`; CMS's real `"City/Town"` header actually normalizes to
  `city_town`. Only a live download (5,419 real hospitals) surfaced this, since the
  test shared the same wrong assumption as the implementation. Fixed by extracting
  `normalize_cms_hospital_frame_names()` as a pure, offline-testable function and
  adding a regression test using the real column name.
- Restored the silent-CMS-filter guard (dropped in the rewritten `04_cms_benchmarks.R`)
  and a stray `.data$` tidyselect deprecation warning.

### Verified against live data during this integration
- Full MEPS pipeline (download -> extract -> validate -> estimate) against the real
  2024 files: weighted office-visit total payment $308.10, out-of-pocket $57.38,
  weighted hourly wage $23.71, 4-hour avoided-visit time cost $94.85.
- CMS hospital sampling frame: 5,419 real hospitals downloaded, correctly classified
  into 4 regions x 3 ownership groups, and stratified-sampled to exactly 120 (10 per
  stratum).
- `cms-hpt.txt` discovery + parsing against one real hospital (NYU Langone): 5
  locations correctly parsed with location name, source page, MRF URL, and contact
  info. Not run in bulk across the full 120-hospital sample (see `docs/evidence_layers.md`).

## 2026-08-28 (evidence layer)

### Added
- CI: `.github/workflows/r-tests.yml` runs `tests/testthat.R` on every push and pull
  request to `main` via `r-lib/actions`. The suite is fully offline (no live API
  calls), so CI runs are deterministic. Status badge added to `README.md`.
- Evidence layer: `R/cms_benchmarks.R` (live CMS Medicare physician-fee API),
  `R/hpt_prices.R` (Hospital Price Transparency MRF ingestion), `R/meps_burden.R`
  (MEPS patient/societal burden), `R/evidence_codes.R` (shared HCPCS codebook),
  `R/evidence_synthesis.R` and `R/evidence_provenance.R` (formatting and provenance
  helpers), run via `analysis/06_evidence_layers.R`.
- `R/budget_impact.R`: scales per-patient savings to annual cohort sizes
  (10/25/50/100/1000 patients).
- `R/sensitivity_probabilistic.R`: `summarize_probability_cheapest()` reports what
  fraction of Monte Carlo draws each strategy was the least expensive, not just the
  mean incremental cost.
- `evidence_tier` column (A/B/C/D/structural) added to every row of
  `config/model_parameters.csv`, summarized by `summarize_evidence_tiers()`.
- `R/literature_replication.R`: a generic harness (`validate_against_published_model()`)
  for checking this repository's cost engine against a published study's own
  parameters, plus `literature_replication_status()` tracking Ladabaum et al. 2011
  (cross-checked), Yi et al. 2018, and Havrilesky et al. 2009 (both
  `pending_parameter_extraction` -- not fabricated).
- `analysis/07_manuscript_outputs.R`: consolidates Tables 1-9 (parameters, cost
  components, strategy comparison, one-way sensitivity, PSA summary, thresholds,
  budget impact, evidence tiers, validation status) into `tables/manuscript_*.csv`.
- Real BLS CPI-U Medical Care anchors (2010: 388.436; 2026: 593.781) in
  `data/cpi_medical_care.csv`, and a Ladabaum et al. 2011-anchored office-EMB cost
  cross-validation scenario (`office_cost_ladabaum_historical` in `R/scenarios.R`).
- `docs/evidence_layers.md`, `docs/reuse_mapping.md`, `docs/data_sources.md`,
  `docs/methods_notes.md`, `docs/validation_notes.md`.
- Initial repository build: `R/` cost-engine (parameters, validation, inflation,
  strategy costs, comparison, deterministic + probabilistic sensitivity, threshold
  analysis, scenarios, plotting, tables), `config/model_parameters.csv`,
  `data/cpi_medical_care.csv`, `analysis/01`-`05` scripts, `tests/testthat/` suite,
  `figures/`, `tables/`.

### Changed
- `emb_failure_lynch` base value changed from an ad hoc midpoint (0.17) to a pooled
  proportion across four named Lynch-specific studies (0.137 = 25/183 pooled events),
  with the four studies' numerators/denominators recorded in the parameter's notes.
- `R/cms_benchmarks.R::cms_query_hcpcs()` now verifies the requested filter field
  actually exists in the CMS API response and errors loudly if not, rather than
  silently returning an unfiltered dataset.

### Fixed
- **Data-masking name collision** in the (since-removed) APCD prototype's
  `sampling_code_vector()`: `dplyr::filter(.data$concept %in% concept)` had the
  function argument shadowed by a same-named data column, so every call silently
  returned every procedure code regardless of what was requested. Fixed with
  `.env$concept`.
- **Reversed inequality-join columns** in the same prototype's rescue-linkage logic:
  `dplyr::join_by(rescue_date > service_date, ...)` named columns from the wrong side
  of the join, causing a hard crash. Fixed by swapping to
  `service_date < rescue_date, followup_end >= rescue_date`.
- **CPI index-scale mismatch**: an early placeholder 2014 CPI value (100) sat on a
  disconnected scale from the real 2010/2026 BLS anchors (~390-590), producing a
  spurious ~5.9x inflation multiplier for the JAMA Surgery-sourced per-minute
  room/anesthesia costs. Replaced with a geometrically interpolated placeholder on
  the correct scale, and added a permanent sanity-check test
  (`tests/testthat/test-inflation.R`) against year-to-year implausible ratios.
- `dplyr::if_else()` in `compare_strategies_to_cheapest()` and a `min()`-on-empty
  warning in the rescue-linkage logic (vctrs recycling and eager branch-evaluation
  issues respectively).

### Removed
- APCD (all-payer claims database) claims-linkage layer: designed, built, and
  verified working on synthetic data (after the two bug fixes above), but removed
  because this project has no approved state APCD data use agreement. See
  `docs/evidence_layers.md`.
- CMS facility/OPPS benchmark layer: abandoned after confirming the public
  "Outpatient Hospitals by Provider and Service" dataset is keyed by APC code, not
  HCPCS/CPT code, and would require a HCPCS-to-APC crosswalk not currently available.
