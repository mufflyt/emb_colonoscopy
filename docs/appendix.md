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
| `docs/appendix.md` (this file) | Bug-reproduction record, CI workflow notes, provenance of the evidence-layer code |

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
3. Installs the package list from `R/00_source_all.R`'s `required_packages` plus
   `testthat`, via `r-lib/actions/setup-r-dependencies` (listed explicitly since this
   repository has no `DESCRIPTION` to resolve dependencies from).
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
