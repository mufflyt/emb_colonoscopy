#' Saboteur tests: adversarial attempts to break the headline result
#'
#' Every other test file in this repository checks that the model does
#' what its documented logic says. This file does the opposite job: it
#' attacks the conclusion. Each test takes one documented weakness in
#' the base case and pushes it to an adversarial but *defensible* value
#' -- a value a skeptical reviewer could actually argue for -- then
#' records what happens to the finding "combined EMB is the least
#' expensive strategy."
#'
#' Two kinds of test live here, and the distinction matters:
#'
#'   SURVIVES  the conclusion holds under the attack. The assertion
#'             guards the claim, and a future parameter change that
#'             breaks it will fail loudly.
#'   BREAKS    the conclusion genuinely flips. The assertion pins the
#'             breakpoint, so the fragility is a tested, visible fact
#'             rather than a footnote. A test here failing means the
#'             breakpoint MOVED, which is itself news.
#'
#' A saboteur test that starts failing is not necessarily a bug. Read
#' which kind it is first.

cheapest_strategy <- function(overrides = list()) {
  strategy_costs <- compute_strategy_costs(
    override_model_parameters(test_model_parameters(), overrides),
    test_price_index_table()
  )$strategy_costs
  strategy_costs$strategy[base::which.min(strategy_costs$expected_total_cost)]
}

strategy_cost_of <- function(strategy_name, overrides = list()) {
  strategy_costs <- compute_strategy_costs(
    override_model_parameters(test_model_parameters(), overrides),
    test_price_index_table()
  )$strategy_costs
  strategy_costs$expected_total_cost[strategy_costs$strategy == strategy_name]
}

combined_margin <- function(overrides = list()) {
  strategy_cost_of("office_emb", overrides) - strategy_cost_of("combined_emb", overrides)
}


# ---- Saboteur 1: the added-minutes assumption -------------------------------
# The single largest tornado driver. Base case assumes 5 incremental
# colonoscopy-suite minutes; the published feasibility range is 1-12.

test_that("SURVIVES: combined stays cheapest across the entire published 1-12 minute range", {
  for (minutes in c(1, 5, 8, 10, 12)) {
    expect_equal(
      cheapest_strategy(list(combined_emb_added_minutes = minutes)),
      "combined_emb",
      info = base::paste("added minutes =", minutes)
    )
  }
})

test_that("BREAKS: an endoscopy unit claiming 15 added minutes flips the conclusion", {
  # 15 minutes is above the ~12.3-minute threshold but not absurd: a
  # reviewer who times their own suite could assert it.
  expect_equal(cheapest_strategy(list(combined_emb_added_minutes = 15)), "office_emb")
  expect_lt(combined_margin(list(combined_emb_added_minutes = 15)), 0)
})

test_that("BREAKS: the minutes breakpoint sits between 12 and 13 minutes", {
  expect_equal(cheapest_strategy(list(combined_emb_added_minutes = 12)), "combined_emb")
  expect_equal(cheapest_strategy(list(combined_emb_added_minutes = 13)), "office_emb")
})


# ---- Saboteur 2: the preop-visit structural toggle --------------------------
# combined_requires_preop_office_visit = TRUE rests on one clinician's
# practice. A reviewer can argue it either way, so the conclusion must
# not depend on which way it is set.

test_that("SURVIVES: combined stays cheapest with the preop visit both required and folded in", {
  expect_equal(cheapest_strategy(list(combined_requires_preop_office_visit = TRUE)), "combined_emb")
  expect_equal(cheapest_strategy(list(combined_requires_preop_office_visit = FALSE)), "combined_emb")
})


# ---- Saboteur 3: the office EMB failure rate -------------------------------
# emb_failure_lynch = 13.3% is pooled from 22/166 across three studies
# nobody in this project has read in full (all paywalled). It is the
# #2 tornado driver, and the whole saving is an escalation story.

test_that("SURVIVES: combined stays cheapest across the published failure-rate bound 10.3%-20.0%", {
  for (failure_rate in c(0.103, 0.133, 0.20)) {
    expect_equal(
      cheapest_strategy(list(emb_failure_lynch = failure_rate)),
      "combined_emb",
      info = base::paste("emb_failure_lynch =", failure_rate)
    )
  }
})

test_that("BREAKS: a competent operator with a 5% failure rate makes office EMB cheapest", {
  # Below the ~6.7% threshold. Entirely arguable: a high-volume
  # gynecologist may genuinely fail far less often than the pooled
  # Lynch literature, which is dominated by tiny denominators.
  expect_equal(cheapest_strategy(list(emb_failure_lynch = 0.05)), "office_emb")
})

test_that("BREAKS: the failure-rate breakpoint sits between 6% and 7%", {
  expect_equal(cheapest_strategy(list(emb_failure_lynch = 0.06)), "office_emb")
  expect_equal(cheapest_strategy(list(emb_failure_lynch = 0.07)), "combined_emb")
})

test_that("BREAKS: Yi et al.'s non-Lynch failure rate is below the breakpoint too", {
  # If a reviewer argues the Lynch-specific rate is unreliable and the
  # general postmenopausal-bleeding literature should be used instead,
  # emb_failure_general (11%) still holds, but Yi's own first-attempt
  # success of 0.58 (i.e. 42% failure) swings hard the other way. Both
  # directions are recorded here so neither can be cherry-picked.
  expect_equal(cheapest_strategy(list(emb_failure_lynch = 0.11)), "combined_emb")
  expect_equal(cheapest_strategy(list(emb_failure_lynch = 0.42)), "combined_emb")
})


# ---- Saboteur 4: is D&C's dominance an artifact of its facility fee? -------
# dnc_facility_or_asc_fee = $3,307.24 drives the $3,338 saving vs D&C,
# and Yi et al. priced D&C ~52% lower. docs/methods_notes.md reports the
# $0-$20,000 root search never converged, so the claim needs a direct test.

test_that("SURVIVES: D&C is never the cheapest strategy even with a free facility", {
  expect_false(cheapest_strategy(list(dnc_facility_or_asc_fee = 0)) == "dnc")
  # And at the ASC rate, which is the realistic low-cost alternative.
  expect_false(cheapest_strategy(list(dnc_facility_or_asc_fee = 1738.07)) == "dnc")
})

test_that("SURVIVES: adopting Yi et al.'s own D&C price leaves the ranking unchanged", {
  # Yi 2018 priced D&C at $2,310.47 combined professional+facility
  # (2017 USD). Strip this repository's professional fee out of that
  # figure to get a comparable facility-only input.
  yi_facility_equivalent <- 2310.47 - 212.13
  expect_equal(
    cheapest_strategy(list(dnc_facility_or_asc_fee = yi_facility_equivalent)),
    "combined_emb"
  )
})


# ---- Saboteur 5: the parameter that actually went stale --------------------
# emb_pathology_cost moved $70.14 -> $50.75 in commit 471e067 and shifted
# every derived figure in docs/. Pathology is charged identically in all
# three arms, so it must not be able to change the ranking at all.

test_that("SURVIVES: a shared cost charged equally to every arm cannot flip the ranking", {
  for (pathology_cost in c(0, 50.75, 70.14, 250)) {
    expect_equal(
      cheapest_strategy(list(emb_pathology_cost = pathology_cost)),
      "combined_emb",
      info = base::paste("emb_pathology_cost =", pathology_cost)
    )
  }
})


# ---- Saboteur 6: coordination and room-time costs -------------------------

test_that("BREAKS: coordination cost above ~$264 erases the advantage over office EMB", {
  expect_gt(combined_margin(list(coordination_cost = 250)), 0)
  expect_lt(combined_margin(list(coordination_cost = 300)), 0)
})

test_that("SURVIVES: combined stays cheapest at the upper bound of the room-cost rate", {
  expect_equal(cheapest_strategy(list(direct_room_cost_per_minute = 33.44)), "combined_emb")
})


# ---- Saboteur 7: the joint worst case ------------------------------------
# One-way sensitivity analysis moves one parameter at a time, which is
# exactly how a fragile result survives a tornado diagram. This stacks
# every anti-combined bound at once. Nothing in the manuscript claims
# the result survives this; the test exists to state plainly that it
# does not, so nobody discovers it in peer review.

test_that("BREAKS: stacking every anti-combined bound simultaneously flips the result", {
  worst_case <- list(
    combined_emb_added_minutes = 12,        # upper published bound
    emb_failure_lynch = 0.103,              # lower published bound
    direct_room_cost_per_minute = 33.44,    # upper bound
    anesthesia_cost_per_minute = 6.36,      # upper bound
    coordination_cost = 38.09,              # upper bound
    combined_to_dnc_probability = 0.0636    # upper bound
  )
  expect_equal(cheapest_strategy(worst_case), "office_emb")
})

test_that("SURVIVES: the joint BEST case for office EMB still never makes D&C competitive", {
  worst_case <- list(
    combined_emb_added_minutes = 12,
    emb_failure_lynch = 0.103,
    direct_room_cost_per_minute = 33.44,
    dnc_facility_or_asc_fee = 1738.07
  )
  expect_false(cheapest_strategy(worst_case) == "dnc")
})


# ---- Saboteur 8: payer mix ------------------------------------------------

test_that("SURVIVES: combined stays cheapest under Medicaid and commercial multipliers", {
  medicaid <- list(
    emb_office_professional_cost = 97.03 * 0.883,
    emb_pathology_cost = 50.75 * 0.916,
    dc_professional_cost = 212.13 * 0.775,
    office_visit_em_cost = 88.76 * 0.836
  )
  commercial <- list(
    emb_office_professional_cost = 97.03 * 1.775,
    emb_pathology_cost = 50.75 * 1.800,
    dc_professional_cost = 212.13 * 1.626,
    office_visit_em_cost = 88.76 * 1.492
  )
  expect_equal(cheapest_strategy(medicaid), "combined_emb")
  expect_equal(cheapest_strategy(commercial), "combined_emb")
})


# ---- Saboteur 9: the zero that is not a measurement -----------------------
# office_emb_serious_infection_probability = 0 encodes absent data, not
# measured safety, and the adverse-event-per-1,000 comparison is a reported
# secondary outcome. The saboteur here found something worse than a fragile
# number: the parameter is not wired into the model at all.

test_that("SURVIVES: combined's adverse-event advantage comes from avoided D&C rescue", {
  outcomes <- compute_strategy_clinical_outcomes(test_model_parameters())
  combined_ae <- outcomes$major_ae_per_1000[outcomes$strategy == "combined_emb"]
  office_ae <- outcomes$major_ae_per_1000[outcomes$strategy == "office_emb"]
  expect_lt(combined_ae, office_ae)

  # The advantage is entirely rescue-driven: each arm's AE exposure is its
  # D&C-rescue probability times the D&C complication rate, nothing else.
  parameters <- test_model_parameters()
  dnc_complication_rate <- as.numeric(
    parameters$base_value[parameters$parameter == "dnc_overall_complication_probability"]
  )
  expect_equal(
    office_ae,
    outcomes$rescue_dnc_probability[outcomes$strategy == "office_emb"] *
      dnc_complication_rate * 1000,
    tolerance = 1e-8
  )
})

test_that("BREAKS: office_emb_serious_infection_probability is declared but never consumed", {
  # This is a documented gap, asserted so it cannot be forgotten. The
  # office arm's AE count excludes office-side infection entirely, so the
  # reported 0.36-vs-2.48-per-1,000 contrast understates office EMB's own
  # procedural risk by however much post-biopsy infection actually is.
  # When the parameter is wired in, this test will fail -- delete it then.
  parameters <- test_model_parameters()
  baseline <- compute_strategy_clinical_outcomes(parameters)
  perturbed <- compute_strategy_clinical_outcomes(
    override_model_parameters(
      parameters, list(office_emb_serious_infection_probability = 0.05)
    )
  )
  expect_equal(baseline$major_ae_per_1000, perturbed$major_ae_per_1000)
  expect_false(
    any(grepl(
      "office_emb_serious_infection_probability",
      unlist(lapply(
        list.files(file.path(repo_root_path(), "R"), pattern = "[.]R$", full.names = TRUE),
        readLines, warn = FALSE
      )),
      fixed = TRUE
    ))
  )
})


# ---- Saboteur 10: documentation drift ------------------------------------
# The real failure that happened: commit 471e067 regenerated tables/ and the
# manuscript but left every derived figure in docs/ and README.md quoting
# the previous run. Prose cannot be unit-tested in general, but the headline
# numbers can be, and they are the ones that reach a reader.

test_that("SURVIVES: README quotes the generated summary sentence verbatim", {
  summary_path <- file.path(repo_root_path(), "tables/manuscript_summary_sentence.txt")
  readme_path <- file.path(repo_root_path(), "README.md")
  testthat::skip_if_not(base::file.exists(summary_path) && base::file.exists(readme_path))

  normalise <- function(text) {
    text <- base::gsub("^>\\s*", "", text)
    text <- base::paste(text, collapse = " ")
    base::gsub("\\s+", " ", base::trimws(text))
  }
  generated <- normalise(base::readLines(summary_path, warn = FALSE))
  readme <- normalise(base::readLines(readme_path, warn = FALSE))
  expect_true(base::grepl(generated, readme, fixed = TRUE))
})

test_that("SURVIVES: no doc quotes a base-case cost that the model no longer produces", {
  strategy_costs <- compute_strategy_costs(
    test_model_parameters(), test_price_index_table()
  )$strategy_costs
  current <- base::sprintf(
    "$%s",
    base::formatC(strategy_costs$expected_total_cost, format = "f", digits = 2, big.mark = ",")
  )

  doc_paths <- c(
    base::list.files(file.path(repo_root_path(), "docs"), pattern = "[.]md$", full.names = TRUE),
    file.path(repo_root_path(), "README.md")
  )
  doc_text <- base::unlist(base::lapply(doc_paths, base::readLines, warn = FALSE))

  # Any line that calls a figure "per patient" in bold or quotes the
  # base-case trio must use a current number. Historical-change
  # narratives are explicitly exempt: they are flagged with a
  # "Historical figures (pre-" block and are meant to preserve old values.
  per_patient_lines <- base::grep("per patient", doc_text, value = TRUE)
  per_patient_lines <- base::grep("[*][*][$]", per_patient_lines, value = TRUE)
  quoted <- base::regmatches(
    per_patient_lines,
    base::gregexpr("[$][0-9][0-9,]*[.][0-9]{2}", per_patient_lines)
  )
  quoted <- base::unique(base::unlist(quoted))
  expect_true(
    base::all(quoted %in% current),
    info = base::paste(
      "docs quote stale per-patient cost(s):",
      base::paste(base::setdiff(quoted, current), collapse = ", ")
    )
  )
})

test_that("SURVIVES: the generated tables agree with each other on the headline margin", {
  margin_path <- file.path(repo_root_path(), "tables/combined_vs_office.csv")
  testthat::skip_if_not(base::file.exists(margin_path))
  recorded <- utils::read.csv(margin_path)
  expect_equal(
    base::abs(recorded$incremental_cost_combined_vs_office[[1]]),
    combined_margin(),
    tolerance = 1e-6
  )
})
