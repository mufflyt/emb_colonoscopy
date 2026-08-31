#!/usr/bin/env Rscript
#' Independent verification of the manuscript's PSA-derived clinical-outcome claims
#'
#' Deliberately does NOT source("R/00_source_all.R") and does NOT call
#' compute_diagnostic_yield(), compute_strategy_clinical_outcomes(), or
#' run_probabilistic_sensitivity() -- per the project's independent-confirmation
#' meta-rule (see "Rule 2" in docs/testing_philosophy.md), a finding capable of
#' changing the study's conclusions is not independently confirmed if the
#' confirmation reuses the same pipeline that produced it. This script re-derives
#' every clinical-outcome and joint cost/outcome claim in the manuscript's
#' Results and Discussion sections directly from the already-saved PSA draws
#' file, using only base R and no repository function calls.
#'
#' Read-only: writes nothing, only prints. Re-run whenever
#' tables/probabilistic_sensitivity_draws.csv is regenerated (which happens
#' every time analysis/03_probabilistic_sensitivity.R runs, since PSA is
#' unseeded) to re-check the manuscript's numbers against the current draws.
#'
#' Run from the repository root:
#'   Rscript analysis/12_independent_psa_verification.R

d <- utils::read.csv("tables/probabilistic_sensitivity_draws.csv")

cat("n draws:", nrow(d), "\n\n")

summarize_col <- function(x) {
  c(
    mean = mean(x), sd = sd(x),
    median = median(x),
    p25 = as.numeric(quantile(x, 0.25)),
    p75 = as.numeric(quantile(x, 0.75))
  )
}

cat("=== Expected cost ($) ===\n")
cost_summary <- rbind(
  office_emb   = summarize_col(d$office_emb_cost),
  combined_emb = summarize_col(d$combined_emb_cost),
  dnc          = summarize_col(d$dnc_cost)
)
print(round(cost_summary, 2))

cat("\n=== Major adverse events per 1,000 ===\n")
ae_summary <- rbind(
  office_emb   = summarize_col(d$office_emb_major_ae_per_1000),
  combined_emb = summarize_col(d$combined_emb_major_ae_per_1000),
  dnc          = summarize_col(d$dnc_major_ae_per_1000)
)
print(round(ae_summary, 3))

cat("\n=== Delayed cancer/precancer diagnoses per 1,000 ===\n")
neoplasia_summary <- rbind(
  office_emb   = summarize_col(d$office_emb_neoplasia_delayed_per_1000),
  combined_emb = summarize_col(d$combined_emb_neoplasia_delayed_per_1000),
  dnc          = summarize_col(d$dnc_neoplasia_delayed_per_1000)
)
print(round(neoplasia_summary, 3))

cat("\n=== Joint cost + delayed-neoplasia comparison: combined_emb vs. office_emb ===\n")
combined_cheaper <- d$combined_emb_cost < d$office_emb_cost
combined_no_worse_neoplasia <- d$combined_emb_neoplasia_delayed_per_1000 <= d$office_emb_neoplasia_delayed_per_1000
combined_strictly_better_neoplasia <- d$combined_emb_neoplasia_delayed_per_1000 < d$office_emb_neoplasia_delayed_per_1000
both <- combined_cheaper & combined_no_worse_neoplasia

cat(sprintf("P(combined cheaper than office)                         = %.1f%% (%d/%d)\n",
            100 * mean(combined_cheaper), sum(combined_cheaper), nrow(d)))
cat(sprintf("P(combined no greater delayed-neoplasia risk than office) = %.1f%% (%d/%d)\n",
            100 * mean(combined_no_worse_neoplasia), sum(combined_no_worse_neoplasia), nrow(d)))
cat(sprintf("P(combined strictly lower delayed-neoplasia than office)  = %.1f%% (%d/%d)\n",
            100 * mean(combined_strictly_better_neoplasia), sum(combined_strictly_better_neoplasia), nrow(d)))
cat(sprintf("P(BOTH: cheaper AND no greater neoplasia risk)            = %.1f%% (%d/%d)\n",
            100 * mean(both), sum(both), nrow(d)))

cat("\n=== Also vs. major AE exposure: combined_emb vs. office_emb ===\n")
combined_no_worse_ae <- d$combined_emb_major_ae_per_1000 <= d$office_emb_major_ae_per_1000
both_cost_and_ae <- combined_cheaper & combined_no_worse_ae
all_three <- combined_cheaper & combined_no_worse_neoplasia & combined_no_worse_ae
cat(sprintf("P(combined no greater major-AE exposure than office)      = %.1f%% (%d/%d)\n",
            100 * mean(combined_no_worse_ae), sum(combined_no_worse_ae), nrow(d)))
cat(sprintf("P(cheaper AND no greater major-AE exposure)               = %.1f%% (%d/%d)\n",
            100 * mean(both_cost_and_ae), sum(both_cost_and_ae), nrow(d)))
cat(sprintf("P(cheaper AND no greater neoplasia AND no greater AE)     = %.1f%% (%d/%d)\n",
            100 * mean(all_three), sum(all_three), nrow(d)))

cat("\n=== Sanity cross-check: saved cheapest_strategy column vs. independently re-derived min-cost strategy ===\n")
recomputed_cheapest <- apply(d[, c("office_emb_cost", "combined_emb_cost", "dnc_cost")], 1, function(row) {
  c("office_emb", "combined_emb", "dnc")[which.min(row)]
})
cat("Mismatches between saved cheapest_strategy and independently re-derived min-cost strategy:",
    sum(recomputed_cheapest != d$cheapest_strategy), "/", nrow(d), "\n")
print(table(d$cheapest_strategy))
