# Saboteur tests: attacking the result instead of confirming it

Every other test file in `tests/testthat/` asks whether the model does what its
documented logic says. `tests/testthat/test-saboteurs.R` asks the opposite question:
how hard is it to make the headline finding go away? Each test takes one documented
weakness in the base case, pushes it to an adversarial but *defensible* value, and
records what happens.

"Defensible" is the whole discipline. A test that sets `combined_emb_added_minutes`
to 500 proves nothing, because no reviewer would propose it. A test that sets it to 15
is worth writing, because an endoscopy unit that timed its own suite could assert
exactly that, and the finding does not survive it.

## The two labels

Every test name begins with `SURVIVES` or `BREAKS`, and the distinction governs how a
future failure should be read.

| Label | Meaning | What a failure means |
| --- | --- | --- |
| `SURVIVES` | The conclusion holds under the attack. | A guard was breached. Something that used to be robust no longer is. |
| `BREAKS` | The conclusion genuinely flips. The test pins where. | The breakpoint **moved**. That is news about the model, not necessarily a bug. |

A `BREAKS` test failing is not a regression to be reverted on sight. Read which kind
of test it is before changing anything.

## What survives

- The entire published 1-12 minute range for `combined_emb_added_minutes`.
- `combined_requires_preop_office_visit` set either way, so the conclusion does not
  depend on that structural toggle.
- The published failure-rate bound for `emb_failure_lynch` (10.3%-20.0%).
- A **free** D&C facility (`dnc_facility_or_asc_fee = 0`), and the ASC rate.
- Adopting Yi et al. 2018's own, roughly 52% lower D&C price.
- Any shared cost moved across its whole plausible range, including the parameter
  that actually went stale (`emb_pathology_cost`).
- The upper bound of `direct_room_cost_per_minute`.
- Medicaid and commercial payer multipliers.

## What breaks, and where

These are now tested facts rather than footnotes.

| Attack | Breakpoint | Base case |
| --- | --- | --- |
| Incremental colonoscopy-suite minutes | between **12 and 13** minutes | 5 |
| Office EMB failure probability | between **6% and 7%** | 13.3% |
| Coordination cost | between **$250 and $300** | $22.08 |
| All six anti-combined bounds at once | **flips to office EMB** | -- |

The last row is the one worth dwelling on. One-way sensitivity analysis moves one
parameter at a time, which is precisely how a fragile result survives a tornado
diagram with its reputation intact. Stack `combined_emb_added_minutes` at 12,
`emb_failure_lynch` at 0.103, both per-minute rates at their upper bounds,
`coordination_cost` at its upper bound, and `combined_to_dnc_probability` at its
upper bound, and office EMB becomes the cheapest strategy. Nothing in the manuscript
claims otherwise, and now nothing has to: the joint worst case is asserted in the
test suite rather than waiting to be discovered in peer review.

Note that the two largest breakpoints sit uncomfortably close to the edge of the
observed data. 13 minutes is one minute above the top of the published range, and a
6%-7% office failure rate is entirely plausible for a high-volume operator. Both are
stated as limitations in the manuscript; the tests make them precise.

## A real defect found by attacking

`office_emb_serious_infection_probability` is declared in
`config/model_parameters.csv` with a base value of 0, flagged `provisional`, and
described as reflecting absent incidence data rather than a claim of zero risk. The
saboteur test that tried to perturb it found something worse than a fragile number:
**the parameter is not consumed anywhere in `R/`.** Setting it to 5% changes no
output. Each arm's adverse-event exposure is exactly its D&C-rescue probability times
the D&C complication rate, so the reported 0.36-versus-2.48-per-1,000 contrast
excludes office-side infection entirely.

The first version of that test passed for the wrong reason: it asserted
`expect_gte(perturbed, baseline)`, which an unchanged value satisfies. That is the
characteristic failure mode of a test written against an assumption instead of
against the code. It now asserts the gap explicitly, including a grep over `R/`
confirming the parameter is never referenced, and is written to **fail once the
parameter is wired in** so that nobody has to remember to delete it.

## A misconception corrected by attacking

The first draft of `tests/testthat/test-sensitivity-scenarios.R` asserted that
`emb_pathology_cost` has zero leverage on the combined-versus-office gap, reasoning
that pathology is charged identically to all three arms and must therefore cancel.
The test failed, with a spread of $3.73.

Pathology is billed **per specimen, not per strategy**. Office EMB pays it again on a
repeat attempt and again on D&C rescue; the combined arm pays it again only on its own
much rarer rescue. The gap's sensitivity to pathology is therefore the price range
times the difference in expected specimen count:

```
31.98 x |0.018 - (0.133 x 0.05 + 0.1280125)| = 3.73086675
```

which matches `tables/one_way_sensitivity.csv` to the digit. Both tests now assert
that identity, and a second test confirms the leverage collapses by more than 100x
when the two arms' escalation rates are equalized. The ranking still cannot flip on
pathology, so the `SURVIVES` saboteur test stands, but its original stated reason was
wrong.

## Documentation-drift guards

The third group of tests in the saboteur file does not attack the model at all. It
attacks the prose, because prose is where this repository's worst real failure
happened.

Commit `471e067` (2026-09-12) updated `emb_pathology_cost` ($70.14 to $50.75) and
`dc_professional_cost` ($209.76 to $212.13) from CMS PUF queries, regenerated
`tables/` and the manuscript, and verified the manuscript against the live pipeline.
It did not touch `docs/` or `README.md`, which went on quoting the previous run's
figures for eight weeks: combined $506.11, office $749.18, D&C $3,839.81, margin
$243.06 (32.4%), a 91.4% PSA win rate, and four ICERs. All were corrected on
2026-11-06.

Three guards now make that failure mode detectable:

1. **README quotes the generated sentence verbatim.** `tables/manuscript_summary_sentence.txt`
   must appear in `README.md` as written, whitespace-normalized.
2. **No doc quotes a dead per-patient cost.** Any line in `docs/*.md` or `README.md`
   that pairs a bold dollar figure with the phrase "per patient" must use a number the
   current model actually produces.
3. **The generated tables agree with each other.** `tables/combined_vs_office.csv`'s
   recorded margin must equal the live model's margin.

Guard 2 deliberately exempts the historical change-narratives, which are flagged with
a `> **Historical figures (pre-2026-09-12).**` block. Those sections record what the
model said at the time of a past change; restating them with current numbers would
falsify the change history, so they keep their original values and carry a dated note
pointing at `tables/` for the authoritative set.

## Running them

```sh
Rscript tests/testthat.R                                   # canonical, needs the package installed
Rscript tests/run_without_install.R test-saboteurs.R       # development shortcut, sources R/ directly
```

All three new files were mutation-tested, per
[`docs/testing_philosophy.md`](testing_philosophy.md)'s Rule 1. Planted defects and the
number of failures each produced:

| Planted defect | Failures |
| --- | --- |
| Reintroduce `$506.11` into `docs/methods_notes.md` | 1 |
| Corrupt the README summary quote | 1 |
| `spread` loses its `abs()` | 6 |
| Drop DC from the South Census region list | 2 |
| `weighted_sd` divides by `n` instead of `sum(weights)` | 3 |
| Summary sentence hard-codes "less than" | 2 |
