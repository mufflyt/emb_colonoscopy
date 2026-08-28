# Data sources and provenance

Every parameter's full provenance lives in `config/model_parameters.csv` (columns: `source`,
`dollar_year`, `provisional`, `notes`). This document summarizes that table, flags the open data
quality issue that needs resolution, and lays out the prioritized list of literature still worth
mining, in the order it was identified during model design.

## Parameters with a real source, wired into the base case

| Parameter | Value | Source |
| --- | --- | --- |
| `emb_office_professional_cost` | $98.20 | CMS PFS 2026, CPT 58100 national nonfacility allowed amount (third-party aggregator) |
| `emb_pathology_cost` | $70.14 | CMS PFS 2026, CPT 88305 (third-party aggregator) |
| `dc_professional_cost` | $209.76 | CMS PFS 2026, CPT 58120 facility professional payment (third-party aggregator) |
| `dnc_facility_or_asc_fee` | $3,307.24 | CMS OPPS Addendum B, July 2026, CPT 58120 (downloaded directly from cms.gov 2026-08-28); low bound $1,738.07 is the real CMS ASC Addendum AA rate, also named as `dnc_facility_fee_asc_2026` |
| `dnc_anesthesia_cost` | $114.50 | CMS PUF 2024, CPT 00952 (ASA crosswalk code for CPT 58120), service-weighted mean across 118 real provider-service rows, 1,936 observed services; low/high are the real p25/p75 |
| `combined_emb_added_minutes` | 5 (1-12) | Huang et al. 2011, PMC3014510 |
| `combined_emb_anesthesia_drug_increment_cost` | $0 | Huang et al. 2011, PMC3014510 |
| `direct_room_cost_per_minute` | $20.90/min (2014) | Childers & Maggard-Gibbons, JAMA Surgery |
| `anesthesia_cost_per_minute` | $3.42/min (2014) | Childers & Maggard-Gibbons, JAMA Surgery |
| `emb_failure_lynch` | 13.7% (pooled) | Elmasry 6/25, Lecuru 12/116, Rijcken 2/17, Woolderink 5/25 (via NIHR review, NBK606812) |
| `combined_to_dnc_probability` | 3.6% (2/55) | Nebgen et al. 2014, PMC4389779 |

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
- `emb_failure_general_adambekov_2017` (22.9%, with an 8/201 access-failure vs. 37/201
  inadequate-specimen breakdown) -- a general (non-Lynch) U.S. Pipelle failure-rate study.
- `emb_failure_general` (11%) and `emb_insufficient_general` (31%) -- a general postmenopausal-bleeding
  meta-analysis (PubMed 26748390), retained as a non-Lynch comparator.
- `hysteroscopy_failure_rate_lynch_range`, `lynch_surveillance_adherence_ladabaum`,
  `combined_screen_adherence`, `office_emb_pain_*`, `combined_emb_pain` -- tagged
  `future_extension`, for effectiveness/adherence/patient-experience extensions this repository does
  not yet implement.

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

## Open data-quality flag: CPT 58558 (hysteroscopy + D&C)

`hysteroscopy_dc_professional_cost` is recorded as **$204.41**, but a separate citation surfaced
during the same literature search reported **$1,269.90** (Q4 2026, a different fee-schedule
aggregator) for the same CPT code. This is most likely a professional-only vs.
professional-plus-facility distinction, but it has **not** been reconciled. The parameter is marked
`provisional` and is not used in the base case (it is a scenario-only alternative to blind D&C); it
should be checked against the CMS Physician Fee Schedule Look-Up Tool directly before it is used for
anything.

## Provisional placeholders with no source yet

| Parameter | Base value | What's needed |
| --- | --- | --- |
| `emb_disposable_supply_cost` | $35 | Pipelle device + tray + prep supply cost (hospital supply chain or CMS supply fee schedule) |
| `office_visit_em_cost` | $110 | Confirmed CMS PFS value for the applicable E/M code (currently a rough CPT 99213 anchor) |
| `coordination_cost` | $25 | A micro-costing or implementation-cost estimate of scheduling/staffing overhead for a combined visit |
| `dnc_preop_clinic_visit_cost` | $150 | Source needed |
| `dnc_recovery_room_cost` | $250 | Source needed (could be re-modeled as recovery-minutes x a per-minute rate) |
| `office_to_dnc_escalation_fraction` | 100% | Lynch-specific data on how often a failed office attempt is repeated in-office vs. escalated |
| `combined_requires_preop_office_visit` | FALSE | Structural scenario assumption, not a literature parameter |

## Next literature to mine, in priority order

This list reflects the priority ranking developed during model design, highest-yield first. None of
these have been extracted into `config/model_parameters.csv` yet.

1. **Yi et al. 2018** (Gynecologic Oncology, PubMed 29747864) -- a U.S. Medicare-payer-perspective
   decision tree comparing Pipelle vs. D&C, reporting $1,897.80 vs. $2,999.11 per patient and
   explicitly modeling sampling failure. This is the single highest-value external validation
   target for this repository's office/D&C arms -- see `docs/validation_notes.md` for why its
   internal parameters (not just its top-line output) need to be extracted before it can be used as
   a real replication check.
2. **Munro et al. 2022** (ScienceDirect S1553465021013261) -- office vs. institutional operative
   hysteroscopy economic model; already contributes the three reference values above, but its full
   cost decomposition (instrumentation, supplies, staffing) has not yet been extracted.
3. **The 2024 NIHR Lynch systematic review and economic model** (NCBI Bookshelf NBK606810/NBK606812)
   -- already the source of `emb_failure_lynch` and `hysteroscopy_failure_rate_lynch_range`; its full
   cost tables (gynecologic surveillance, colorectal surveillance, risk-reducing surgery, downstream
   cancer treatment, gamma-distribution uncertainty with a ~10% coefficient of variation) have not
   been mined beyond those two probabilities.
4. **The original Lynch surveillance studies** (Lecuru, Elmasry, Rijcken, Woolderink) -- currently
   used only via their pooled numerators/denominators (see `emb_failure_lynch`'s notes); reading the
   primary papers could separate "cannot access the endometrium" from "inadequate specimen" the way
   Adambekov et al. did for the general population.
5. **ONCE 2025** (PMC12351693) and the **Weill Cornell implementation framework**
   (ScienceDirect S1048891X2401017X) -- contemporary workflow and micro-costing detail (mean 42-minute
   combined procedure duration, staffing/scheduling/supply requirements) that could refine
   `coordination_cost` and `combined_emb_added_minutes` beyond the 2011 Huang et al. estimate.
6. **Office-vs-OR hysteroscopy literature for external validation** -- a systematic review/meta-analysis
   (PubMed 30528838) reporting outpatient costs of ~$97-$1,258 vs. OR costs of ~$258-$3,144 across
   seven studies, and a University of Florida analysis (PMC4154435) modeling an office-first strategy
   with OR rescue ($3,448 vs. an all-OR $4,946, saving $1,498, 95% CI $1,051-$1,923) -- structurally
   very close to this repository's own decision tree and a second external validation target
   alongside Yi et al. 2018.
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
