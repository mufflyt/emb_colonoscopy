# Adverse-event cost evidence table

Built 2026-09-01 in response to a specific instruction: monetize D&C adverse-event risk by
**management pathway**, not by inserting a single generic "$X per event" placeholder. Every
nonzero term below traces to a named source, verified directly (not relayed) in this session.
**Nothing in this table is wired into `compute_dnc_strategy_cost()` or any other cost function yet**
-- per instruction, that only happens once every nonzero term has a traceable source, and several
terms below do not yet have one.

The structured version of this table is `tables/ae_cost_evidence_table.csv`, with columns `event`,
`event_probability`, `population`, `management_state`, `p_management_given_event`, `unit_cost`,
`cost_source`, `evidence_tier`, `provisional`, `notes`.

## The formula this table is built to support

```
expected_AE_cost(event) = P(event) x sum over management states m of [ P(m | event) x cost(m) ]
```

For uterine perforation, `P(m | event)` for each management state is only usable in this formula
once `cost(m)` is fully sourced (professional fee **and** facility fee). As of this table, that is
true for 2 of 5 management states (observation, laparoscopy-only), covering 65.4% of perforation
cases by probability mass; the remaining 34.6% (immediate laparotomy, laparoscopy-converted, and
unspecified) are missing a facility-cost or management-detail term and are explicitly left `NA`
rather than estimated. For severe hemorrhage, `P(m | event)` itself is unsourced, so the formula
cannot be evaluated at all for that event yet.

## Uterine perforation (`dnc_perforation_probability` = 0.93%, Hefler et al. 2009)

**Event probability:** already in `config/model_parameters.csv` as `dnc_perforation_probability`
(50/5,359 nonobstetric D&Cs, tier A). Verified directly against Hefler et al. 2009's PubMed abstract
this session (Obstet Gynecol 2009;113(6):1268-1271, PMID 19461421): "Uterine perforation occurred in
50 cases (0.9%)." Hefler's own abstract describes only the *rate* of complications, not their
*management* -- it is not a source for what follows.

**Management-state distribution:** Ben-Baruch G, Menczer J, Frenkel Y, Serr DM. "Laparoscopy in the
management of uterine perforation." J Reprod Med 1982;27(2):73-76 (PMID 6212675) -- a distinct,
later paper from an overlapping author group, not the 1980 Isr J Med Sci paper Hefler's own
reference list cites (the two are easy to conflate; verified as separate papers directly on PubMed).
A retrospective review of 52 patients with uterine perforation secondary to curettage:

| Management | n | % | Source detail |
|---|---|---|---|
| Observation only | 23 | 44.2% | "the curettage was discontinued, and the postperforation course was uneventful" |
| Laparoscopy only (no conversion) | 11 | 21.2% | Derived: 18 total laparoscopy minus 7 that converted (below) |
| Immediate laparotomy, no laparoscopy | 8 | 15.4% | "underwent immediate exploratory laparotomy without laparoscopy; in three of them no internal organ injury or bleeding was found" |
| Laparoscopy converted to laparotomy | 7 | 13.5% | Of the 18 laparoscopy patients, "seven of these women underwent subsequent laparotomy" |
| Unspecified | 3 | 5.8% | 23+8+18 = 49 of the abstract's own stated 52 patients; the remaining 3 are not accounted for in the abstract text available this session |

That last row is an honest, disclosed data gap, not an error folded into the other rows -- the
percentages are reported exactly as the abstract states them (44.2% + 15.4% + 34.6% = 94.2%), not
rescaled to sum to 100%.

**Costs, by management state** (CY2026 CMS, all downloaded and verified directly this session --
see `articles/cms_source_data/`):

- **Observation only: $0 marginal.** No new billable procedure; treated the same way this repo
  already treats `dnc_recovery_room_cost` (extended recovery time is bundled into the D&C's own
  OPPS facility fee already charged in the base case).
- **Diagnostic laparoscopy (CPT 49320), no conversion:**
  - Professional fee: facility total RVU 9.47 x CY2026 conversion factor 33.4009 (RVU26C, July 2026
    release) = **$316.30**.
  - Facility fee (OPPS): status indicator J1, APC 5361, payment weight 67.57, payment rate
    **$6,176** (OPPS Addendum B, July 2026).
  - Facility fee (ASC alternative): payment indicator A2, weight 53.81, payment rate **$3,031**
    (ASC Addendum AA, July 2026).
  - **Total (OPPS): $6,492.30.** Fully sourced.
- **Immediate laparotomy (CPT 49000), no laparoscopy:**
  - Professional fee: facility total RVU 21.82 x 33.4009 = **$728.81**.
  - Facility fee: **UNSOURCEABLE.** CPT 49000 carries OPPS status indicator **C (inpatient-only)**
    in the current OPPS Addendum B -- no APC, no payment rate assigned. It is also absent from the
    ASC Addendum AA (0 matching rows; confirmed directly, not inferred). A real facility cost for
    this state requires MS-DRG inpatient costing (hospital base rate x DRG relative weight,
    wage-index adjusted) -- a different methodology than the OPPS/ASC per-procedure approach used
    everywhere else in this repository, and one this repository has not built. Left `NA`, not
    estimated.
- **Laparoscopy converted to laparotomy:**
  - Professional fee: both procedures' fees summed, $316.30 + $728.81 = **$1,045.11** (a simplifying
    assumption -- real claims sometimes bundle a converted procedure differently -- flagged
    provisional for that reason on top of the missing facility component).
  - Facility fee: **UNSOURCEABLE**, same reason as immediate laparotomy (the encounter still ends
    in a CPT 49000 laparotomy).
- **Unspecified (3/52):** **UNSOURCEABLE.** No management detail available.

**External plausibility check only (not population-matched, not used as a base-case value):**
Grzywacz VP, et al. (PMC10776262, an open-access US commercial-claims study of IUD users): "surgical
management of uterine perforations" occurred at 4.5 events per 100 enrolled individuals over a
5-year period, with a mean cost of $31 per enrolled individual over the same period/denominator --
implying roughly **$689/event** ($31 / 0.045). Verified directly (exact table values, not a
paraphrase). Deliberately **not** used as the D&C base-case perforation cost: different population
(IUD insertion-related perforation, not curettage-instrument perforation) and, per the note in the
CSV, the roughly 9x gap between this figure and the CMS-priced diagnostic-laparoscopy total above is
itself informative -- it suggests that claims-based "surgical management" category likely captures
many lower-intensity managements (e.g., office-based retrieval) rather than uniformly representing
OR-based laparoscopy/laparotomy, which is exactly why it should not be substituted for the
management-state-weighted D&C-specific estimate above.

## Severe hemorrhage (`dnc_severe_hemorrhage_probability` = 0.13%, Hefler et al. 2009)

**Event probability:** already in `config/model_parameters.csv` (7/5,359, tier A), verified against
the same Hefler et al. 2009 abstract this session: "seven cases (0.1%) with severe hemorrhage."

**Management-state distribution: UNSOURCED.** A targeted PubMed search for a D&C-specific or
comparable-population hemorrhage management study (transfusion rate, reoperation rate,
observation-only rate) was attempted this session and interrupted by a bot-check partway through;
not exhaustively retried. Per instruction, this event is **not monetized**: peripartum/obstetric
hemorrhage cost literature was deliberately not substituted, since it describes a different clinical
event with a different resource-use profile. This remains an open research task -- see "What would
resolve this" below.

## What would resolve this

- **Immediate/converted-laparotomy facility cost:** build an MS-DRG-based inpatient costing
  methodology (this repo currently has none), or locate a published cost specifically for inpatient
  laparotomy repair of an iatrogenic uterine perforation.
- **The 3/52 unspecified Ben-Baruch/Menczer patients:** full-text access to the 1982 paper, or a
  second independent management-pathway study to triangulate against.
- **Severe hemorrhage management pathway:** a literature search specifically for nonobstetric D&C
  or curettage-related hemorrhage management (transfusion rate is the most likely lever), ideally in
  a population comparable to Hefler et al.'s cohort.

## Status

**Not wired into any cost function.** `compute_dnc_strategy_cost()`'s `expected_total_cost` is
unchanged. This table exists so that (a) what is and isn't sourced is explicit and reviewable before
any wiring decision, and (b) the real, verified values captured this session (Hefler's probabilities
cross-checked, Ben-Baruch/Menczer's management-state split, and the CMS professional/facility fees
for CPT 49320/49000) don't need to be re-derived from scratch when this is picked back up.
