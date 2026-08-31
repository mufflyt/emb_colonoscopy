#!/usr/bin/env Rscript
#' Decision-tree model diagram
#'
#' Builds the schematic decision-tree figure required by the CHEERS
#' reporting guideline (item 15: "a figure showing a summary of the model...
#' clearly show how the various factors or processes lead to the outcome of
#' interest" -- explicitly called out in Obstetrics & Gynecology's
#' Instructions for Authors as one of two CHEERS items the journal checks
#' specifically). Standard decision-tree notation: squares are decision
#' nodes, circles are chance nodes, triangles are terminal (payoff) nodes.
#' All probabilities and costs are pulled live from the model, not
#' hand-typed, so this figure cannot silently drift from the base case.
#' Run from the repository root:
#'   Rscript analysis/10_decision_tree_figure.R

base::source("R/00_source_all.R")

base::message("=== Decision-tree model diagram ===")

model_parameters <- load_model_parameters("config/model_parameters.csv")
price_index_table <- load_price_index_table("data/cpi_medical_care.csv")
strategy_result <- compute_strategy_costs(model_parameters, price_index_table)
costs <- strategy_result$strategy_costs

get_cost <- function(strategy_name) {
  base::round(costs$expected_total_cost[costs$strategy == strategy_name], 2)
}
get_escalation_probability <- function(strategy_name) {
  costs$escalation_probability[costs$strategy == strategy_name]
}

office_initial_cost <- base::round(costs$initial_cost[costs$strategy == "office_emb"], 2)
combined_initial_cost <- base::round(costs$initial_cost[costs$strategy == "combined_emb"], 2)
dnc_cost <- get_cost("dnc")
office_escalation_pct <- scales::percent(get_escalation_probability("office_emb"), accuracy = 0.1)
office_success_pct <- scales::percent(1 - get_escalation_probability("office_emb"), accuracy = 0.1)
combined_escalation_pct <- scales::percent(get_escalation_probability("combined_emb"), accuracy = 0.1)
combined_success_pct <- scales::percent(1 - get_escalation_probability("combined_emb"), accuracy = 0.1)

# Terminal nodes show the actual cost incurred along THAT path (initial
# attempt, plus the D&C rescue cost if that path escalates) -- NOT the
# strategy's overall probability-weighted expected cost, which is instead
# annotated at each strategy's own chance node (the standard "fold-back"
# value shown at a decision-tree's branch point).
office_escalate_path_cost <- base::round(office_initial_cost + dnc_cost, 2)
combined_escalate_path_cost <- base::round(combined_initial_cost + dnc_cost, 2)

base::message(
  "Office EMB: initial $", office_initial_cost, ", escalation ", office_escalation_pct,
  "; Combined EMB: initial $", combined_initial_cost, ", escalation ", combined_escalation_pct,
  "; D&C: $", dnc_cost
)

# Graphviz DOT syntax via DiagrammeR. rankdir=LR for a left-to-right tree,
# matching standard decision-analysis figure convention.
tree_dot <- base::sprintf('
digraph decision_tree {
  rankdir=LR;
  fontname="Helvetica";
  node [fontname="Helvetica", fontsize=11];
  edge [fontname="Helvetica", fontsize=10];

  root [shape=square, style=filled, fillcolor="#4A90D9", fontcolor=white,
        label="Lynch syndrome\\nsurveillance\\npatient"];

  office_chance [shape=circle, style=filled, fillcolor="#F5F5F5",
                 label="Office EMB\\nInitial cost: $%s\\nExpected total: $%s"];
  office_success [shape=triangle, style=filled, fillcolor="#B7E4C7",
                  label="Adequate sample\\nCost: $%s"];
  office_fail [shape=circle, style=filled, fillcolor="#F5F5F5",
               label="Failed/inadequate\\nsample"];
  office_dnc [shape=triangle, style=filled, fillcolor="#F4A6A6",
              label="Escalate to D&C\\nCost: $%s"];

  combined_chance [shape=circle, style=filled, fillcolor="#F5F5F5",
                    label="Combined EMB\\n(during colonoscopy)\\nInitial cost: $%s\\nExpected total: $%s"];
  combined_success [shape=triangle, style=filled, fillcolor="#B7E4C7",
                     label="Adequate sample\\nCost: $%s"];
  combined_dnc [shape=triangle, style=filled, fillcolor="#F4A6A6",
                label="Escalate to D&C\\nCost: $%s"];

  dnc_terminal [shape=triangle, style=filled, fillcolor="#F4A6A6",
                label="Operative D&C\\n(no escalation branch)\\nTotal: $%s"];

  root -> office_chance [label="  Strategy 1: Office EMB"];
  office_chance -> office_success [label="  %s"];
  office_chance -> office_fail [label="  %s"];
  office_fail -> office_dnc [label="  escalate\\n(100%%)"];

  root -> combined_chance [label="  Strategy 2: Combined EMB"];
  combined_chance -> combined_success [label="  %s"];
  combined_chance -> combined_dnc [label="  %s"];

  root -> dnc_terminal [label="  Strategy 3: Operative D&C"];
}
', office_initial_cost, get_cost("office_emb"),
   office_initial_cost, office_escalate_path_cost,
   combined_initial_cost, get_cost("combined_emb"),
   combined_initial_cost, combined_escalate_path_cost,
   dnc_cost,
   office_success_pct, office_escalation_pct,
   combined_success_pct, combined_escalation_pct
)

tree_graph <- DiagrammeR::grViz(tree_dot)
tree_svg <- DiagrammeRsvg::export_svg(tree_graph)

if (!base::dir.exists("figures")) {
  base::dir.create("figures", recursive = TRUE, showWarnings = FALSE)
}

rsvg::rsvg_png(
  charToRaw(tree_svg), file = "figures/figure7_decision_tree.png",
  width = 2400, height = 1200
)
base::message("Saved figure to: figures/figure7_decision_tree.png")

base::message("=== Decision-tree model diagram complete ===")
