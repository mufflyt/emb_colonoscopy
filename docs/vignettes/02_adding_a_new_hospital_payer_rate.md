# Vignette 2: Adding a new hospital's payer-rate data

This walks through the real process used to build `data/gyn_onc_hospital_payer_rates.csv`
(74 hospitals) and `data/colonoscopy_multi_hospital_rates.csv` (6 hospitals), so the same
approach can be extended to another hospital later. It is a data-collection vignette, not
a model-parameter vignette: nothing described here feeds `config/model_parameters.csv` or
any cost function -- see `docs/data_sources.md`'s explicit "does not feed the base-case
cost engine" caveat, which still applies.

## 1. Why this data exists

The base-case model prices Medicare-allowed amounts from CMS's Physician & Other
Practitioners by Provider and Service PUF. That's deliberate -- it's the one reimbursement
figure that's uniform, public, and auditable nationwide. But Medicaid and commercial payer
rates vary hospital by hospital and are not published by CMS. The CMS Hospital Price
Transparency Rule (45 CFR 180) requires hospitals to publish machine-readable files (MRFs)
of their actual payer-negotiated rates, which is the only public window into that
variation. `docs/data_sources.md`'s "What would it take to get Medicaid/commercial data?"
analysis is the fuller version of this rationale.

## 2. Pick a sampling frame, not a convenience sample

The 74-hospital sample used FREIDA (the AMA's residency/fellowship directory) to identify
all 75 ACGME-accredited gynecologic oncology fellowship programs (specialty code 42941) --
a criterion tied directly to this study's clinical population, not an arbitrary "big
hospitals" list. `data/gyn_onc_fellowship_programs_freida.csv` has the full list
(`program_name,city,state,source,accessed_date`). If you're adding a hospital outside this
frame, say so explicitly in the new row's `notes` column rather than silently blending
sampling frames.

## 3. Find the hospital's MRF

Most hospitals publish a `cms-hpt.txt` file at a standardized, discoverable path -- that's
the first thing to look for. It's an index of the hospital's actual machine-readable file
locations (which are often not where you'd guess from the hospital's main website).

## 4. Download and extract, tiered by file size

Small files (tens of MB) can be downloaded and parsed directly. Large files (multi-GB,
common for health systems with many payer contracts) need a tiered strategy: stream/grep
for the specific CPT codes of interest rather than loading the whole file, and -- this
matters -- verify a backgrounded download actually completed rather than assuming it did.
Silently-dead background jobs were the single biggest source of wasted effort building
this dataset; prefer synchronous, foreground extraction over backgrounding a job you can't
easily check on.

Target codes for the gyn-onc sample were CPT 58100 (office EMB), 88305 (pathology), 58120
(D&C), 99213 (office visit), and the relevant colonoscopy code -- i.e., exactly the codes
in `docs/clinical_coding_reference.md` Section 1, because the point was pricing this
model's actual procedures, not an arbitrary code list.

## 5. Flag data quality honestly -- do not smooth it over

Every row in `data/gyn_onc_hospital_payer_rates.csv` carries a `*_confidence` column
(`high`/`medium_high`/`medium`/`low_medium`/`low`, or `not_found`/`inconclusive`/
`not_applicable` when nothing usable was found) and a free-text `notes` column. Watch for,
and flag rather than discard or silently accept:

- **Placeholder rates** identical to the hospital's gross charge (not a real negotiated
  rate)
- **Zero-historical-claims flags** some MRFs include for rates that have never actually
  been paid
- **Bundled/case-rate values** repeated identically across unrelated CPT codes (a sign the
  file is reporting a package price, not a per-code rate)
- **Duplicate chargemaster (CDM) lines** for the same code
- **Mislabeled payers** -- a row labeled "commercial" that is actually Medicare Advantage
  or Medicaid managed care under a commercial-sounding plan name

`medicare_proxy_type` in the schema distinguishes `FFS` (true traditional Medicare, rare in
these files) from `MA` (Medicare Advantage, the most common Medicare-adjacent rate
actually published) from `not_found` -- never conflate MA with true FFS Medicare in a
summary statistic.

Of the 74 hospitals in the current sample, 7 produced zero usable data for documented,
specific reasons (one has no payer-negotiated rates in its file at all; one is a 13+ GB
file where scanning stopped partway through; four were hard-blocked by bot protection
across multiple retry strategies; one is a federal facility structurally exempt under 45
CFR 180). Recording *why* a hospital failed is as important as recording a hospital that
succeeded -- see `docs/data_sources.md` for the full per-hospital breakdown, and keep that
standard for any hospital you add.

## 6. Cross-validate when you can

The 74-hospital sample and the earlier 6-hospital sample were built independently, months
apart, by different methods. Where they overlapped (UCHealth Colorado, CPT G0105), the
Medicare-allowed amount matched exactly ($916.25) -- a real, load-bearing cross-check that
the extraction method is sound, not a coincidence to skip documenting.

## 7. Document the schema and update the index files

Add a dated section to `docs/data_sources.md` describing the new row(s): purpose, method,
and the same "does not feed the base-case cost engine" caveat. Add a line to
`CHANGELOG.md` (technical) and `NEWS.md` (plain-English) and, if the file count or
description in `README.md`'s "Repository structure" section has gone stale, fix that too.
