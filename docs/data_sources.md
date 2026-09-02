# Data sources and provenance

Every parameter's full provenance lives in `config/model_parameters.csv` (columns: `source`,
`dollar_year`, `provisional`, `notes`). This document summarizes that table, flags the open data
quality issue that needs resolution, and lays out the prioritized list of literature still worth
mining, in the order it was identified during model design.

## Parameters with a real source, wired into the base case

| Parameter | Value | Source |
| --- | --- | --- |
| `emb_office_professional_cost` | $97.03 | CMS PUF 2024, CPT 58100, `Place_Of_Srvc = O` (nonfacility/office), service-volume-weighted mean across 299 real provider-service rows, 4,431 observed services (live CMS Data API query). Applies to office_emb only |
| `emb_office_professional_cost_facility` | $60.05 | CMS PUF 2024, CPT 58100, `Place_Of_Srvc = F` (facility), service-volume-weighted mean across 20 real provider-service rows, 283 observed services (live CMS Data API query). Applies to combined_emb only -- see "Supply-cost double-count" note below |
| `emb_disposable_supply_cost` | $28.79 | CMS CY2026 PFS Final Rule Direct PE Inputs file (CMS-1832-F), CPT 58100 nonfacility supply line items, summed directly (see below). Applies to combined_emb only |
| `emb_pathology_cost` | $70.14 | CMS PFS 2026, CPT 88305 (third-party aggregator) |
| `dc_professional_cost` | $209.76 | CMS PFS 2026, CPT 58120 facility professional payment (third-party aggregator) |
| `dnc_facility_or_asc_fee` | $3,307.24 | CMS OPPS Addendum B, July 2026, CPT 58120 (downloaded directly from cms.gov 2026-08-28); low bound $1,738.07 is the real CMS ASC Addendum AA rate, also named as `dnc_facility_fee_asc_2026` |
| `dnc_anesthesia_cost` | $114.50 | CMS PUF 2024, CPT 00952 (ASA crosswalk code for CPT 58120), service-weighted mean across 118 real provider-service rows, 1,936 observed services; low/high are the real p25/p75 |
| `scheduler_hourly_wage_onet_2025` | $22.08/hr | O*NET OnLine, median wage report for SOC 43-6013 Medical Secretaries and Administrative Assistants, 2025 (BLS OEWS data; bls.gov itself blocks automated retrieval, so this real number was retrieved via O*NET OnLine, the DOL/BLS-funded site republishing the same data) |
| `office_visit_em_cost` | $88.76 | CMS PUF 2024, CPT 99213, filtered to `Rndrng_Prvdr_Type = 'Obstetrics & Gynecology'` (12,739 real provider-service rows, 686,012 observed services); service-weighted mean, low/high = real p25/p75. Replaces the earlier unverified $110 national-all-specialty guess |
| `dnc_preop_clinic_visit_cost` | $125.40 | CMS PUF 2024, CPT 99214, same OB/GYN filter (7,642 rows, 515,741 observed services); service-weighted mean, low/high = real p25/p75. See the global-period note below for why this is genuinely separately payable, not bundled |
| `combined_emb_added_minutes` | 5 (1-12) | Huang et al. 2011, PMC3014510 |
| `combined_emb_anesthesia_drug_increment_cost` | $0 | Huang et al. 2011, PMC3014510 |
| `direct_room_cost_per_minute` | $20.90/min (2014) | Childers & Maggard-Gibbons, JAMA Surgery |
| `anesthesia_cost_per_minute` | $3.42/min (2014) | Childers & Maggard-Gibbons, JAMA Surgery |
| `emb_failure_lynch` | 13.3% (pooled) | Elmasry 5/25, Lecuru 12/116, Woolderink 5/25 -- all three confirmed genuinely Pipelle-specific via direct primary-source full-text verification, 2026-08-31 (Rijcken 2003 excluded, not a Pipelle-specific study; see below) |
| `combined_to_dnc_probability` | 1.8% (2/111) | Nebgen et al. 2014, PMC4389779 -- corrected 2026-08-31 from 3.6% (2/55), a patient-level-vs-per-encounter denominator mismatch; see below |

**Retrieving the CMS OPPS/ASC addenda:** these are the official CMS payment addenda, updated
quarterly, at `cms.gov/medicare/payment/prospective-payment-systems/hospital-outpatient-pps/
quarterly-addenda-updates` (OPPS Addendum B) and `cms.gov/medicare/payment/prospective-payment-
systems/ambulatory-surgical-center-asc/asc-payment-rates-addenda` (ASC Addendum AA). Both sit behind
an AMA CPT-license click-through (`cms.gov/apps/ama/license.asp?file=/files/zip/{slug}.zip`) rather
than a direct download link; `curl -X POST` with `agree=yes&next=Accept` to
`https://www.cms.gov/files/zip/{slug}.zip` (the same URL, POST instead of the GET the license page
redirects through) returns the real zip. The July 2026 files used here also had a text encoding quirk
(a curly-apostrophe byte that makes naive `grep` treat the CSV as binary and silently return no
matches) -- use `grep -a` or open in R with `readr::read_csv()` rather than trusting an unqualified
`grep` "not found" result. To refresh: replace `july-2026` in the two slugs above with the current
quarter and re-run the same lookup for CPT 58120.

**Why the D&C preop visit is real cost, not double-counted:** before pricing
`dnc_preop_clinic_visit_cost`, its global-surgery status was checked, since CMS's 90-day (major
procedure) global period bundles the preoperative day into the procedure's own RVU-based payment,
which would make a separate preop-visit cost a double-count exactly like the recovery-room case
above. Checked against the live CMS PFS Relative Value File (`RVU26C`, `PPRRVU2026_Jul_nonQPP.csv`,
downloaded directly from `cms.gov/medicare/payment/fee-schedules/physician/pfs-relative-value-files`
-- no AMA license gate on this file): **CPT 58120's `GLOB DAYS` field is `010`**, a minor-procedure
10-day global period, not 090. The 1-day-before bundling rule is specific to 090-day major
procedures, so a preop visit on a separate calendar day from the D&C is genuinely separately
payable. Priced as CPT 99214 (established patient, moderate complexity -- chosen to reflect surgical
consent/risk discussion), filtered to real OB/GYN-specialty billing via the CMS Physician &
Other Practitioners PUF (the same live query mechanism already used elsewhere), not a national
all-specialty average.

**Note on the OB/GYN specialty filter for E/M codes:** unlike the procedure-specific codes queried
elsewhere in this repo (which have low enough national row counts to pull in full), common E/M codes
like 99213/99214 are billed by nearly every physician in the country and can return 500,000+ rows,
making an unfiltered national pull impractical. `cms_query_hcpcs()` only supports a single filter
condition; the OB/GYN-specific queries here were run with a second `Rndrng_Prvdr_Type` filter
condition added manually (value: `"Obstetrics & Gynecology"`, confirmed from CPT 58120's own billing
data -- CMS's exact provider-type string uses an ampersand, not `Obstetrics/Gynecology`). If this
kind of specialty-filtered E/M lookup is needed again, consider adding an optional second-filter
parameter to `cms_query_hcpcs()` rather than hand-writing the httr2 call each time.

## Real values kept deliberately separate from the base-case engine (reference/validation only)

These are documented in the parameter table but are **not** consumed by `R/strategy_costs.R`,
either because they represent an independent provenance track that should not be silently blended
with the CMS-2026 track, or because they are pure external benchmarks:

- `cost_emb_ladabaum_2010` ($224, gamma alpha=13.94/rate=0.062) and `cost_colonoscopy_ladabaum_2010`
  ($645) -- Ladabaum et al. 2011 (PMC3793257), a historical (2010-dollar) office-EMB cost anchor.
  Used only in the `office_cost_ladabaum_historical` scenario (`R/scenarios.R`), which
  inflation-adjusts it to the reference year using the real BLS CPI anchors below and substitutes it
  for `emb_office_professional_cost` as a cross-check, not a base-case input.
- `cost_hysteroscopy_office_munro_2022` / `_asc_` / `_or_` ($1,382.48 / $1,655.31 / $2,918.10) --
  Munro et al. 2022, an independent U.S. economic model of CPT 58558 by setting. Munro's OR figure
  ($2,918.10) is now a convergent-validation check against `dnc_facility_or_asc_fee`'s real CMS OPPS
  value specifically ($3,307.24, ~13% higher) rather than the full D&C arm total, since the facility
  fee is now sourced separately from the arm's other components -- see `cost_hysteroscopy_or_opps_2026`
  ($3,307.24, CPT 58558's own OPPS rate, identical to 58120's since both group into APC 5414) for a
  same-code, same-methodology comparison instead.
- `hysteroscopy_dc_professional_cost` ($796.75, real CMS PUF 2024 facility-setting value as of
  2026-08-29 -- see "RESOLVED data-quality flag" below) -- reference/scenario parameter only, for a
  not-yet-implemented hysteroscopy-guided D&C comparator arm; not consumed by any function in
  `R/strategy_costs.R`.
- `emb_failure_general_adambekov_2017` (22.9%, with an 8/201 access-failure vs. 37/201
  inadequate-specimen breakdown) -- a general (non-Lynch) U.S. Pipelle failure-rate study.
- `emb_failure_general` (11%) and `emb_insufficient_general` (31%) -- a general postmenopausal-bleeding
  meta-analysis (PubMed 26748390), retained as a non-Lynch comparator.
- `hysteroscopy_failure_rate_lynch_range`, `lynch_surveillance_adherence_ladabaum`,
  `combined_screen_adherence`, `office_emb_pain_*`, `combined_emb_pain` -- tagged
  `future_extension`, for effectiveness/adherence/patient-experience extensions this repository does
  not yet implement.
- `cost_hysteroscopy_office_moawad_2014` / `cost_hysteroscopy_or_moawad_2014` ($1,356 / $4,946) --
  Moawad et al. 2014 (JSLS, PMID 25392671), a University of Florida audit of office vs. OR diagnostic
  hysteroscopy for abnormal uterine bleeding (non-Lynch, n=130, billing-department charges rather than
  Medicare-allowed amounts). A second independent office-vs-institutional cost differential alongside
  the Munro 2022 values, for a different procedure and dollar year.

## Supply-cost double-count and facility-vs-nonfacility rate correction (2026-08-28)

Before this correction, `emb_office_professional_cost` (CPT 58100's nonfacility professional fee)
was charged, unmodified, to both the office_emb arm and the combined_emb arm, and
`emb_disposable_supply_cost` was an unsourced $35 placeholder summed into both arms as well. Two
questions were checked against CMS's own primary data before changing anything (per this project's
meta-rule that a study-frame-changing finding requires independent confirmation before acting on it):

**1. Is the disposable-supply cost already priced into the professional fee?** CMS's CY2026
Physician Fee Schedule Final Rule Direct Practice Expense (PE) Inputs file (`CMS-1832-F`, from the
`cms.gov/medicare/payment/fee-schedules/physician/federal-regulation-notices/cms-1832-f` regulation
page -- no AMA-license gate, unlike the OPPS/ASC addenda) itemizes every clinical-labor/supply/
equipment input CMS uses to compute a code's practice-expense RVU. Extracting the zip and grepping
`CMS-1832-F_PUF_Supply_508.txt` for HCPCS `58100` returns:

| Supply | CMS code | Unit price | `nf_quantity` | `f_quantity` |
| --- | --- | --- | --- | --- |
| Pack, pelvic exam | SA051 | $14.38 | 1 | 0 |
| Gloves, sterile | SB024 | $0.91 | 1 | 0 |
| Needle, 18-27g | SC029 | $0.04 | 1 | 0 |
| Syringe 10-12ml | SC051 | $0.21 | 1 | 0 |
| Curette, suction, endometrial (Pipelle) | SD039 | $5.75 | 1 | 0 |
| Uterine sound | SD329 | $3.17 | 1 | 0 |
| Tenaculum | SD330 | $3.77 | 1 | 0 |
| Lidocaine 1% w-epi inj (Xylocaine w-epi) | SH046 | $0.08/ml | 1 | 0 |
| Povidone swabsticks (3 pack) | SJ043 | $0.48 | 1 | 0 |
| **Total** | | **$28.79** | | |

Every single item -- including the Pipelle device itself -- carries `nf_quantity = 1` (priced into
the *nonfacility* PE RVU, i.e. already inside `emb_office_professional_cost`) and `f_quantity = 0`
(explicitly excluded from the facility-setting PE calculation). This directly confirms
`emb_disposable_supply_cost` was double-counted against `emb_office_professional_cost` for the
office_emb arm, and it was removed from that arm's cost sum accordingly (see
`R/strategy_costs.R::compute_office_emb_strategy_cost()`).

**2. Should the combined arm use a facility-setting rate?** The EMB portion of the combined arm is
performed in the facility/endoscopy-suite setting where the surveillance colonoscopy itself takes
place, not the physician's own office -- so charging it the *nonfacility* rate was a setting
mismatch. A live query against the CMS Physician & Other Practitioners by Provider and Service PUF
(`cms_query_hcpcs()` in `R/cms_benchmarks.R`) for CPT 58100, split by `Place_Of_Srvc`, found:

- Facility (`F`): service-volume-weighted mean `Avg_Mdcr_Alowd_Amt` = **$60.05** (20 provider rows,
  283 total services, 2024 claims data)
- Nonfacility (`O`): service-volume-weighted mean = **$97.03** (299 provider rows, 4,431 total
  services, 2024 claims data)

This ~38% gap is real and reproducible (re-run: `cms_query_hcpcs(cms_find_dataset_uuid("Medicare
Physician.*Provider and Service", data_year = 2024L), "58100")`, then group by `Place_Of_Srvc` and
compute the `Tot_Srvcs`-weighted mean of `Avg_Mdcr_Alowd_Amt`). A new parameter,
`emb_office_professional_cost_facility` ($60.05), now supplies the combined arm's
`incremental_professional_fee` component. Because the Direct PE Inputs file shows `f_quantity = 0`
for every one of the nine supply items above in the facility setting, those supplies are *not*
priced into the facility-rate fee -- so `emb_disposable_supply_cost`, now summed directly from the
itemized CMS supply list above ($28.79, replacing the old $35 placeholder), was kept as a genuine
incremental cost for the combined arm specifically (it is never charged to office_emb, and the
colonoscopy facility itself is never separately charged to the combined arm under the
incremental-cost principle, so nothing else prices these supplies in for this arm).

Both parameter-value changes (`emb_office_professional_cost` switched from a 2026 fee-schedule
aggregator to the live 2024 PUF nonfacility figure, for methodological consistency with the new
facility-rate parameter) and the two structural code changes above were mutation-tested per the
project's meta-rule: the double-count defect was replanted in `R/strategy_costs.R`, confirmed to
fail `tests/testthat/test-strategy-costs.R` and `tests/testthat/test-independent-confirmation.R`,
then reverted and confirmed green, for both the office-arm and combined-arm corrections
independently.

## The real BLS CPI-U Medical Care anchors (`data/cpi_medical_care.csv`)

Two real, literature-sourced index values are in place: **2010 = 388.436** and **2026 = 593.781**
(the ratio, ~1.529x, is the multiplier used in the `office_cost_ladabaum_historical` scenario).
**2014 is still an estimated placeholder** (geometrically interpolated between the two real anchors,
not an actual reported value), needed for the Childers/Maggard-Gibbons per-minute OR/anesthesia
parameters. `data-raw/00_get_price_index.R` documents how to close this gap. Both real anchors
should still be independently re-confirmed against the live BLS series (CUUR0000SAM) before this
model is used for anything beyond development -- they were transcribed during literature review, not
fetched programmatically by this repository's code.

**A real bug this exact setup caught, worth knowing about:** an earlier version of this file paired
the real anchors with a disconnected synthetic `2014 = 100` value, which silently produced a ~5.9x
inflation multiplier for every 2014-dollar cost in the model (instead of the correct ~1.4x). This was
caught by `tests/testthat/test-inflation.R`'s implausible-ratio sanity check, not by inspection.
Anyone editing this file should keep that test passing.

## RESOLVED data-quality flag: CPT 58558 (hysteroscopy + D&C) (2026-08-29)

`hysteroscopy_dc_professional_cost` was recorded as $204.41, with a conflicting citation reporting
$1,269.90 (Q4 2026, a different fee-schedule aggregator) for the same CPT code -- originally
suspected to be a professional-only vs. professional-plus-facility distinction. A live CMS Physician
& Other Practitioners PUF query for CPT 58558, split by `Place_Of_Srvc` (the same method used to
resolve the CPT 58100 facility/nonfacility question above), found:

- Facility (`F`): service-volume-weighted mean allowed amount = **$796.75** (383 provider rows,
  6,393 total services, 2024 claims data), p25 = $221.61, p75 = $1,460.92
- Nonfacility (`O`): service-volume-weighted mean = **$1,310.79** (89 provider rows, 1,752 total
  services), p25 = $1,204.56, p75 = $1,455.15

Neither original figure was right, but the mystery is resolved: the $1,269.90 citation is very close
to the real *nonfacility* weighted mean ($1,310.79) -- it was very likely reporting the nonfacility
(physician-office, all-inclusive) allowed amount, not a professional-plus-facility bundle. Since this
parameter's own description specifies the *facility* setting (paired with a separate facility payment
such as `cost_hysteroscopy_or_opps_2026`), it was updated to the real facility-setting value,
**$796.75** (low/high = the real p25/p75), `provisional` set to `FALSE`, and re-tiered to evidence
tier B. It remains unwired into any strategy cost function -- this is still a reference/scenario
parameter only, for a not-yet-implemented hysteroscopy-guided D&C comparator arm (see
`hysteroscopy_failure_rate_lynch_range`), so this fix does not change the base case.

## PARTIALLY RESOLVED, then CORRECTED: `emb_failure_lynch`'s source citations (2026-08-30 -> 2026-08-31)

**2026-08-30 finding (paper-identity question -- correctly resolved):** while researching
`office_to_dnc_escalation_fraction` (below), a possible citation-mismatch concern surfaced: Fam
Cancer 2009, volume 8, contains two similarly-themed Lynch-syndrome endometrial screening papers
back-to-back -- Elmasry K et al., "Strategies for endometrial screening in the Lynch syndrome
population: a patient acceptability study" (pp. 431-9), and Gerritzen LH et al., "Improvement of
endometrial biopsy over transvaginal ultrasound alone for endometrial surveillance in women with
Lynch syndrome" (pp. 391-7). Elmasry's own PubMed abstract (PMID 19526324) only describes a
pain/acceptability survey with no mention of a biopsy failure count, raising the question of whether
the "Elmasry 6/25" figure actually belonged to Gerritzen's paper instead. Checked against the NIHR
review's own Table 11 (NBK606812/table/table11), which attributes 6/25 (24.0%) to Elmasry
specifically, and against an independent German HTA evidence report that separately extracted
Elmasry's full-text results directly, confirming the same 25-patient cohort had Pipelle-related
failures. Conclusion at the time: no paper-identity error -- 6/25 is genuinely Elmasry's number, just
reported in the results/table rather than the abstract. **This conclusion about which paper the
number belongs to was correct.**

**2026-08-31 finding (the number itself was wrong -- this is the real correction):** institutional
full-text access to all four candidate studies (see below) allowed direct verification against the
primary sources for the first time, rather than relying on the NIHR review's extraction table. This
found the review's Table 11 itself contains an error: Elmasry's Table 3 "Pipelle done" column shows
20 successful biopsies and 5 failures (patients coded "No- atrophic" x2, "No- pain", "No- no sample",
"No- no access") out of 25 -- **5/25 (20.0%), not 6/25 (24.0%)** as the review's table states. Recounted
twice directly from the primary table to confirm. Separately, Rijcken et al. 2003 turned out not to
be a Pipelle-specific study at all (see below) -- a second, independent error in the same review
table. Both corrections are now reflected in `emb_failure_lynch`'s base value (13.7% -> 13.3%); see
`docs/methods_notes.md` for the full before/after base-case impact. The lesson: confirming a number
matches its cited secondary source is necessary but not sufficient -- the secondary source itself can
be wrong, and only reading the primary text catches that.

## Full primary-source verification of `emb_failure_lynch`'s four candidate studies (2026-08-31)

Institutional full-text access (University of Colorado Anschutz, via PubMed's institutional proxy
and each publisher's own SSO) was used to read all four Lynch EMB-failure studies directly for the
first time -- previously this parameter's numbers were checked only against the NIHR review's
extraction table and a third-party evidence report, never the primary sources themselves.

**Elmasry et al. 2009** (Fam Cancer 8:431-9, PMID 19526324) -- Table 3 lists every one of the 25
participants' "Pipelle done" outcome individually: 20 "Yes" (all "Normal" histology) and 5 "No"
(patients coded atrophic x2, pain/cannulation-failure x1, no-sample x1, no-access-from-prior-resection
x1). **5/25 (20.0%)**, not the 6/25 (24.0%) the NIHR review's Table 11 stated. Recounted twice
directly from the table to confirm before using this number.

**Lecuru et al. 2008** (Int J Gynecol Cancer 18:1326-31, PMID 18217965) -- Methods states endometrial
biopsy "was performed using a Pipelle de Cornier device" for every attempt (confirms this is
genuinely Pipelle-specific, unlike Rijcken below); Results reports "endometrial biopsy was attempted
in 116 cases and failed in 12 (10%)." **12/116 (10.3%)** -- exact match to the existing citation, no
correction needed.

**Rijcken et al. 2003** (Gynecol Oncol 91:74-80, PMID 14529665) -- this is where the review's second
error was found. This study's own Table 2 lists the "Method of sampling" used for each of its 17
endometrial samplings individually: Pipelle (4 patients: 3C, 4, 8, 12), VABRA (2 patients),
hysteroscopy alone (2 patients), curettage (2 patients), and hysteroscopy+curettage (7 patients) --
a genuine mix, not a Pipelle-specific protocol. The 2 samples with "No material" outcomes (the
NIHR review's numerator for "2/17 Pipelle") were patients using the "Hysteroscopy" and
"H&C + biopsy" methods specifically, per the same table -- **neither was a Pipelle attempt.** Of the
4 genuinely Pipelle-labeled samples in this study, all 4 succeeded (0/4 failures; 2 showed complex
atypical hyperplasia, 2 showed no abnormalities). Rijcken was therefore dropped from
`emb_failure_lynch`'s pool entirely, rather than corrected to 0/4 -- a 4-patient Pipelle-only subset
buried inside an otherwise mixed-method study is not a meaningful independent replicate for a pooled
Lynch-specific Pipelle failure-rate estimate.

**Woolderink et al. 2020** (BMC Womens Health 20:54, PMID 32183830, genuinely open access) -- Table 2:
of 25 enrolled women, 18 had sufficient endometrial samples and 5 had insufficient samples (23
attempted the invasive sampling; 2 more never attempted it at all, for other reasons). **5/25
(20.0%)** -- exact match to the existing citation, no correction needed.

**Net result:** `emb_failure_lynch`'s pooled estimate is now built from three studies (Elmasry,
Lecuru, Woolderink), each individually confirmed genuinely Pipelle-specific by reading the primary
text, with Rijcken excluded as a category error rather than merely a wrong number. New pooled value:
(5+12+5)/(25+116+25) = 22/166 = **13.3%** (was 13.7%). See `config/model_parameters.csv`'s
`emb_failure_lynch` row for the full citation and `docs/methods_notes.md` for the base-case impact.

## Corroborating (non-Lynch) context for `emb_failure_lynch`: Adambekov et al. 2017 (2026-09-01)

Adambekov et al. 2017 (Gynecol Oncol 144:324-328, PMID 27913154) is a general (non-Lynch)
retrospective cohort of 201 women undergoing Pipelle biopsy for suspected uterine pathology at a
single U.S. health system (UPMC, 2013), examining risk factors for sampling failure. Read in full
2026-09-01 to assess whether it belongs in this repository's citation base.

**Not used to change `emb_failure_lynch`'s base value.** This is a general population, not Lynch
syndrome specifically -- tier C (general/adjacent) evidence relative to the tier-A pooled
Lynch-specific estimate above. This project's convention is not to dilute a direct-population
tier-A estimate with adjacent-population data (see the evidence-tier system in
`config/model_parameters.csv`).

**What it does provide: corroborating context that 13.3% is plausible, not an outlier.** Adambekov
reports an overall Pipelle failure rate of 46/201 = 22.89% in its general population -- higher than
this model's Lynch-specific 13.3%, but Adambekov's own introduction cites Dijkhuizen et al. 2000's
pooled meta-analytic estimate of 10.4% and Clark et al. 2002's 8%, with individual studies reporting
up to 33% depending on population characteristics. This model's Lynch-specific pooled rate (13.3%)
sits within that broader range, closer to the meta-analytic estimates than to the higher
single-study outliers.

**Checked and confirmed NOT relevant to `office_to_dnc_escalation_fraction`.** Despite superficially
seeming related (both concern "what happens around a failed Pipelle attempt"), Adambekov reports
only predictors of the failure event itself (postmenopausal bleeding as indication, OR 7.41; history
of prior biopsy failure, OR 23.87; non-physician provider, OR 9.15) and nothing about the pathway
after a failure -- no repeat-attempt-vs-D&C data. `office_to_dnc_escalation_fraction` remains sourced
only by Nebgen et al. 2014's protocol language and Yi et al. 2018's published estimate (see
`config/model_parameters.csv`).

**Net result:** added as a corroborating-context citation in `config/model_parameters.csv`'s
`emb_failure_lynch` notes field, not wired into any cost function, not added to the manuscript's
reference list (the manuscript's Methods does not currently discuss general Pipelle-failure-rate
literature at all).

## CORRECTED: `combined_to_dnc_probability`'s denominator (2026-08-31)

A collaborator flagged a possible denominator mismatch and asked for it to be audited against the
primary text before anything was changed, per this project's independent-confirmation meta-rule
(`docs/testing_philosophy.md`). Confirmed by reading the primary source directly (not the secondary
summary that raised the question):

Nebgen et al. 2014's "Demographics" section states: **"Two women (3.6%) had cervical stenosis and
underwent hysteroscopy with dilation and curettage."** This sentence sits directly among other
unambiguously patient-level statistics in the same paragraph -- "The mean age at enrollment was 39.5
years... The majority were Caucasian (85%)... Eighty-five percent were pre-menopausal... The majority,
78% were multiparous..." -- all computed over the paper's n=55 patients, not its 111 screening visits.
2/55 = 3.636%, matching "3.6%" exactly; 2/111 would round to "1.8%," which the paper does not use here.
The same paper explicitly uses the 111-visit denominator elsewhere, for encounter-level rates: "EMBx
in our study detected endometrial cancer in 0.9% (1/111) of surveillance visits, and premalignant
hyperplasia in 3.6% (4/111) of screening visits" -- so the authors themselves consistently distinguish
patient-level from visit-level percentages, and placed the cervical-stenosis figure in the
patient-level block.

`combined_to_dnc_probability` is consumed by `compute_combined_emb_strategy_cost()` as a
**per-encounter** `escalation_probability` -- `compute_strategy_costs()` prices a single combined-
screening visit, not a patient's multi-year screening history. Using the patient-level 2/55 (a
10.5-year cumulative prevalence: "what fraction of these patients ever had this happen across all
their visits") as a per-encounter probability was therefore the wrong denominator for how this
parameter is actually used in the cost engine. Re-denominated to the encounter-level rate the same two
events are counted against elsewhere in the same paper: **2/111 = 1.8%**.

**What this correction does NOT resolve.** The paper's protocol statement -- "If cervical stenosis or
insufficient endometrial tissue was encountered, hysteroscopy and dilation and curettage were
scheduled" -- covers two failure modes, but the paper reports a count for only one of them (the 2
cervical-stenosis cases). No separate insufficient-tissue count is given, so 2/111 is a **floor** on
total combined-EMB escalations, not necessarily a complete count. The paper also reports no data on
what fraction of combined-EMB failures, if any, went unresolved (no rescue procedure) -- this is the
same evidence gap already documented in `docs/methods_notes.md`'s "Interpretation of delayed-neoplasia
outcomes" section, and remains open. A collaborator has proposed contacting the Nebgen and/or ONCE
(Frissora et al. 2025) investigators for the underlying aggregate counts (total combined-EMB attempts,
adequate/insufficient specimens, cervical stenosis, repeat EMB, hysteroscopy/D&C, no follow-up
sampling) -- this would let `office_failed_emb_further_workup_fraction`-style math be built for the
combined arm the way it already exists (indirectly) for the office arm. Not yet pursued.

**Effect on the base case:** `low_value`/`high_value` also updated, from an unsourced 0.01-0.10
sensitivity band to the exact binomial 95% CI for 2/111 (`stats::binom.test()`: 0.0022-0.0636).
Combined EMB's expected cost dropped from $574.77 to $505.88 (its escalation-cost component roughly
halved along with the escalation probability); the combined-vs-office margin widened from $190.16
(24.9%) to $259.04 (33.9%); the minutes threshold widened from ~10.7 to ~12.7. See
`docs/methods_notes.md` for the full base-case history.

## Literature search for `office_to_dnc_escalation_fraction` (2026-08-30, partially resolved)

Searched for a Lynch-specific fraction of failed/inadequate standalone office EMB attempts that
proceed to operative D&C versus a repeat office attempt. Two avenues were checked:

1. **The four Lynch EMB-failure studies underlying `emb_failure_lynch`** (Elmasry 2009, Lecuru 2008,
   Rijcken 2003, Woolderink 2020) -- as of 2026-08-30 all four were confirmed hard-paywalled with no
   free full text found anywhere (PMC, publisher DOI pages, institutional repositories all checked);
   Woolderink turned out to be genuinely open access after all, and full text of the other three was
   obtained on 2026-08-31 via institutional access (see the primary-source verification section
   above). None of the four papers describes a repeat-office-attempt-vs-D&C-escalation split for
   standalone office EMB -- this remains a genuine literature gap, now confirmed by reading the full
   text rather than inferred from inaccessible abstracts.
2. **The two MD Anderson combined-screening papers already used elsewhere in this model**: Huang et
   al. 2011 (PMC3014510) has no mention of biopsy failure or escalation pathways anywhere in its full
   text (it is a pain/acceptability study only). Nebgen et al. 2014 (PMC4389779) -- already the
   source of `combined_to_dnc_probability` -- states its protocol explicitly: "If cervical stenosis
   or insufficient endometrial tissue was encountered, hysteroscopy and dilation and curettage were
   scheduled," and reports "two women (3.6%) had cervical stenosis and underwent hysteroscopy with
   dilation and curettage." This is real, quotable evidence that this MD Anderson Lynch-surveillance
   program's own protocol escalates 100% of EMB failures straight to D&C, with no repeat-office-visit
   step written into the protocol.

**Why this only partially resolves the parameter:** Nebgen et al. 2014 describes the *combined* arm's
protocol (EMB fails during an already-sedated colonoscopy encounter), not a standalone office-EMB
program specifically. It is real, Lynch-specific, and directly analogous, but it is not a direct
measurement of `office_to_dnc_escalation_fraction`'s target population. The parameter's source/notes
were updated to cite this quote and re-tiered from D (unfounded placeholder) to C (general/adjacent
Lynch-surveillance evidence); the base value stays at 100% and `provisional` stays `TRUE`, since no
study of the standalone-office population itself was found. This is a genuine, currently-unresolvable
literature gap given the paywall barrier on the four candidate primary studies, not an unsearched one.

**Update (2026-08-31):** a second, independent, real citation was found while extracting Yi et al.
2018's full text for the validation exercise below. Yi et al.'s Table 1 reports "P (moving to D&C if
1st attempted Pipelle failed) = 0.95 (range 0.94-1)" for a general (non-Lynch) postmenopausal-bleeding
Medicare cohort -- i.e. only 5% of failed Pipelle attempts get a repeat office attempt, the rest move
straight to D&C. The paper's own footnote states this is "based on expert clinical estimation," not a
directly measured rate, but it is a real, peer-reviewed, published number, and it converges closely
with both the existing Nebgen et al. 2014 citation and this parameter's 100% base case. Added to the
parameter's source; value and tier unchanged (100%, still tier C, still provisional) since neither
citation is a direct measurement of the standalone-office Lynch population.

## `combined_requires_preop_office_visit` confirmed by the model owner (2026-08-30)

Per the model owner's clinical practice (Tyler Muffly, MD, Denver Health), the combined strategy's
protocol includes a separate preoperative office visit before the colonoscopy date, for consent and
risk assessment specific to adding EMB to the procedure. `combined_requires_preop_office_visit` was
flipped from `FALSE` to `TRUE` and its `provisional` flag cleared. This is a structural modeling
decision, not a literature-evidence claim -- it is re-tiered from D (unfounded placeholder) to
`structural`, the same tier used for `reference_dollar_year`, since it reflects a protocol/scenario
decision rather than a data point to be graded A-D. The base case now includes `office_visit_em_cost`
($88.76) as the combined arm's `preop_office_visit` component; scenario analysis can still set this
back to `FALSE` to model consent/risk assessment folded into existing care (the prior base-case
assumption). This narrowed the combined-vs-office margin from $294.22 (37.7%) to $205.46 (26.3%) and
the minutes threshold from ~13.8 to ~11.1 -- see `docs/methods_notes.md` for the full base-case
history.

## Fixed: `office_to_dnc_escalation_fraction` was a degenerate beta distribution in PSA (2026-08-31)

Running `analysis/03_probabilistic_sensitivity.R` after adding the diagnostic-yield extension below
surfaced a real bug: `office_emb_neoplasia_delayed_per_1000` was exactly 0 across all 1,000 PSA draws,
not just at the base case. Cause: `office_to_dnc_escalation_fraction`'s `base_value` sits at exactly
1.0, a distribution boundary. `draw_parameter_sample()` (`R/sensitivity_probabilistic.R`) moment-matches
a beta distribution to `base_value`, clamping means of exactly 0 or 1 to `1e-6`/`1 - 1e-6` -- so every
PSA draw for this parameter landed within a hair of 1.0 regardless of its declared 0.5-1.0
`low_value`/`high_value` range. The parameter never actually varied in probabilistic sensitivity
analysis, which meant `compute_strategy_clinical_outcomes()`'s delayed-neoplasia metric was
mechanically silent in every stochastic run -- exactly the parameter this whole extension exists to
stress-test.

**Fix:** changed `office_to_dnc_escalation_fraction`'s `distribution` from `beta` to `triangular`
(min=0.5, mode=1.0, max=1.0). `sample_triangular()` already handles this correctly as min/mode/max, so
1.0 remains the base-case/modal assumption while PSA now genuinely explores the 0.5-1.0 range.
Triangular is also the more honest distributional choice here on its own terms: this 0.5-1.0 range is
a structural/plausibility bound (per the parameter's own notes, no study of standalone office EMB
reports this split), not a binomial confidence interval, which is what the beta machinery implicitly
assumes. The base case (100% escalation) itself was deliberately left unchanged -- this is a sampling
fix, not a re-grounding of the assumption.

**Guard added:** `validate_model_parameters()` (`R/utils_validation.R`, run automatically inside
`load_model_parameters()`) now rejects any `beta`-distributed parameter with `base_value` exactly 0 or
1 and a non-degenerate `low_value`/`high_value` range, so this class of bug cannot recur silently
elsewhere. Regression tests: `tests/testthat/test-parameters.R` (confirms 1,000 draws of the real,
fixed parameter span most of 0.5-1.0 with `sd > 0.01`) and `tests/testthat/test-validation.R` (the
guard itself, mutation-tested per `docs/testing_philosophy.md`).

**Effect on PSA results** (`Rscript analysis/03_probabilistic_sensitivity.R`, `n_simulations = 1000`,
before -> after):

| Metric | Before fix | After fix |
| --- | --- | --- |
| Combined EMB cheapest | 81.4% of draws | 69.3% of draws |
| Office EMB mean cost | $766 | $680 |
| Combined EMB mean cost | $616 | $598 |
| `office_emb_neoplasia_delayed_per_1000` | exactly 0 in all 1,000 draws | median 1.41, mean 1.60, range 0.002-5.42 (all 1,000 draws nonzero) |

The prior 81.4% figure was effectively conditioning on `P(D&C after failed office EMB) ~= 1` in every
draw, which understated office EMB's true expected rescue-D&C cost across the parameter's own declared
uncertainty range. Once the parameter actually varies, lower escalation draws reduce office EMB's
expected cost (narrowing combined EMB's cost-saving margin) while simultaneously generating nonzero
delayed-neoplasia risk for office EMB specifically -- the cost-versus-diagnostic-risk tradeoff this
extension was built to expose. Combined EMB remains the more frequently cost-saving strategy; office
EMB's PSA-implied delayed-neoplasia risk (median ~1.4 per 1,000) is a new, previously invisible
finding that argues against treating `office_to_dnc_escalation_fraction`'s 100% base case as a
costless conservative assumption.

## Diagnostic-yield and clinical-outcome extension (2026-08-31)

`R/diagnostic_yield.R` adds 15 new parameters, all `future_extension` category/strategy (not wired
into `R/strategy_costs.R`), plus two `reference_only` adverse-event cost anchors. Every citation below
was independently verified against the primary source directly (PubMed abstract, or full open-access
text where available), not accepted from a secondary AI-generated literature summary a collaborator
initially supplied -- that summary's "office EMB failure" figures (6/25, 12/116, 2/17, 5/25 -> 13.7%)
turned out to reproduce the exact pre-correction error already fixed in `emb_failure_lynch` above,
which is why every numeric claim here was re-checked against the actual paper before being added.

**D&C adverse-event probabilities** (`dnc_perforation_probability` 0.93%, `dnc_false_passage_probability`
0.78%, `dnc_severe_hemorrhage_probability` 0.13%, `dnc_overall_complication_probability` 1.92%) --
Hefler L et al. The intraoperative complication rate of nonobstetric dilation and curettage. Obstet
Gynecol 2009;113(6):1268-1271 (PMID 19461421). Verified directly from the PubMed abstract: 103/5,359
(1.9%) intraoperative complications in a retrospective single-center series (2,542 premenopausal +
2,817 postmenopausal patients, 1995-2006); perforation 50/5,359 (0.9%), false passage 42/5,359 (0.8%),
severe hemorrhage 7/5,359 (0.1%). 95% CIs for all four values computed via exact binomial test
(`stats::binom.test()` in R), since the source itself reports point estimates only. Non-Lynch general
D&C population; the source's own finding that retroverted uterus, postmenopausal status, and
nulliparity independently predict complications is relevant since Lynch surveillance D&Cs skew toward
that risk profile.

**Hysteroscopy complication probabilities** (`hysteroscopy_diagnostic_complication_probability` 0.13%,
`hysteroscopy_operative_complication_probability` 0.95%, `hysteroscopy_postprocedure_infection_probability`
range 0.01%-1.42%, midpoint 0.72%) -- ACOG Committee Opinion No. 800, The Use of Hysteroscopy for the
Diagnosis and Treatment of Intrauterine Pathology (2020). Verified by reading the full committee
opinion text directly (acog.org, open access): "The two largest multicenter studies of 13,600
diagnostic and operative hysteroscopies and 21,676 operative hysteroscopies found overall complication
rates of 0.28% and 0.22% respectively... Significantly more complications occurred during operative
hysteroscopy than during diagnostic hysteroscopy (0.95% versus 0.13%; P<.01)," and "rates of
postprocedure infection... ranging from 0.01% to 1.42%." The source does not disaggregate which exact
denominator backs the 0.13%/0.95% split, nor does it report a confidence interval for the infection
range -- both limitations are carried into the parameter notes rather than papered over.

**Office EMB serious-infection probability** (`office_emb_serious_infection_probability` = 0,
PROVISIONAL) -- Namazov A et al. Septic Shock and Multiple Organ Failure After Office Endometrial
Sampling. J Reprod Med 2017;62(1-2):72-74 (PMID 29999294), a case report. Verified directly from the
PubMed abstract, which states plainly: "No data are available of infectious complications related to
endometrial biopsy. The incidence is presumed to be negligible." Base value of 0 documents this
absence of any denominator, not a claim of zero risk.

**Diagnostic sensitivity/specificity for cancer and precancer** (`office_emb_cancer_sensitivity` 0.774
[0.565-0.900], `dnc_cancer_sensitivity` 0.880 [0.281-0.993], `office_emb_cancer_specificity` 0.985
[0.927-0.997], `dnc_cancer_specificity` 0.984 [0.956-0.995], `office_emb_precancer_sensitivity` 0.74,
`dnc_precancer_sensitivity` 0.80) -- Sakna NA et al. Diagnostic accuracy of endometrial sampling tests
for detecting endometrial cancer: a systematic review and meta-analysis. BMJ Open 2023;13:e072124
(open access, CC BY-NC 4.0; verified by reading the full text directly, not just the abstract). A
bivariate diagnostic random-effects meta-analysis of 12 studies (1,607 participants); the Pipelle-EC
subgroup pools only 3 studies, D&C-EC pools 5 -- D&C's very wide 95% CI (28.1%-99.3%) is a direct
consequence of that small, heterogeneous pool, not a transcription error. The AEH/precancer subgroup
values (0.74/0.80) have no confidence interval reported in the source's main text. Population is women
with clinical suspicion of endometrial carcinoma (mostly postmenopausal bleeding) referred for
hysterectomy -- indirect evidence for this repository's asymptomatic Lynch surveillance population,
not a direct measurement of it.

**Further-workup fraction after a benign/insufficient office sample**
(`office_failed_emb_further_workup_fraction` = 0.695 [0.50-1.00]) -- Slaager FC et al. Diagnostic
workup of patients with benign or inconclusive reports on office endometrial biopsy after first
episode of postmenopausal blood loss. Eur J Obstet Gynecol Reprod Biol 2025;310:113991 (PMID
40294513), a multicenter prospective cohort. Verified directly from the PubMed abstract: of 350
eligible patients, 197 (56%) underwent further diagnostic procedures (hysteroscopy or saline infusion
sonography); those patients had more frequent insufficient aspiration samples (20.8% vs. 11.8%,
p=0.025) than the 153 managed expectantly. The 0.695 base value is NOT the authors' own stated number
-- it is derived here by back-calculating approximate counts from those percentages (20.8% x 197 ~= 41
insufficient-sample patients who received further workup, 11.8% x 153 ~= 18 who did not; 41/(41+18) =
0.695) and is explicitly flagged as such in the parameter's notes. This is a broader, non-D&C-specific
"further workup" pathway, kept deliberately separate from `office_to_dnc_escalation_fraction` (see
below) rather than replacing its base-case value.

**Adverse-event dollar-cost anchors, doubly-inherited, tier D**
(`cost_uterine_perforation_gtn_model_2020` $12,800, `cost_hemorrhage_gtn_model_2020` $4,882, 2018
dollars) -- Batman S et al. Cost-effectiveness of second curettage for treatment of low-risk
non-metastatic gestational trophoblastic neoplasia. Gynecol Oncol 2020;157(3):711-715 (PMID 32276791,
PMC7293571), Table 2. Verified by reading the full text directly. Both figures were themselves
borrowed by this GTN cost-effectiveness model from two entirely unrelated cost studies (perforation
cost from Moayeri et al. 2009, a laparoscopy-for-infertility cost-effectiveness study, under the
assumption every perforation results in a diagnostic laparoscopy; hemorrhage cost from Chung et al.
2001, a trial-of-labor-after-cesarean cost-effectiveness study), then inflated to 2018 dollars via
medical CPI. Per this project's explicit prior finding while grounding `office_to_dnc_escalation_fraction`
and the norm stated in "What should not be conflated" below and in `docs/validation_notes.md`: this is
disclosed as a weak, doubly-indirect anchor from the wrong clinical population, kept only as a
documented starting point for a real CMS resource-pathway costing exercise, and explicitly NOT treated
as sufficient evidence to wire an adverse-event cost into any strategy's total.

**What was deliberately NOT added:** unsourced adverse-event dollar costs of the kind that would let
`compute_strategy_clinical_outcomes()` produce an `expected_adverse_event_cost` column immediately
(an earlier draft of this extension proposed $5,000/perforation, $3,000/hemorrhage, $1,000/infection,
$1,500/anesthesia-AE placeholders with no citation at all). `docs/validation_notes.md`'s explicit norm
against "fabricating structure to hit a known target" applies with equal force to inventing a cost as
to inventing a probability -- see the two GTN-model anchors above for what a real, disclosed-as-weak
alternative looks like instead.

**Combined-EMB unresolved-failure probability: evidence gap.** The current model cannot estimate
delayed cancer or precancer after combined EMB in a manner directly comparable with standalone office
EMB. The available combined-screening evidence provides a directly observed probability of escalation
to hysteroscopy/D&C (`combined_to_dnc_probability`) but does not separately report (1) the overall
probability of an inadequate or failed combined EMB and (2) the fraction of those failures that never
receive definitive follow-up sampling. The model therefore has no evidence-based unresolved-failure
branch for combined EMB. Its modeled delayed-neoplasia rate is consequently zero by construction and
must not be interpreted as evidence that combined EMB eliminates delayed diagnosis. Demonstrated
empirically 2026-08-31: `combined_emb_neoplasia_delayed_per_1000` was exactly 0.000 (SD 0) across all
1,000 draws of `analysis/03_probabilistic_sensitivity.R`'s PSA output, while office EMB's equivalent
column varied with a mean of 1.60 per 1,000 -- see `docs/methods_notes.md`'s "Interpretation of
delayed-neoplasia outcomes" section for the full write-up and why the resulting "cheaper AND no
greater delayed-neoplasia risk" joint probability should not be reported as a distinct finding.

## Manuscript submission materials (2026-08-31)

`manuscript/title_page.qmd` and `manuscript/manuscript.qmd` are Quarto files formatted for submission
to *Obstetrics & Gynecology* (the "Green Journal"), split per the journal's double-anonymized peer
review requirement. Format verified directly against the journal's live Instructions for Authors
(`journals.lww.com/greenjournal/pages/information-for-authors`, version dated April 20, 2026), not
assumed from general knowledge -- word/reference/figure limits, structured-abstract headings, body
section order, citation style, and the two CHEERS reporting-guideline items the journal calls out
specifically (item 15, a model-summary figure; items 16/18, a full assumption table) were all read
directly from the live page. Both files render successfully via `quarto render` to real `.docx` files.

Two new analysis scripts support the manuscript's finalized figure/table selection:

- `analysis/10_decision_tree_figure.R` builds `figures/figure7_decision_tree.png` (CHEERS item 15) via
  `DiagrammeR`/Graphviz, using standard decision-tree notation (squares = decisions, circles = chance
  nodes, triangles = terminal/payoff nodes). Every probability and dollar figure on the diagram is
  pulled live from `compute_strategy_costs()`, not hand-typed -- the figure cannot silently drift from
  the base case. Terminal nodes show the actual cost incurred along that specific path (e.g., the
  office-EMB-then-D&C terminal shows `initial_cost + dnc_cost`, not the strategy's overall
  probability-weighted expected cost, which is instead annotated at the chance node) -- an initial
  version of this figure conflated the two, caught and corrected before use.
- `analysis/11_manuscript_table10_summary.R` builds `tables/manuscript_table10_summary.csv` (base-case
  cost + PSA-derived clinical-outcome means, one row per strategy). Deliberately reads the
  already-saved `tables/probabilistic_sensitivity_draws.csv` rather than calling
  `run_probabilistic_sensitivity()` again, since that function is unseeded and a fresh call would draw
  a different 1,000 simulations than the ones the manuscript's Results text was written from --
  reintroducing the same same-document inconsistency already caught once while drafting
  `docs/manuscript_methods_results.md` (see that file's git history).
- `DiagrammeR`, `DiagrammeRsvg`, and `rsvg` were added to `R/00_source_all.R`'s `required_packages`,
  needed only for the decision-tree figure.

**Reference verification (2026-08-31):** two citations flagged `[VERIFY]` when the manuscript qmd files
were first drafted were independently confirmed directly against the primary source:

- Ladabaum U et al. Strategies to identify the Lynch syndrome among patients with colorectal cancer: a
  cost-effectiveness analysis. Confirmed via PMC3793257: *Ann Intern Med. 2011 Jul 19;155(2):69-79.*
  Exactly as drafted -- no correction needed.
- Childers CP, Maggard-Gibbons M. Understanding costs of care in the operating room. Confirmed via
  PubMed 29490366: *JAMA Surg. 2018 Apr 18;153(4):e176233.* Exactly as drafted. The same primary-source
  read also cross-validated this repository's own `direct_room_cost_per_minute` ($20.90) and
  `procedure_room_cost_per_minute` ($36.14) parameters: the abstract's reported ambulatory-setting
  figures -- "$36.14 ($19.53)" total and "$20.90 of $35.39" direct-expense share -- match both
  parameters' base values exactly.

**Figure/table selection finalized** at 5 of 5 slots (Original Research's combined limit): Table 1
(parameters/assumptions), Table 2 (base-case cost + clinical-outcome summary, new), Figure 1 (decision
tree, new), Figure 2 (PSA histogram), Figure 3 (geographic sensitivity). The remaining ~10 existing
analysis outputs are proposed for Supplemental Digital Content, explicitly exempted from the combined
limit per the Instructions for Authors.

## Geographic sensitivity analysis (2026-08-31)

`R/geographic_sensitivity.R` re-prices the base-case strategies at four localities using real CMS
geographic-adjustment data -- no GPCI, wage index, or RVU value is invented. Deliberately kept
deterministic (not part of `run_probabilistic_sensitivity()`): geography is a "does the conclusion
generalize elsewhere" question, not a parameter-uncertainty question.

**Data sources, all downloaded directly from cms.gov 2026-08-31:**

- **GPCI** (`data/cms_geographic_indices_2026.csv`'s `gpci_work`/`gpci_pe`/`gpci_mp` columns) --
  `GPCI2026.csv`, part of the RVU26C package (`cms.gov/medicare/payment/fee-schedules/physician/
  pfs-relative-value-files/rvu26c`, `files/zip/rvu26c-updated-06-30-2026.zip`), "ADDENDUM E. FINAL
  CY 2026 GEOGRAPHIC PRACTICE COST INDICES (GPCIs) BY STATE AND MEDICARE LOCALITY."
- **RVUs** (`data/cms_pfs_rvus_2026.csv`) -- `PPRRVU2026_Jul_nonQPP.csv`, same RVU26C package,
  "2026 National Physician Fee Schedule Relative Value File July Release." Work/practice-expense
  (nonfacility and facility separately)/malpractice RVUs, by CPT and setting.
- **OPPS wage index** (`opps_wage_index` column) -- FY2026 IPPS Final Rule (CMS-1833-F) Table 3,
  "WAGE INDEX TABLE BY CBSA" (`cms.gov/files/zip/fy2026-ipps-fr-tables-2-3-4a-4b.zip`), Reclassified
  Wage Index column. OPPS uses the IPPS post-reclassification wage index for its own facility-payment
  geographic adjustment.
- **OPPS labor-related share** (0.60, used as `labor_share` in `facility_mapping`) -- Federal Register,
  CY 2026 OPPS/ASC final rule with comment period (document 2025-20907, published 2025-11-25). Exact
  quote, verified by reading the full text directly: "The OPPS labor-related share is 60 percent of the
  national OPPS payment. This labor-related share is based on a regression analysis that determined
  that, for all hospitals, approximately 60 percent of the costs of services paid under the OPPS were
  attributable to wage costs."

**The four localities** (`data/cms_geographic_indices_2026.csv`), chosen per the collaborator's own
suggestion (national / Denver-Colorado / a low-cost locality / a high-cost locality):

| locality_id | Physician GPCI locality (statewide unless noted) | Physician GPCIs (work/PE/MP) | OPPS wage-index area | OPPS wage index |
| --- | --- | --- | --- | --- |
| `national` | -- (synthetic, all GPCIs = 1.0) | 1.000 / 1.000 / 1.000 | -- (synthetic) | 1.0000 |
| `colorado` | Colorado (statewide Medicare physician locality) | 1.012 / 1.064 / 0.781 | Denver-Aurora-Centennial, CO (CBSA 19740) | 1.0542 |
| `low_cost` | Arkansas (statewide) | 1.000 / 0.859 / 0.515 | Arkansas statewide/rural (CBSA 04) | 0.8187 |
| `high_cost` | Manhattan, NY (a specific physician locality, not statewide) | 1.064 / 1.162 / 1.586 | New York-Jersey City-White Plains, NY-NJ (CBSA 35614) | 1.3697 |

**A real, disclosed limitation:** Medicare's physician-fee-schedule geography (GPCI, by Medicare
"locality," often statewide) and hospital-facility geography (OPPS wage index, by CBSA/metro area) are
two genuinely different CMS systems that do not share a common geographic unit. Colorado's GPCI is
literally statewide (every Colorado provider shares one locality) while the OPPS wage index used
alongside it is Denver-metro-specific; Arkansas's GPCI and wage index are both genuinely statewide
(a clean pairing); Manhattan's GPCI is borough-specific while its paired OPPS wage index covers the
broader New York-Jersey City-White Plains metro. This is not a data-quality shortcut -- it is the most
faithful pairing possible given how CMS's own two systems are actually structured, and is disclosed
here rather than presented as if "Denver" meant one single, unified geography in both systems.

**Parameters adjusted, and why others are deliberately not (yet):** `professional_mapping` covers only
`emb_office_professional_cost` (CPT 58100, nonfacility), `emb_office_professional_cost_facility` (CPT
58100, facility), and `dc_professional_cost` (CPT 58120, facility) -- the three professional fees with
a directly verified CPT/setting RVU match. `emb_pathology_cost` (CPT 88305), `office_visit_em_cost`/
`dnc_preop_clinic_visit_cost` (E/M codes), and `dnc_anesthesia_cost` are deliberately NOT
geographically adjusted this round -- their exact Medicare payment/setting treatment (e.g. whether the
malpractice GPCI-bearing procedure code is the right RVU source for a pathology or anesthesia service)
has not been verified, and the architecture (an additional `professional_mapping` row) supports adding
them later without changing any function. `facility_mapping` covers only `dnc_facility_or_asc_fee`,
using `opps_wage_index` (matching that parameter's own OPPS-sourced base value) and the real, verified
0.60 labor-related share -- validation deliberately fails (rather than silently defaulting) if this
value were ever left unsourced.

**The critical validation, run first:** the `national` locality's GPCIs and wage index are all 1.0 by
construction, so it must reproduce `compute_strategy_costs()`'s own base-case output exactly. Confirmed
both by an automated test (`tests/testthat/test-geographic-sensitivity.R`, INDEPENDENT-CONFIRMATION-
flavored, mutation-tested) and by the actual analysis run: national locality produced $506.11 /
$761.94 / $3,839.81 (combined/office/D&C), exactly matching `analysis/01_base_case.R`'s output.

**Result** (`Rscript analysis/09_geographic_sensitivity.R`): combined EMB remained the least expensive
strategy in all 4 of 4 localities. Combined-vs-office savings ranged from $207.12 (Arkansas, the
low-cost locality) to $348.75 (Manhattan, the high-cost locality) per patient -- i.e. the base case's
qualitative conclusion (combined EMB cheaper than office EMB) is not an artifact of national-average
pricing; it holds, and if anything strengthens, at both geographic extremes tested. See
`tables/geographic_sensitivity_summary.csv` for the full table and
`tables/geographic_adjustment_audit.csv` for every individual GPCI/wage-index multiplier applied.

## Provisional placeholders with no source yet

| Parameter | Base value | What's needed |
| --- | --- | --- |
| `coordination_cost` | $22.08 | Wage component now real (O*NET/BLS OEWS, SOC 43-6013, $22.08/hr median, see `scheduler_hourly_wage_onet_2025`); the 30-min-per-scheduler time component is a practitioner estimate (Tyler Muffly, MD, Denver Health), not an independently published source. Ahsan et al. 2022's Weill Cornell implementation commentary (see "Next literature to mine" item 5 below) describes the same kind of stakeholder-coordination workflow qualitatively but reports no time or cost figures, so it does not resolve this gap. A formal micro-costing/implementation-cost study of actual coordination time would still improve on the time component specifically |
| ~~`office_to_dnc_escalation_fraction`~~ **SUPERSEDED 2026-09-02** | ~~100%~~ | No longer a placeholder: replaced by `office_repeat_attempt_fraction` (5%, Yi et al. 2018) and `office_repeat_attempt_success_probability` (25%, Adambekov et al. 2017 Table 1, n=8) -- both real, sourced values, though from a small, general (non-Lynch) evidence base rather than a Lynch-specific standalone-office measurement. See "Interpretation of delayed-neoplasia outcomes" in `docs/methods_notes.md` for the full account. Remaining gap: still no Lynch-specific citation for either parameter. |

**`dnc_recovery_room_cost` was removed from this list, not filled in.** Per MedPAC's Ambulatory
Surgical Center Services Payment System documentation (payment basics, rev. Nov 2021): "Medicare pays
for facility services provided in ASCs -- such as nursing, recovery care, anesthetics, drugs, and
other supplies -- using a payment system that is primarily linked to [OPPS]... Within each APC, CMS
packages most ancillary items and services with the primary service." Recovery-room/PACU time is
therefore already inside `dnc_facility_or_asc_fee`; `compute_dnc_strategy_cost()` no longer sums it
separately (as of 2026-08-28), and `dnc_recovery_room_cost` is kept in the parameter table only as a
documented, explicitly-excluded reference value with a regression test
(`tests/testthat/test-strategy-costs.R`) enforcing the exclusion.

## Next literature to mine, in priority order

This list reflects the priority ranking developed during model design, highest-yield first.

1. ~~Yi et al. 2018~~ **DONE (2026-08-31)** -- full-text obtained via institutional access; Table 1's
   complete parameter set extracted and documented in `docs/validation_notes.md`. Turned out not to
   be a viable numeric-replication target (its decision tree models diagnostic accuracy and
   life-expectancy effectiveness that this repository's cost-only engine doesn't implement) -- see
   `docs/validation_notes.md` for the full comparison and the two real cost anchors it did yield
   (`cost_pipelle_yi2018`, `cost_dc_yi2018`), plus a real supporting citation for
   `office_to_dnc_escalation_fraction` (95% of failed Pipelle attempts move to D&C, per Yi et al.'s
   own Table 1).
2. ~~Munro et al. 2022~~ **DONE (2026-08-31)** -- full text obtained (open access, CC BY). Table 1
   confirms the three reference values above exactly ($1,382.48 / $1,655.31 / $2,918.10). The paper's
   further cost decomposition (Tables 2A-2D: per-vendor hysteroscope/camera/monitor pricing,
   depreciation schedules, and net-practice-revenue-by-case-volume modeling) answers a different
   question -- which hysteroscopic system/instrument a practice should purchase and at what case
   volume it becomes profitable -- not this repository's EMB-vs-D&C setting comparison, so it was
   deliberately not mined further into new parameters.
3. ~~The 2024 NIHR Lynch systematic review and economic model~~ **REVIEWED, NOT INCORPORATED
   (2026-08-31)** -- the review's own "Costs" section (whole-disease economic model chapter) was
   located and read in full. Its gynaecological-surveillance costs are UK NHS tariffs (Healthcare
   Resource Groups) in GBP, 2021-2 price year: hysteroscopy-with-biopsy-and-TVUS £279.53 (HRG MA46Z,
   inflated from £264.02 in 2019/20 prices), plus CA-125 testing £49.60 = £329.13 combined; TVUS alone
   with CA-125 £220.86; colorectal surveillance colonoscopy £593.37-£749.29 (HRGs FE32Z/FE30Z);
   risk-reducing hysterectomy/BSO £4,660.22-£6,281.03; all costed with gamma distributions at a 10%
   coefficient of variation. Not extracted into new parameters for two compounding reasons: (1) these
   are NHS tariff costs in a different currency and payer system than this repository's US
   CMS-allowed-amount basis -- a GBP-to-USD conversion would introduce exchange-rate and
   health-system-structure noise, not resolve it; (2) the surveillance costs are bundled procedures
   (hysteroscopy + TVUS, or + CA-125) rather than a standalone EMB Pipelle cost comparable to this
   repository's office_emb/combined_emb/dnc arms. `emb_failure_lynch` and
   `hysteroscopy_failure_rate_lynch_range` remain the only parameters sourced from this review.
4. ~~The original Lynch surveillance studies~~ **DONE (2026-08-31)** -- full text of Lecuru, Elmasry,
   and Rijcken obtained via institutional access (Woolderink was already open access). This is what
   caught the `emb_failure_lynch` correction above: Elmasry's true count is 5/25 not 6/25, and Rijcken
   is not a Pipelle-specific study at all. Still not found in any of the four, even with full text in
   hand: a reported repeat-office-attempt-vs-D&C-escalation pathway (see
   `office_to_dnc_escalation_fraction`) or a "cannot access the endometrium" vs. "inadequate specimen"
   breakdown the way Adambekov et al. reported for the general population -- this is a genuine gap in
   what these studies measured, not an access barrier.
5. ~~ONCE 2025~~ **REVIEWED, NOT INCORPORATED (2026-08-31)** -- Frissora et al., One-Stop Colon and
   Endometrial Screening (ONCE): a prospective study of combined cancer screening for Lynch syndrome.
   Proc (Bayl Univ Med Cent) 2025;38(5):646-649. Full text obtained. Reports mean combined-procedure
   duration 42 minutes (range 27-59) and mean total OR/suite time 54 minutes (range 37-93) in n=20
   Lynch patients, with "the EMB typically takes less than 10 minutes" -- directionally consistent
   with, but less granular than, Huang et al. 2011's Table-reported median 5 min (range 1-12) already
   used for `combined_emb_added_minutes`, since ONCE reports total combined-session time rather than
   an isolated EMB-added-time measurement. No cost data and no EMB failure-rate data (0% of patients
   reported pain; the study's only "failure"-adjacent finding is unrelated -- one incidental stage IA
   endometrial cancer diagnosis). Not used to change any parameter; logged here as a second,
   independent, converging real-world time observation for `combined_emb_added_minutes`.
   The originally hypothesized companion citation "Weill Cornell implementation framework
   (ScienceDirect S1048891X2401017X)" could not be located or verified by any search method tried
   (PubMed keyword search, general web search) and should be treated as an unconfirmed/likely
   erroneous citation -- **not** a real source. What the user actually located and downloaded instead
   is a different, real Weill Cornell paper: Ahsan MD et al., "Combining endometrial biopsy with colon
   cancer screening for patients with Lynch syndrome: framework for establishing a patient-centered
   approach." Int J Gynecol Cancer 2022;32:818-819 (doi:10.1136/ijgc-2022-003355) -- a commentary
   describing a 4-step institutional rollout process (stakeholder identification; equipment/tray
   setup; OR-scheduling workflow; staff education sessions) for launching a combined GI+GYN Lynch
   screening program. Purely qualitative/process description, no cost, time, or failure-rate figures
   -- not extractable into any parameter, but consistent with and supportive of this repository's
   `combined_requires_preop_office_visit` and `coordination_cost` modeling choices (both reflect the
   same kind of institutional coordination burden this commentary describes). The `coordination_cost`
   citation above previously misattributed this framework to a nonexistent ScienceDirect/Value in
   Health PII; that citation is corrected here.
6. ~~Office-vs-OR hysteroscopy literature for external validation~~ **PARTIALLY DONE (2026-08-31)** --
   the University of Florida analysis (Moawad et al. 2014, JSLS, PMC4154435/e2014.00393) was obtained
   and its office ($1,356) and all-OR ($4,946) procedure-charge figures added as
   `cost_hysteroscopy_office_moawad_2014` / `cost_hysteroscopy_or_moawad_2014` (see above); its
   office-first-with-OR-rescue-vs-all-OR framing ($3,448 vs. $4,946, saving $1,498 per patient, 95% CI
   $1,051-$1,923) is structurally close to this repository's own office_emb-vs-dnc comparison, though
   for diagnostic hysteroscopy (CPT 58555) in a non-Lynch abnormal-uterine-bleeding population rather
   than Pipelle EMB in Lynch surveillance -- kept as reference-only for that reason. The seven-study
   systematic review/meta-analysis (PubMed 30528838, outpatient $97-$1,258 vs. OR $258-$3,144) was not
   pursued this round.
7. **Patient time-cost literature** (colonoscopy time-and-motion studies, e.g. PubMed 18263561 and
   PMC5847315) -- mean patient-occupied time of 23.2-28.8 hours and $335-$432 in lost time/caregiver
   cost per colonoscopy episode. Not used in the current payer-perspective base case, but directly
   relevant to the patient-time/societal perspective this repository's structure is designed to add
   later without restructuring (see the README's "Extending this model" section) -- and to the
   specific argument that the combined arm's *incremental* patient burden is close to zero, since the
   colonoscopy trip is already being made.

## What should not be conflated

- **Medicare reimbursement, hospital cost, and charges are conceptually distinct**, per the user's
  original instruction. Every dollar figure currently in this model is a Medicare-anchored
  reimbursement or allowed-amount figure (CMS PFS lines) or a cost-accounting estimate (the JAMA
  Surgery OR-cost-per-minute study). None of it is a hospital charge. If hospital charge data is
  added later, it should get its own `dollar_year`/`source`-tagged parameter track, not overwrite an
  existing reimbursement-based value.
- **The Ladabaum-2010 track and the CMS-2026 track answer different questions** and are kept in
  separate parameters (`cost_emb_ladabaum_2010` vs. `emb_office_professional_cost`) for exactly this
  reason -- see `R/scenarios.R`'s `office_cost_ladabaum_historical` scenario for the one place they
  are deliberately brought together, with the inflation adjustment made explicit rather than implied.
