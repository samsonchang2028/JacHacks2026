# ============================================================
# seed_precedent.jac — OWNER: P2
# Action graph (precedents) + Law anchor.
#
# P1 does not edit this file. You do not edit seed_signal.jac.
# Category strings MUST come from CATEGORIES in schema.jac —
# this is the join key PrecedentMatcher uses. Get it wrong and
# the matcher silently returns nothing.
#
# Outcome.verified=False means: the demo will NOT claim it.
# ============================================================

include schema;


def seed_precedent() {

    act = ActionAnchor();
    root ++> act;

    # --- 1. Prop I (2022) — counter-ballot-measure, failed
    p_i = PrecedentCase(name="Proposition I (2022)", category="road_closure",
                        location="San Francisco", year=2022);
    tac_ballot = Tactic(name="ballot_measure",
                        description="Counter-measure to reopen JFK Drive and "
                                    + "the Upper Great Highway to cars.");
    out_i = Outcome(result="failed",
                    note="Failed ~34.9% yes to ~65.1% no.", verified=True);
    act ++> p_i;
    p_i +>: used :+> tac_ballot;
    tac_ballot +>: resulted_in :+> out_i;

    # --- 2. Prop K environmental review challenge — litigation, failed, on appeal
    p_ceqa = PrecedentCase(name="Prop K environmental review challenge",
                           category="road_closure", location="San Francisco",
                           year=2026);
    tac_lit = Tactic(name="litigation",
                     description="Challenge on environmental review grounds.");
    out_ceqa = Outcome(result="failed",
                       note="Dismissed Jan 2026 — court held the review "
                            + "requirement did not apply because the measure was "
                            + "placed on the ballot by a minority of supervisors, "
                            + "who do not constitute a public agency. On appeal.",
                       verified=True);
    act ++> p_ceqa;
    p_ceqa +>: used :+> tac_lit;
    tac_lit +>: resulted_in :+> out_ceqa;

    # --- 3. District 4 supervisor recall — the tactic that WORKED
    p_recall = PrecedentCase(name="District 4 supervisor recall",
                             category="road_closure", location="San Francisco",
                             year=2025);
    tac_recall = Tactic(name="recall",
                        description="Recall of the supervisor who placed the "
                                    + "measure on the ballot.");
    out_recall = Outcome(result="succeeded",
                         note="Opposition to the closure prompted a successful "
                              + "recall.", verified=True);
    act ++> p_recall;
    p_recall +>: used :+> tac_recall;
    tac_recall +>: resulted_in :+> out_recall;

    # --- 4. Boston Parcel C — closest structural analogue to Portsmouth Square
    p_parcel = PrecedentCase(name="Parcel C protests, Boston Chinatown",
                             category="development", location="Boston", year=1993);
    tac_coal = Tactic(name="petition",
                      description="Coalition with bilingual meetings, petitions, "
                                  + "and a rally before the approval hearing.");
    out_parcel = Outcome(result="unresolved",
                         note="TODO(P2): verify final outcome before claiming it.",
                         verified=False);
    act ++> p_parcel;
    p_parcel +>: used :+> tac_coal;
    tac_coal +>: resulted_in :+> out_parcel;

    # --- 5. Portsmouth Square bridge opposition — the null case, and the point
    p_bridge = PrecedentCase(name="Portsmouth Square bridge opposition",
                             category="renovation", location="San Francisco",
                             year=2026);
    tac_inf = Tactic(name="public_comment",
                     description="Opposition voiced through community leaders "
                                 + "and in-language press.");
    out_bridge = Outcome(result="failed",
                         note="No comment recorded in the supervisor's office; "
                              + "demolition proceeded.", verified=True);
    act ++> p_bridge;
    p_bridge +>: used :+> tac_inf;
    tac_inf +>: resulted_in :+> out_bridge;


    # ========================================================
    # LAW — TIER 2. Anchor only. Populate only if Procedure is done.
    # ========================================================
    law = LawAnchor();
    root ++> law;
    # TODO(P2, stretch): LegalStandard nodes + relied_on edges from Tactic.
    # If this slips, the demo still works. Do not start it before hour 6.

    print("seed_precedent: ok");
}
