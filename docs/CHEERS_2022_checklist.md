# CHEERS 2022 checklist (internal working audit)

Audited 2026-08-31 against the current `manuscript/manuscript.qmd` and `manuscript/title_page.qmd`
(git commit at time of audit: see `git log -1 -- manuscript/`). CHEERS (Consolidated Health Economic
Evaluation Reporting Standards) 2022 is a 28-item **reporting-completeness** checklist, not a
methodological quality score -- ISPOR's own CHEERS II task force explicitly warns against using it to
grade methodology.[^1] This audit follows that distinction: "Reported" means the item is stated
somewhere in the manuscript, not that the underlying method is beyond critique (several items are
themselves the honest limitations already documented in the Discussion).

This document supersedes an earlier draft audit performed against a prior snapshot of the manuscript
(before Title, Abstract, Introduction, Discussion, the decision-tree figure, and the explicit
perspective/time-horizon/HEAP/outcome-selection/heterogeneity/distributional-effects/patient-engagement
statements existed). Several items that earlier audit marked "Missing" are now "Reported" -- re-verify
against the live file rather than trusting any cached summary of this table, including this one, once
the manuscript changes further.

The submission-ready version of this table (for use as Supplemental Digital Content, the format most
economic-evaluation journals request) is `manuscript/cheers_checklist.qmd`.

| # | CHEERS 2022 item | Status | Where addressed | Notes |
|---|---|---|---|---|
| 1 | Title: identify study as economic evaluation and specify interventions compared | Reported | Manuscript title | "Cost-Minimization of Endometrial Biopsy Strategies..." names the analysis type; the journal's 100-character title limit precludes naming all three strategies individually in the title itself -- they are named in the Précis and Abstract Objective instead. |
| 2 | Abstract: structured summary of objectives, perspective, setting, methods (including PSA/scenario analyses), results, conclusions | Reported | Abstract (Objective/Methods/Results/Conclusion) | Mentions PSA, threshold, geographic, and clinical-outcome sensitivity analyses explicitly. |
| 3 | Background and objectives: context and rationale for the evaluation, study question/objective | Reported | Introduction | Lynch syndrome background, current surveillance burden, the gap this model fills, and an explicit objective statement. |
| 4 | Health economic analysis plan (HEAP): whether one was prepared, and if so where it is available | Reported | Methods, opening paragraph | States explicitly that no HEAP was registered before the analysis began, per CHEERS's own allowance to report "none" rather than retrofit one. |
| 5 | Study population: population and subgroups analyzed, why they are relevant | Reported | Methods, opening paragraph | "Adult women with Lynch syndrome who are candidates for gynecologic surveillance and have an already-scheduled surveillance colonoscopy"; explicitly states age/genotype/menopausal status/prior biopsy history are not modeled as subgroups. |
| 6 | Setting and location: relevant context for decision-making | Reported | Methods (opening + geographic sensitivity paragraph) | U.S. Medicare context; office, facility/endoscopy-suite, and operating-room/OPPS settings; four geographic localities. |
| 7 | Comparators: interventions compared and why chosen | Reported | Methods, opening paragraph; Introduction | Standalone office biopsy, operative D&C, combined biopsy; rationale given in Introduction. |
| 8 | Perspective: perspective(s) of the analysis, and how that determined costs/outcomes included | Reported | Methods, second paragraph | "U.S. healthcare-sector perspective... valued primarily using Medicare allowed amounts... supplemented by published resource-cost estimates for services not separately reimbursed... Patient time, transportation, lost productivity, and other nonmedical costs were excluded." Revised 2026-08-31 from an earlier, less precise "health-system/payer perspective" framing that did not distinguish reimbursement-valued from resource-cost-valued inputs -- see CHANGELOG.md. |
| 9 | Time horizon: and why appropriate | Reported | Methods, second paragraph | "A single endometrial-surveillance episode, beginning with the initial sampling strategy and extending through any rescue D&C... costs or consequences beyond resolution of that episode were not included." |
| 10 | Discount rate: for costs and outcomes, why appropriate | Reported | Methods, second paragraph | "Because the horizon was less than one year, costs were not discounted." No outcome discounting applicable (outcomes are event probabilities, not life-years). |
| 11 | Selection of outcomes: outcomes used, relevance to the decision problem | Reported | Methods, third paragraph | Total expected cost as primary outcome (rationale given); two secondary clinical outcomes selected specifically to test the equivalent-effectiveness assumption. |
| 12 | Measurement of outcomes: how outcomes were measured/estimated | Reported | Methods (clinical-outcome-sensitivity paragraph); Figure 1 | AE exposure tied to D&C probability and a real cohort; delayed-neoplasia logic described; decision-tree figure shows the structural pathway. |
| 13 | Valuation of outcomes: methods to value outcomes, e.g. utility values | Reported (explicit non-valuation) | Methods, third paragraph | "Neither was converted to a utility, quality-adjusted life-year, or monetary value, so no outcome valuation step was required for them." CHEERS explicitly permits this framing for cost analyses that do not use utilities. |
| 14 | Measurement and valuation of resources and costs: methods for estimating resources/unit costs | Reported (strong) | Methods (throughout); Table 1 | CMS PFS/PUF, OPPS/ASC addenda, Direct PE Inputs file, per-minute room/anesthesia proxy, all individually cited per parameter in Table 1. |
| 15 | Currency, price date, and conversion | Reported | Methods, second paragraph | 2026 USD; BLS CPI-U Medical Care for inflation adjustment of earlier-year costs. |
| 16 | Rationale and description of model: type of model, why chosen, model diagram if applicable | Reported | Methods, fourth paragraph; Figure 1 | One-step decision tree, incremental-cost principle, escalation structure; Figure 1 (`figures/figure7_decision_tree.png`) built directly from live model output. |
| 17 | Analytics and assumptions: approach to validating/adjusting the model, structural assumptions | Reported (strong) | Methods (throughout); Table 1; `docs/methods_notes.md` | Evidence-tier hierarchy, incremental-cost principle, inflation methodology, independent re-derivation of study-frame-changing findings (`docs/testing_philosophy.md`). |
| 18 | Characterizing heterogeneity: methods for estimating differences across subgroups | Reported (explicit scope statement) | Methods, penultimate paragraph | States explicitly that only setting/geographic heterogeneity was characterized (geographic sensitivity analysis), and that patient-level heterogeneity was not modeled. |
| 19 | Characterizing distributional effects: methods for equity-related analyses | Reported (explicit N/A) | Methods, penultimate paragraph | "Distributional or equity effects... were outside this analysis's scope." The illustrative Medicaid/commercial reimbursement scenario is a payer-mix sensitivity analysis, not a distributional/equity analysis, and is not described as one. |
| 20 | Characterizing uncertainty: methods for uncertainty in study parameters, model assumptions | Reported (strong) | Methods (five-analysis paragraph); Results | Deterministic one-way sensitivity, 1,000-draw PSA, threshold analysis, scenario analysis, geographic sensitivity, plus two clinical-outcome sensitivity analyses. |
| 21 | Engagement with patients and others affected: approach and extent, if any | Reported (explicit statement) | Methods, penultimate paragraph | "Structural modeling assumptions... were informed by clinician-investigator practice experience; no formal patient or public engagement process was undertaken." |
| 22 | Study parameters: values, ranges, references, and if applicable how uncertainty was characterized | Reported (strong) | Table 1 (`tables/manuscript_table1_parameters.csv`) | Every parameter: base value, low/high bound, distribution, source citation, evidence tier. Satisfies CHEERS items 16/18's assumption-table expectation as explicitly called out by the target journal's own Instructions for Authors. |
| 23 | Summary of main results: for each strategy, costs, outcomes, and their differences | Reported | Results; Table 2 | Base-case costs and difference, PSA means, threshold values, geographic results, clinical-outcome means, all by strategy. |
| 24 | Effect of uncertainty: how uncertainty affected the decision-relevant conclusion | Reported (strong) | Results | Which parameters most influence the conclusion (tornado-style ranges), PSA probability-cheapest, threshold values, geographic robustness. |
| 25 | Effect of engagement: how engagement with patients/others affected the study | Reported | Methods, penultimate paragraph | Same sentence as item 21 names the specific structural assumption (the combined arm's preoperative office visit) that clinician input affected. |
| 26 | Study findings, limitations, generalizability, and current knowledge | Reported | Discussion | Full limitations discussion including the delayed-neoplasia structural asymmetry, the escalation-fraction assumption, D&C's own unmodeled failure risk, unmonetized adverse-event costs, and non-Lynch-specific parameter sources, each paired with what evidence would resolve it. **Flagged as a first-pass author draft pending final clinical/policy review, not yet author-confirmed** -- see the DRAFT comment at the top of that section in `manuscript.qmd`. |
| 27 | Source of funding: and role of funder | Reporting structure in place, content pending | `title_page.qmd` | Placeholder fields exist ("Disclosure of funding received for this work") but require the author's actual funding information -- not fabricated here. |
| 28 | Conflicts of interest: based on ICMJE-recommended disclosure | Reporting structure in place, content pending | `title_page.qmd` | Placeholder field exists ("Disclosure of financial support") with the journal's own suggested "no conflicts" fallback language -- requires the author's actual disclosure. |

## Summary

- **26 of 28 items:** reported in the current manuscript draft.
- **2 of 28 items (27, 28):** reporting structure exists on the title page; actual content requires the
  author (funding source, conflicts of interest are not something an AI assistant should state on an
  author's behalf).
- **0 of 28 items:** genuinely missing with no reporting mechanism in place.

Budget-impact analysis, which this model also includes (Table 7 of the full manuscript output set), is
explicitly outside CHEERS's scope per the CHEERS 2022 statement itself -- it is retained as useful
supplementary work, not force-fit into this checklist.

[^1]: Husereau D, Drummond M, Augustovski F, et al. Consolidated Health Economic Evaluation Reporting
      Standards 2022 (CHEERS 2022) Statement: Updated Reporting Guidance for Health Economic
      Evaluations. Value Health 2022;25(1):3-9.
