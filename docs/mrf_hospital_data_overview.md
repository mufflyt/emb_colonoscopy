# MRF hospital data: what it is, why we got it, how we got it, and the full hospital list

A single orientation page for the two real-hospital payer-rate datasets in `data/`.
`docs/data_sources.md` remains the detailed, chronological provenance log (the full
verification history, column-by-column); this page is the "what is this and which
hospitals" summary a reader should start with instead of searching that longer log.

## What an MRF is

An **MRF (machine-readable file)** is a dataset every U.S. hospital is legally required
to publish under the CMS **Hospital Price Transparency Rule (45 CFR 180)**. It lists, for
essentially every service and procedure the hospital bills, the actual rate it has
individually negotiated with each insurer -- gross charge, cash/self-pay price, and a
separate negotiated rate per payer. It is the only public window into what hospitals
actually get paid by commercial insurers and Medicaid managed-care plans, since CMS only
publishes what Medicare itself pays (uniform nationwide, GPCI-adjusted) -- not what
private payers pay.

## Why we got them

The base-case model prices everything off CMS Medicare-allowed amounts, because that is
the one figure that is public, uniform, and auditable everywhere. But Medicaid and
commercial rates vary hospital to hospital and are not published by CMS -- MRFs are the
only way to see that real-world variation for this model's actual procedures (EMB,
pathology, D&C, colonoscopy). Two separate efforts did this, for two different reasons:

- **An opportunity-cost sensitivity check (6 hospitals)** -- bounding what displacing a
  colonoscopy-suite slot for a combined-EMB add-on could reasonably cost, using each
  hospital's own commercial-vs-Medicare margin. Feeds
  `analysis/16_opportunity_cost_colonoscopy.R`.
- **A broader real-world cross-check (74 hospitals)** -- testing whether the base case's
  Medicare-only pricing looks reasonable against actual negotiated rates at a large,
  clinically relevant sample of hospitals, since the original 6-hospital sample was just
  a convenience sample.

**Neither dataset feeds `config/model_parameters.csv` or the base-case cost engine** --
both are standalone, documented sensitivity/validation exercises, not inputs to the
headline result.

## How we got them

1. **Pick a sampling frame, not a convenience sample.** For the 74-hospital pull, we used
   **FREIDA** (the AMA's residency/fellowship directory) to get all 75 ACGME-accredited
   **gynecologic oncology fellowship programs** -- tied directly to this study's clinical
   population (the clinicians who actually perform this surveillance), not an arbitrary
   "big hospitals" list.
2. **Find each hospital's MRF** via its `cms-hpt.txt` discovery index (a standardized,
   CMS-required pointer file most hospitals publish).
3. **Download and extract**, tiered by file size -- small files parsed directly,
   multi-GB files grepped/streamed for the five target codes (58100, 88305, 58120, 99213,
   colonoscopy) rather than loaded whole.
4. **Flag data quality honestly rather than smoothing it over**: placeholder rates
   identical to gross charge, rates with zero real claims, bundled/case-rate values
   repeated across unrelated codes, duplicate chargemaster lines, and payers mislabeled
   "commercial" that are actually Medicare Advantage or Medicaid managed care -- all get
   flagged in a `notes`/`confidence` column rather than silently accepted or dropped.

Full step-by-step method: `docs/vignettes/02_adding_a_new_hospital_payer_rate.md`
(narrative) and `vignettes/adding-a-hospital-payer-rate.Rmd` (the same topic, with the one
part of it that's real executable R). Full per-hospital provenance and the complete
column schema: `docs/data_sources.md`'s "Hospital payer-rate sample expansion" section.

## The hospital lists

### Original 6-hospital sample

`data/colonoscopy_multi_hospital_rates.csv` -- a convenience sample, predates the
FREIDA-based sampling frame below.

| Hospital | State |
|---|---|
| Denver Health Medical Center | CO |
| UCHealth University of Colorado Hospital | CO |
| Emory University Hospital | GA |
| University of Mississippi Medical Center | MS |
| University of Arkansas for Medical Sciences | AR |
| NYU Langone Hospitals (Tisch) | NY |

### 74-hospital FREIDA sample

`data/gyn_onc_hospital_payer_rates.csv`, drawn from the 75-program FREIDA sampling frame
(`data/gyn_onc_fellowship_programs_freida.csv`; one duplicate excluded, leaving 74
attempted). 41 returned usable data on every target code, 26 on some codes, and 7
returned none.

**41 hospitals -- usable data on every target code:**

Allegheny General Hospital (PA); Beth Israel Deaconess Medical Center (MA); Brigham and
Women's Hospital (MA); Cleveland Clinic Foundation, Main Campus (OH); Cooper University
Hospital (NJ); Corewell Health William Beaumont University Hospital (MI); Detroit Medical
Center -- Harper University Hospital (MI); Erie County Medical Center/University at
Buffalo (NY); Froedtert Hospital/Medical College of Wisconsin (WI); H. Lee Moffitt Cancer
Center (FL); Hospital of the University of Pennsylvania (PA); Loma Linda University
Medical Center (CA); Los Angeles General Medical Center, formerly LAC+USC (CA); M Health
Fairview University of Minnesota Medical Center (MN); MUSC Health Main Campus (SC);
Maimonides Medical Center (NY); Massachusetts General Hospital (MA); Memorial Hospital for
Cancer and Allied Diseases/Memorial Sloan Kettering (NY); Montefiore Medical Center (NY);
NYU Langone Hospitals, Tisch (NY); NewYork-Presbyterian/Columbia University Irving Medical
Center (NY); OU Health University of Oklahoma Medical Center (OK); Robert Wood Johnson
University Hospital (NJ); St. Luke's University Hospital (PA); Stanford Health Care,
Stanford Hospital (CA); Strong Memorial Hospital/University of Rochester Medical Center
(NY); Temple University Hospital, Main Campus (PA); The Ohio State University Wexner
Medical Center (OH); UC Davis Medical Center (CA); USA Health University Hospital (AL); UT
MD Anderson Cancer Center (TX); University Health System, San Antonio (TX); University
Hospitals Cleveland Medical Center (OH); University of Chicago Medical Center (IL);
University of Michigan Health, University Hospital (MI); University of New Mexico Hospital
(NM); University of Virginia Medical Center (VA); University of Wisconsin Hospital/UW
Health (WI); Vanderbilt University Medical Center (TN); Women and Infants Hospital of
Rhode Island (RI); Yale New Haven Hospital (CT).

**26 hospitals -- usable data on some target codes** (codes found / codes attempted):

| Hospital | State | Codes found |
|---|---|---|
| AdventHealth Orlando | FL | 4/5 |
| Atrium Health Carolinas Medical Center | NC | 5/6 |
| Barnes-Jewish Hospital | MO | 4/6 |
| Cedars-Sinai Medical Center | CA | 4/5 |
| City of Hope National Medical Center | CA | 5/6 |
| Duke University Hospital | NC | 4/5 |
| Emory University Hospital | GA | 5/6 |
| Jackson Memorial Hospital | FL | 3/6 |
| North Shore University Hospital (Northwell Health) | NY | 5/6 |
| Northwestern Memorial Hospital | IL | 1/6 |
| Regional One Health (UT Tennessee HSC gyn onc surgical site) | TN | 5/6 |
| Ronald Reagan UCLA Medical Center | CA | 4/6 |
| Tampa General Hospital | FL | 4/5 |
| The University of Kansas Hospital | KS | 1/6 |
| UC San Diego Health (Jacobs Medical Center) | CA | 5/6 |
| UCHealth University of Colorado Hospital | CO | 4/5 |
| UCI Medical Center (UC Irvine Health) | CA | 4/5 |
| UCSF Medical Center | CA | 5/6 |
| UNC Medical Center | NC | 2/5 |
| UPMC Presbyterian (shared with Montefiore/Shadyside campuses) | PA | 4/5 |
| University of Alabama Hospital (UAB) | AL | 3/5 |
| University of Iowa Health Care Medical Center | IA | 5/6 |
| University of Kentucky Albert B. Chandler Hospital | KY | 4/5 |
| Wake Forest Baptist Medical Center (North Carolina Baptist Hospital) | NC | 2/6 |
| Wellstar MCG Health (Augusta University Medical Center) | GA | 4/5 |
| William P. Clements Jr. University Hospital (UT Southwestern) | TX | 1/6 |

**7 hospitals -- zero usable data, each for a documented reason:**

| Hospital | State | Why |
|---|---|---|
| Johns Hopkins Hospital | MD | File publishes these codes only as chargemaster gross/cash lines -- no payer-negotiated rate exists at all (confirmed, not a search failure) |
| Mayo Clinic Hospital Rochester | MN | 13.35 GB file, 63% scanned, zero matches -- as conclusive as a partial scan of a file this size gets |
| Mount Sinai Hospital | NY | Bot-protection survived multiple access strategies |
| Tufts Medical Center | MA | Bot-protection survived multiple access strategies |
| University of Washington Medical Center | WA | Bot-protection survived multiple access strategies, including a Wayback Machine fallback |
| IU Health University Hospital | IN | Bot-protection survived multiple access strategies, including a Wayback Machine fallback |
| Walter Reed National Military Medical Center | MD | Federal military treatment facility, structurally exempt from the price-transparency rule under 45 CFR 180 -- no MRF exists to find, a structural non-finding rather than a failed search |

### A cross-check between the two datasets

UCHealth University of Colorado Hospital appears in both datasets, pulled independently
(different pass, different date). The two Medicare rates for colonoscopy (HCPCS G0105)
matched exactly ($916.25) -- a real, independent confirmation that both pulls read the
same underlying hospital-published number correctly.

## Known data-quality issues worth knowing before using either dataset

- Several hospitals' files mislabel a Medicaid managed-care plan's ACA-exchange product
  as generically "Commercial" -- the exchange product itself is commercial, but the
  payer's core identity is a state Medicaid MCO.
- Duplicate chargemaster lines mapping the same CPT code to different gross charges and
  different negotiated rates are common enough that no single hospital-level "the
  commercial rate" exists for some codes without picking a specific line.
- Files over roughly 1-2 GB could only be partially scanned within each pass's time/size
  budget -- a "not found" for a large hospital's file is weaker evidence than a "not
  found" for a small one; see each row's own `notes` for which case applies.
