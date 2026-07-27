# ============================================================
# seed_signal.jac — OWNER: P1
# Institution skeleton + Procedure + case Projects + Narrative.
#
# P2 does not edit this file. You do not edit seed_precedent.jac.
# Category strings MUST come from CATEGORIES in schema.jac.
#
# RULE: any CommentChannel or Deadline without a real source_url
# does not get created. Ship "unknown" over a guess.
# ============================================================

include schema;


def seed_signal() {

    # ========================================================
    # GEO ZONES
    # ========================================================
    ct       = GeoZone(name="Chinatown",   kind="neighborhood");
    d3       = GeoZone(name="District 3",  kind="district");
    sunset   = GeoZone(name="Sunset",      kind="neighborhood");
    richmond = GeoZone(name="Richmond",    kind="neighborhood");
    citywide = GeoZone(name="San Francisco (citywide electorate)", kind="citywide");

    # ========================================================
    # CASE 1 — PORTSMOUTH SQUARE  (lead case: missing channel)
    # ========================================================
    ps_anchor = CaseAnchor(slug="portsmouth-square",
                           title="Portsmouth Square Improvement Project");
    root ++> ps_anchor;

    ps = Project(
        name="Portsmouth Square Improvement Project",
        category="renovation",                     # <- from CATEGORIES
        location="Portsmouth Square, Chinatown, San Francisco",
        description="~$73M renovation; pedestrian bridge over Kearny St removed "
                    + "to make room for a larger two-story clubhouse. Park closed "
                    + "for roughly two years from June 2026.",
        timeline="groundbreaking June 2026"
    );
    ps_anchor ++> ps;
    ps +>: located_in :+> ct;
    ps +>: located_in :+> d3;

    # --- Zones AGREE here. The failure was the channel, not the electorate.
    recpark = DecisionBody(name="SF Recreation and Park Department",
                           kind="commission", jurisdiction="citywide agency");
    d3_sup  = DecisionBody(name="District 3 Supervisor's Office",
                           kind="supervisor", jurisdiction="District 3");
    ps +>: decided_by :+> recpark;
    ps +>: decided_by :+> d3_sup;
    d3_sup  +>: accountable_to :+> d3;
    recpark +>: accountable_to :+> citywide;

    # --- inside_process is the whole story of this case
    # contact fields resolved live via ingest/extract/orgs.py (Task 5);
    # mua and geary_cyc below have no org-level contact on their public
    # sites as of this scrape — honest blank, not a guess.
    ccba = Organization(name="Chinese Consolidated Benevolent Association",
                        community="Chinatown family associations",
                        language="zh", contact="info@chssc.org",
                        inside_process=False);
    mua  = Organization(name="Merchants United Association of San Francisco",
                        community="Chinatown / Sunset / Ocean Ave merchants",
                        language="zh", contact="", inside_process=False);
    ccdc = Organization(name="Chinatown Community Development Center",
                        community="Chinatown residents",
                        language="en", contact="info@chinatowncdc.org",
                        inside_process=True);
    sf_chamber = Organization(name="SF Chamber of Commerce",
                        community="San Francisco business community",
                        language="en", contact="info@sfchamber.com, 415.392.4520",
                        inside_process=False);
    cyc = Organization(name="Community Youth Center",
                        community="Chinatown youth and families",
                        language="zh", contact="hello@cycsf.org, (415) 775-1345",
                        inside_process=False);
    for o in [ccba, mua, ccdc, cyc] { o +>: serves :+> ct; }
    sf_chamber +>: serves :+> citywide;

    t1 = Testimony(speaker="CCBA board member (5 decades)",
                   affiliation="CCBA",
                   claim="Bridge let seniors and children cross Kearny safely; "
                         + "removal harms community access. Never heard the plan "
                         + "from city officials.",
                   language="zh");
    t2 = Testimony(speaker="Merchants association president",
                   affiliation="Merchants United",
                   claim="Three simultaneous Chinatown construction projects "
                         + "compound harm to merchants.",
                   language="zh");
    t3 = Testimony(speaker="District 3 Supervisor",
                   affiliation="D3 Supervisor's Office",
                   claim="Office received no communication supporting keeping "
                         + "the bridge.",
                   kind="counterargument");
    for t in [t1, t2, t3] { ps_anchor ++> t; t +>: evidences :+> ps; }
    t3 +>: rebuts :+> t1;

    # --- PROCEDURE — P1 FILLS FROM REAL SOURCES. Deliberately empty.
    # TODO(P1): Rec & Park Commission agenda + public comment instructions
    # TODO(P1): D3 supervisor office contact + accepted comment format
    # TODO(P1): remaining appeal or hearing window
    #
    # ATTEMPTED (ingest/extract/procedure.py, live Firecrawl run): sfrecpark.org's
    # AgendaCenter/DocumentCenter links retire fast — every candidate page
    # mapped for this project 404'd by scrape time. sfbos.org/sf.gov turned
    # up Danny Sauter's D3 page, but it routes to public-records requests,
    # not a project-specific comment channel. No live, citable channel for
    # either body — leaving this a GAP (not a guess) is itself the finding:
    # it's the same gap Danny Sauter's office confirmed (§Failure Mode A in
    # docs/DESIGNDOC.md). DecisionWalker will report it in smoke.jac.
    #
    # Pattern once you have a real source:
    #   ch = CommentChannel(recipient="...", method="email",
    #                       languages="en,zh", source_url="https://...");
    #   dl = Deadline(kind="comment", date="2026-08-14",
    #                 source_url="https://...");
    #   d3_sup +>: accepts_input_via :+> ch;
    #   ch +>: governed_by :+> dl;


    # ========================================================
    # CASE 2 — PROP K  (divergence case — protect this)
    # ========================================================
    pk_anchor = CaseAnchor(slug="prop-k-great-highway",
                           title="Prop K — Upper Great Highway closure");
    root ++> pk_anchor;

    pk = Project(
        name="Proposition K (Upper Great Highway closure)",
        category="road_closure",                   # <- from CATEGORIES
        location="Upper Great Highway, Lincoln Way to Sloat Blvd",
        description="Nov 5 2024 ballot measure permanently closing the Upper "
                    + "Great Highway to private cars. Passed citywide 54.73%. "
                    + "Lost ~60-40 in the Sunset and ~70-30 in the Richmond; "
                    + "Districts 1/4/7/11 combined ~61% no.",
        timeline="passed Nov 2024"
    );
    pk_anchor ++> pk;
    pk +>: located_in :+> sunset;
    pk +>: located_in :+> richmond;

    # --- THE HERO EDGE. Impact = Sunset/Richmond. Decision = citywide.
    electorate = DecisionBody(name="San Francisco citywide electorate",
                              kind="electorate", jurisdiction="citywide");
    pk +>: decided_by :+> electorate;
    electorate +>: accountable_to :+> citywide;

    # Replaced with the specific orgs from config/orgs.yaml (Task 5) —
    # more actionable than the generic placeholders this case started with.
    # These are impact-zone (westside) organizing contacts, not a decision-
    # zone intermediary — per docs/DESIGNDOC.md's "eastside problem", no such
    # intermediary exists for Prop K, and we didn't invent one.
    richmond_ctr = Organization(name="Richmond Neighborhood Center",
                                community="Richmond residents",
                                contact="", inside_process=False);
    geary_assoc  = Organization(name="Geary Merchants Association",
                                community="Richmond merchants",
                                contact="", inside_process=False);
    lowell_ptsa  = Organization(name="Lowell High School PTSA",
                                community="Sunset families",
                                contact="LowellPTSA101@gmail.com",
                                inside_process=False);
    sunset_church = Organization(name="Sunset churches",
                                community="Sunset residents",
                                contact="", inside_process=False);
    for o in [richmond_ctr, geary_assoc] { o +>: serves :+> richmond; }
    for o in [lowell_ptsa, sunset_church] { o +>: serves :+> sunset; }

    t4 = Testimony(speaker="Opposition organizer",
                   affiliation="No on K campaign",
                   claim="Organized opposition never went east of West Portal; "
                         + "most of the city only heard 'a park'.",
                   kind="evidence");
    pk_anchor ++> t4;
    t4 +>: evidences :+> pk;

    print("seed_signal: ok");
}
