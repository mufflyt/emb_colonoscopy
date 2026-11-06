# Appendix

Supplementary material that doesn't fit cleanly into the other `docs/` files, plus a
navigation index now that there are several of them.

## Documentation index

| File | Covers |
| --- | --- |
| [`README.md`](../README.md) | Clinical problem, base-case result, repo structure, quick start |
| [`CHANGELOG.md`](../CHANGELOG.md) | Exhaustive technical log of every addition/change/fix/removal, by date |
| [`NEWS.md`](../NEWS.md) | User-facing highlights of the same history |
| [`docs/reuse_mapping.md`](reuse_mapping.md) | Component-by-component mapping of what was reused/adapted/newly built from `colpocleisis_costeff` |
| [`docs/data_sources.md`](data_sources.md) | Full parameter provenance, open data-quality flags, prioritized list of literature still worth mining |
| [`docs/methods_notes.md`](methods_notes.md) | The incremental-cost principle, decision-tree structure, cost-minimization-vs-cost-effectiveness framing, simplifying assumptions |
| [`docs/validation_notes.md`](validation_notes.md) | Why Yi et al. 2018 is not numerically reproduced, and what a real replication would require |
| [`docs/evidence_layers.md`](evidence_layers.md) | The CMS/HPT/MEPS public-data layer: what exists, what was dropped (APCD, CMS facility) and why, three real bugs caught during review |
| [`docs/testing_philosophy.md`](testing_philosophy.md) | Two CI meta-rules: prove every blocking test fails-then-passes on a planted defect; independently re-derive any study-frame-changing finding. Worked log of twenty-five real mutation tests. |
| [`docs/saboteur_tests.md`](saboteur_tests.md) | Adversarial test suite: the SURVIVES/BREAKS taxonomy, every tested breakpoint, the two defects found by attacking the result, and the documentation-drift guards |
| [`docs/ae_cost_evidence_table.md`](ae_cost_evidence_table.md) | Management-pathway-based adverse-event costing evidence table (uterine perforation, severe hemorrhage) -- what's sourced, what's explicitly unsourceable, and why. Not yet wired into any cost function. |
| `docs/appendix.md` (this file) | Bug-reproduction record, CI workflow notes, provenance of the evidence-layer code, raw CMS source-file inventory |

## Independent PSA verification script

`analysis/12_independent_psa_verification.R` formalizes, as a reusable repository script, the
independent re-derivation described in `docs/testing_philosophy.md`'s Rule 2 as applied to the
manuscript's clinical-outcome claims. It was originally written and run ad hoc (in a scratch
location, not tracked by the repository) while verifying the manuscript's Results/Discussion
numbers before submission; it is preserved here so the same check can be re-run whenever
`tables/probabilistic_sensitivity_draws.csv` is regenerated, rather than being reconstructed from
scratch each time. It is read-only and does not call any function from `R/`.

## Raw CMS source files (not committed)

The geographic sensitivity analysis (`R/geographic_sensitivity.R`) and several Direct
Practice Expense-sourced cost parameters (see `docs/data_sources.md`) are built from real,
downloaded CMS packages. The distilled values these packages produced are committed
(`data/cms_geographic_indices_2026.csv`, `data/cms_pfs_rvus_2026.csv`, and the individual
parameter values in `config/model_parameters.csv`); the raw packages themselves are not,
because they are large (tens of MB across ZIP archives and spreadsheets) and are official
CMS public-use files that can be re-downloaded from the URLs already cited in
`docs/data_sources.md` rather than vendored into this repository. For traceability, the
packages consulted while building this model's geographic and Direct-PE parameters were:

- `RVU26C` (GPCI and RVU values) -- `cms.gov/medicare/payment/fee-schedules/physician/
  pfs-relative-value-files/rvu26c`
- FY2026 IPPS wage-index tables (OPPS wage index by core-based statistical area) --
  the FY2026 IPPS/OPPS final rule's published wage-index files
- `CMS-1832-F` Direct PE Inputs PUFs (Equipment, Labor, Labor Task Detail, Supply,
  Summary) -- the CY2026 Physician Fee Schedule Final Rule's Direct PE Inputs file,
  already cited by HCPCS code in `docs/data_sources.md`

If these need to be re-verified or re-derived from scratch, re-download the current-year
version of each package from CMS rather than assuming last year's cached copy still
matches the live rule -- CMS revises these files with dated addenda.

## Provenance of the evidence-layer code

`R/cms_benchmarks.R`, `R/hpt_prices.R`, `R/meps_burden.R`, `R/evidence_codes.R`,
`R/evidence_synthesis.R`, and `R/evidence_provenance.R` originated as a standalone
scaffold generated in a separate AI-assisted session (not this one) and handed off as
a zip archive. Before any of it was merged into this repository it was fully read,
run against synthetic and, where possible, live public data, and had three real bugs
found and fixed -- see "Bug reproductions" below and `docs/evidence_layers.md`. An
APCD (claims-linkage) module from that same scaffold was reviewed, fixed, verified
working on synthetic data, and then removed entirely (not merged) once it became
clear this project has no APCD data use agreement to point it at.

## Bug reproductions

These are preserved as a historical record of what was caught during review, in a
form that doesn't depend on any file currently in the repository (the APCD module
they originally lived in was removed -- see `docs/evidence_layers.md`). If an APCD
layer is rebuilt later, re-derive equivalent tests from these reproductions rather
than reintroducing the same bugs.

### Bug 1: data-masking name collision

```r
# BROKEN: the bare `concept` on the right of %in% resolves to the DATA COLUMN
# named `concept` (dplyr's data-masking prefers the data mask over the calling
# environment for bare symbols), not the function argument -- so this returns
# every code in the codebook regardless of what was requested.
sampling_code_vector_broken <- function(concept) {
  sampling_codebook() |>
    dplyr::filter(.data$concept %in% concept) |>
    dplyr::pull(.data$code) |>
    unique()
}

# Reproduction: sampling_code_vector_broken("dc") returns ALL 12 codes in the
# codebook, not just "58120".

# FIXED: .env$concept forces resolution against the calling environment.
sampling_code_vector_fixed <- function(concept) {
  sampling_codebook() |>
    dplyr::filter(.data$concept %in% .env$concept) |>
    dplyr::pull(.data$code) |>
    unique()
}
# sampling_code_vector_fixed("dc") correctly returns "58120" only.
```

This one was consequential: it made every episode in the (since-removed) APCD
episode-classification function get labeled `"combined_colonoscopy_emb"` regardless
of what codes were actually billed, because `has_dc_line`/`has_hyst_line`/etc. were
all `TRUE` for every row.

### Bug 2: reversed inequality-join columns

```r
# BROKEN: dplyr::join_by(x_col OP y_col) resolves x_col against the LEFT
# table's columns and y_col against the RIGHT table's columns. This wrote it
# backwards -- `rescue_date` doesn't exist in the left (index) table, and
# `service_date`/`followup_end` don't exist in the right (rescue) table.
dplyr::left_join(
  index_tbl, rescue_tbl,
  by = dplyr::join_by(
    source, member_id,
    rescue_date > service_date,      # wrong side
    rescue_date <= followup_end       # wrong side
  )
)
# Errors immediately: "Join columns in `x` must be present in the data."

# FIXED:
dplyr::left_join(
  index_tbl, rescue_tbl,
  by = dplyr::join_by(
    source, member_id,
    service_date < rescue_date,
    followup_end >= rescue_date
  )
)
```

### Bug 3: CMS API silently ignores an invalid filter field

Not a bug in this repository's original design so much as an undocumented behavior
of the public CMS data-api, discovered while trying to add a facility-cost layer:
filtering on a field that doesn't exist in the target dataset (`HCPCS_Cd` against a
dataset actually keyed by `APC_Cd`) returns the **entire unfiltered dataset** rather
than an error or an empty result. A request for one CPT code returned 116,182 rows.
`R/cms_benchmarks.R::cms_query_hcpcs()` now checks that the requested filter field is
actually present in the response and raises an error if not -- see
`docs/evidence_layers.md` for the full account.

## CI workflow

`.github/workflows/r-tests.yml` runs on every push and pull request to `main`:

1. Checks out the repository.
2. Installs R via `r-lib/actions/setup-r` (with RStudio Package Manager binaries for
   speed on Ubuntu).
3. Installs the `samevisit` package (this repository's `R/`, via its `DESCRIPTION`) and
   everything it depends on, via `r-lib/actions/setup-r-dependencies` with
   `extra-packages: local::.`.
4. Runs `Rscript tests/testthat.R`.

The suite is fully offline -- no test calls the live CMS API or requires local
HPT/MEPS files -- so CI runs are deterministic and don't depend on external service
availability. If tests are added later that do need network access (e.g. an
integration test against the live CMS API), gate them behind
`Sys.getenv("CI") != "true"` or an explicit opt-in flag so a transient network issue
at data.cms.gov doesn't fail every PR.

To extend this workflow later: add a second job for `R CMD check`-style linting
(e.g. `lintr`), or a matrix build across R versions, once the project's dependency
surface stabilizes. Not added now because it would be speculative infrastructure for
a check this repository doesn't yet need.

## Development test harness (`tests/run_without_install.R`)

`tests/testthat.R` is the canonical runner and the one CI uses. It requires `samevisit`
to be installed, which is the right precondition to enforce before a release but a slow
loop when iterating on a single test. `tests/run_without_install.R` sources `R/*.R`
directly instead, so what runs is the working tree rather than the installed library:

```sh
Rscript tests/run_without_install.R                     # whole suite
Rscript tests/run_without_install.R test-saboteurs.R    # one file
```

Like `analysis/12_independent_psa_verification.R`, this started life as an untracked
scratch script (written while adding `tests/testthat/test-saboteurs.R`, where the
install-then-test cycle dominated the iteration time) and is preserved here rather than
reconstructed from memory each time.

Two limitations are deliberate and are repeated in the script's own header. Sourcing is
not installing, so namespace collisions, missing `@importFrom` declarations, and
`R CMD check` problems are invisible by construction; a green run here is not a
substitute for `Rscript tests/testthat.R`, and is not what the badge reports. And the
script attaches the Imports it needs itself, so a new load-time dependency in
`DESCRIPTION` has to be added to its `required_packages` vector.

## Incident record: eight weeks of stale figures in `docs/` and `README.md` (found 2026-11-06)

**What happened.** Commit `471e067` (2026-09-12, "Finalize manuscript for submission")
updated two parameters from live CMS PUF queries -- `emb_pathology_cost` from $70.14 to
$50.75 and `dc_professional_cost` from $209.76 to $212.13 -- regenerated `tables/` and
`figures/`, and verified every number cited in the manuscript against the re-run
pipeline. It did not touch `docs/` or `README.md`. Those files went on quoting the
previous run for eight weeks.

**What was wrong.** The entire derived set, because both parameters feed every strategy
total: combined $506.11 (actual $485.11), office $749.18 ($727.48), D&C $3,839.81
($3,822.79), margin $243.06 / 32.4% ($242.36 / 33.3%), the PSA win rate 91.4% (91.8%)
and its complement 8.6% (8.2%), PSA means and intervals for both office and combined
arms, all four ICERs, the one-way sensitivity bounds, budget impact at all five cohort
sizes, the geographic savings range $195.62-$333.44 ($194.89-$332.78), the societal
add-ons, the repeat-visit cost $255.93 ($236.54), the combined arm's room-time component
$143.67 ($142.55), and the D&C adverse-event pass-through.

**Why it took eight weeks to notice.** Nothing could notice. The manuscript was verified
against the pipeline; `docs/` never was. A reader checking any figure in `docs/` against
`tables/` would have found the mismatch immediately, and nobody had reason to.

**What was done.** All current-results figures were corrected against `tables/`, after
re-running the model to confirm `tables/` was the authoritative side rather than assuming
it. Four historical change-narratives kept their original numbers and received a dated
`> **Historical figures (pre-2026-09-12).**` block instead, because restating them would
falsify the record of what the model said when each change was made. Three
documentation-drift guards were added to `tests/testthat/test-saboteurs.R` and
mutation-tested; see [`docs/saboteur_tests.md`](saboteur_tests.md). The guards, not the
corrections, are the actual fix: hand-syncing prose against generated tables would simply
rot again on the next parameter update.

**Also found in the same pass.** Reference 8's author list was wrong in four files. The
manuscript read "Yi Y, Yi Y, Bryce CL, et al.", a duplicated first author introduced by
an earlier correction pass that was itself fixing a wholly fabricated "Yi Y, Lu Y, Wu J";
`config/model_parameters.csv` and `tables/manuscript_table1_parameters.csv` still carried
the fabricated version. PubMed 29747864 gives the real list: Yi Y, Bryce CL, Adambekov S,
Edwards RP, Goughnour SL, Linkov F. Corrected everywhere, with the full history preserved
in `manuscript/manuscript.qmd`'s provenance comment. Note that Adambekov being a Yi
co-author explains Yi et al.'s self-citation to Adambekov et al. 2017 for the
sampling-success probability in their Table 1.

**Still outstanding.** `manuscript/manuscript.docx` and `manuscript/manuscript_slides.pptx`
are rendered artifacts and still carry the old author string; re-render before submission.
Separately, `emb_colonoscopy/R/` and `mufflyt/samevisit`'s `R/` are byte-identical copies
with no `Imports:` relationship between them, so they will drift, and the published
numbers will not record which copy produced them.
