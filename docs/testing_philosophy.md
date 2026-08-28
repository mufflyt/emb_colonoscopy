# Testing philosophy

Two rules adopted 2026-08-28, in response to project feedback. Both exist because a
test suite that has never been proven to fail is not evidence of correctness, and a
finding that could change the paper's conclusion deserves more scrutiny than a finding
that doesn't.

## Rule 1: every blocking scientific test must be proven to fail on a planted defect and pass when reverted

A "blocking" test here means any test in `tests/testthat/` that gates CI on `main`
and protects a scientific/correctness claim (as opposed to, say, a pure input-format
check). Passing without ever having been made to fail is not proof a test works --
it could be vacuously true, checking the wrong thing, or silently not exercising the
code path it claims to.

**Process:** when a blocking test is added or materially changed, temporarily plant
a realistic defect in the code it protects, confirm the test goes red, revert the
defect, confirm the test goes green again, and record the result. This is not
automated mutation-testing tooling (no `mutant`/`mutmut`-style framework is wired
into CI) -- it's a discipline applied by hand at the point a test is written, and
logged here so it isn't quietly skipped later.

### Log

| Test | Defect planted | Result |
| --- | --- | --- |
| `validate_cms_filter_field errors when the CMS API silently returns an unfiltered dataset` (`test-evidence-extras.R`) | Disabled the guard (early `return(TRUE)` before the check) | RED with defect (`Expected ... to throw a error` -- failed to throw) -> GREEN on revert |
| `combined EMB arm never includes the colonoscopy baseline anesthesia cost` (`test-strategy-costs.R`) | Added `colonoscopy_anesthesia_episode_cost` into the combined arm's `incremental_anesthesia_drug` component | RED with defect (`Expected ... to be FALSE`, got `TRUE`) -> GREEN on revert |
| `no adjacent pair of index years implies an implausible multi-year inflation multiplier` (`test-inflation.R`) | Reintroduced the original disconnected-scale 2014 CPI value (`100`) | RED with defect, reproducing the exact original bug signature (`ratio = 5.938 over 12 years`), with a **cascading failure** into `test-threshold.R`'s coordination-cost threshold (a live demonstration of how a single bad input can change a downstream conclusion) -> GREEN on revert |
| `raising dnc_facility_or_asc_fee increases all three strategies' costs (via the rescue branch)` (`test-model-identity.R`) | Severed the D&C-cost escalation pass-through in the combined arm (`escalation_cost <- 0`) | RED with defect -> GREEN on revert |
| `INDEPENDENT CONFIRMATION: D&C is dominated...` (`test-independent-confirmation.R`) | Inflated `dnc_recovery_room_cost` by 50% inside the pipeline only (not in the test's independent arithmetic) | RED with defect (all three cross-check assertions failed by the exact planted amount) -> GREEN on revert |

Each row above was executed for real during this session, not simulated -- see the
conversation history / commit that introduced this file for the exact defect-planting
commands.

## Rule 2: an audit result capable of changing the study frame requires independent confirmation

Some findings are just arithmetic bookkeeping. Others change what the paper can
claim -- e.g. "combined EMB is cheaper than office EMB" or "D&C is dominated by both
alternatives even before any facility fee is applied" (see `docs/methods_notes.md`).
A finding like that passing the same test suite that produced it is not independent
evidence; the pipeline and its own tests can share a bug.

**Process:** for a finding capable of changing the study's frame, re-derive it via a
path that does not call the functions that originally produced it -- different code,
ideally different reasoning, checked against the same raw parameter values. If both
paths agree, the finding is confirmed, not just internally consistent.

**Applied:** `tests/testthat/test-independent-confirmation.R` re-derives the
"D&C is dominated by both alternatives even at $0 facility fee" finding using
arithmetic written directly in the test file -- summing raw parameter values and
doing the inflation adjustment by hand -- and never calls
`compute_dnc_strategy_cost()`, `compute_office_emb_strategy_cost()`,
`compute_combined_emb_strategy_cost()`, or `metric_dnc_dominated()`. It passed on
first run (independently reproducing the $618.61 gap between the D&C cost and the
more expensive alternative at zero facility fee) and was itself mutation-tested (see
the log above): a pipeline-only defect that the shared test suite would have missed
if the independent path used the same code was caught.

This does **not** mean the finding is true in the world -- it means the finding is a
correct consequence of the current parameter values, several of which are still
provisional (see `docs/data_sources.md`). Independent confirmation checks the math,
not the inputs.

**When to apply this rule going forward:** any new finding that would appear in a
manuscript's abstract or headline results -- a threshold value, a dominance claim, a
"strategy X is cheapest" statement -- before it's treated as established, not just
"the code that computed it passed its own tests."
