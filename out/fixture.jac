# ---- GeoZones (from ingest fixture) ----
chinatown = GeoZone(name="Chinatown", kind="neighborhood", population_est=0, notes="");
district_3 = GeoZone(name="District 3", kind="district", population_est=0, notes="");
sunset = GeoZone(name="Sunset", kind="neighborhood", population_est=0, notes="");
richmond = GeoZone(name="Richmond", kind="neighborhood", population_est=0, notes="");
san_francisco = GeoZone(name="San Francisco (citywide electorate)", kind="citywide", population_est=0, notes="");

# ---- DecisionBodies ----
sf_recreation = DecisionBody(name="SF Recreation and Park Department", kind="commission", jurisdiction="citywide agency");
sf_recreation +>: accountable_to :+> san_francisco;
district_32 = DecisionBody(name="District 3 Supervisor's Office", kind="supervisor", jurisdiction="District 3");
district_32 +>: accountable_to :+> district_3;
san_francisco2 = DecisionBody(name="San Francisco citywide electorate", kind="electorate", jurisdiction="citywide");
san_francisco2 +>: accountable_to :+> san_francisco;
sf_planning = DecisionBody(name="SF Planning Department", kind="department", jurisdiction="citywide agency");
sf_planning +>: accountable_to :+> san_francisco;

# ---- Organizations ----
chinese_consolidated = Organization(name="Chinese Consolidated Benevolent Association", community="Chinatown family associations", language="zh", contact="info@chssc.org", inside_process=False);
chinese_consolidated +>: serves :+> chinatown;
merchants_united = Organization(name="Merchants United Association of San Francisco", community="Chinatown / Sunset / Ocean Ave merchants", language="zh", contact="", inside_process=False);
merchants_united +>: serves :+> chinatown;
sf_chamber = Organization(name="SF Chamber of Commerce", community="San Francisco business community", language="en", contact="info@sfchamber.com, 415.392.4520", inside_process=False);
sf_chamber +>: serves :+> san_francisco;
community_youth = Organization(name="Community Youth Center", community="Chinatown youth and families", language="zh", contact="hello@cycsf.org, (415) 775-1345", inside_process=False);
community_youth +>: serves :+> chinatown;
chinatown_community = Organization(name="Chinatown Community Development Center", community="Chinatown residents", language="en", contact="info@chinatowncdc.org", inside_process=True);
chinatown_community +>: serves :+> chinatown;
richmond_neighborhood = Organization(name="Richmond Neighborhood Center", community="Richmond residents", language="en", contact="", inside_process=False);
richmond_neighborhood +>: serves :+> richmond;
geary_merchants = Organization(name="Geary Merchants Association", community="Richmond merchants", language="en", contact="", inside_process=False);
geary_merchants +>: serves :+> richmond;
lowell_high = Organization(name="Lowell High School PTSA", community="Sunset families", language="en", contact="LowellPTSA101@gmail.com", inside_process=False);
lowell_high +>: serves :+> sunset;
sunset_churches = Organization(name="Sunset churches", community="Sunset residents", language="en", contact="", inside_process=False);
sunset_churches +>: serves :+> sunset;

# ---- Projects ----
portsmouth_square = Project(
    name="Portsmouth Square Improvement Project",
    category="renovation",
    location="Portsmouth Square, Chinatown, San Francisco",
    description="~$73M renovation; pedestrian bridge over Kearny St removed to make room for a larger two-story clubhouse. Park closed for roughly two years from June 2026.",
    timeline="groundbreaking June 2026",
    source_url="",
    fetched_at=""
);
portsmouth_square +>: located_in :+> chinatown;
portsmouth_square +>: located_in :+> district_3;
portsmouth_square +>: decided_by :+> sf_recreation;
portsmouth_square +>: decided_by :+> district_32;
proposition_k = Project(
    name="Proposition K (Upper Great Highway closure)",
    category="road_closure",
    location="Upper Great Highway, Lincoln Way to Sloat Blvd",
    description="Nov 5 2024 ballot measure permanently closing the Upper Great Highway to private cars. Passed citywide 54.73%. Lost ~60-40 in the Sunset and ~70-30 in the Richmond; Districts 1/4/7/11 combined ~61% no.",
    timeline="passed Nov 2024",
    source_url="",
    fetched_at=""
);
proposition_k +>: located_in :+> sunset;
proposition_k +>: located_in :+> richmond;
proposition_k +>: decided_by :+> san_francisco2;

# ---- CommentChannels + Deadlines ----
# NOTE: wire each channel to its DecisionBody by hand with
# `+>: accepts_input_via :+>` — the fixture doesn't carry
# that link explicitly, so don't guess it here.
planning_department_ch = CommentChannel(recipient="Planning Department", method="email", format_note="reference agenda item number", languages="English, 繁體中文, Español, Filipino, Tiếng Việt", source_url="https://sfplanning.org/public-hearings");
planning_department_ch_deadline = Deadline(kind="comment", date="unknown", threshold="", source_url="https://sfplanning.org/public-hearings");
planning_department_ch +>: governed_by :+> planning_department_ch_deadline;
julie_moore_ch = CommentChannel(recipient="Julie Moore, EIR Coordinator, San Francisco Planning Department", method="email", format_note="Public comments concerning the scope of the EIR should be addressed to the specified recipient.", languages="English,繁體中文,Español,Filipino,Tiếng Việt", source_url="https://sfplanning.org/event/public-scoping-meeting-lake-merced-west-project");
julie_moore_ch_deadline = Deadline(kind="comment", date="2021-07-09", threshold="", source_url="https://sfplanning.org/event/public-scoping-meeting-lake-merced-west-project");
julie_moore_ch +>: governed_by :+> julie_moore_ch_deadline;
elizabeth_white_ch = CommentChannel(recipient="Elizabeth White, EIR Coordinator, San Francisco Planning Department", method="email", format_note="Public comments concerning the scope of the EIR should be directed to the recipient.", languages="Spanish, Cantonese, Filipino", source_url="https://sfplanning.org/event/public-scoping-meeting-housing-element");
elizabeth_white_ch_deadline = Deadline(kind="comment", date="2021-07-16", threshold="", source_url="https://sfplanning.org/event/public-scoping-meeting-housing-element");
elizabeth_white_ch +>: governed_by :+> elizabeth_white_ch_deadline;

# ---- Testimony ----
ccba_board_t = Testimony(speaker="CCBA board member (5 decades)", affiliation="CCBA", claim="Bridge let seniors and children cross Kearny safely; removal harms community access. Never heard the plan from city officials.", language="zh", kind="testimony", source_url="");
merchants_association_t = Testimony(speaker="Merchants association president", affiliation="Merchants United", claim="Three simultaneous Chinatown construction projects compound harm to merchants.", language="zh", kind="testimony", source_url="");
district_3_t = Testimony(speaker="District 3 Supervisor", affiliation="D3 Supervisor's Office", claim="Office received no communication supporting keeping the bridge.", language="en", kind="counterargument", source_url="");
opposition_organizer_t = Testimony(speaker="Opposition organizer", affiliation="No on K campaign", claim="Organized opposition never went east of West Portal; most of the city only heard 'a park'.", language="en", kind="evidence", source_url="");
chinese_cultural_t = Testimony(speaker="Chinese Cultural Foundation", affiliation="Chinese Cultural Foundation", claim="The Portsmouth Square Bridge is about Chinatown's history and culture and should not be removed.", language="en", kind="testimony", source_url="https://www.windnewspaper.com/article/the-community-opposes-the-removal-of-a-historic-pedestrian-bridge-with-good-feng-shui-for-renovating-portsmouth-square");
architect_t = Testimony(speaker="Architect", affiliation="Architect", claim="The City has never shown an alternative design keeping the Bridge although the EIR clearly mentioned it.", language="en", kind="argument", source_url="https://www.windnewspaper.com/article/the-community-opposes-the-removal-of-a-historic-pedestrian-bridge-with-good-feng-shui-for-renovating-portsmouth-square");
construction_firm_t = Testimony(speaker="Construction Firm Owner", affiliation="Construction Firm Owner", claim="If the Portsmouth Square Bridge is removed, the economy in Chinatown is expected to worsen.", language="en", kind="argument", source_url="https://www.windnewspaper.com/article/the-community-opposes-the-removal-of-a-historic-pedestrian-bridge-with-good-feng-shui-for-renovating-portsmouth-square");
ccba_board_t2 = Testimony(speaker="CCBA Board Member", affiliation="CCBA", claim="The bridge provides a huge open space; the City's claim that removal will create more open spaces doesn't make sense.", language="en", kind="argument", source_url="https://www.windnewspaper.com/article/the-community-opposes-the-removal-of-a-historic-pedestrian-bridge-with-good-feng-shui-for-renovating-portsmouth-square");
kite_shop_t = Testimony(speaker="Kite Shop Owner", affiliation="Chinatown merchant", claim="The bridge should not be removed; it is crucial for the community's health and safety.", language="en", kind="argument", source_url="https://www.windnewspaper.com/article/the-community-opposes-the-removal-of-a-historic-pedestrian-bridge-with-good-feng-shui-for-renovating-portsmouth-square");
local_historian_t = Testimony(speaker="Local Historian", affiliation="", claim="The bridge represented the financial and civic power that Chinese Americans achieved after World War II despite systemic racism.", language="en", kind="testimony", source_url="https://www.youtube.com/watch?v=gmbc4GC1Fng");
local_activists_t = Testimony(speaker="Local Activists", affiliation="", claim="Using public money for the bridge was a misallocation of resources that should have gone towards essential housing for residents.", language="en", kind="argument", source_url="https://www.youtube.com/watch?v=gmbc4GC1Fng");
plaintiff_t = Testimony(speaker="Plaintiff", affiliation="Prop K CEQA lawsuit", claim="We feel very confident in our arguments and believe the judge is misreading them.", language="en", kind="testimony", source_url="https://richmondsunsetnews.com/2026/02/08/effort-underway-to-send-ugh-compromise-back-to-voters/");
campaign_consultant_t = Testimony(speaker="Campaign Consultant", affiliation="Prop K campaign", claim="The way Prop. K was presented was misleading and did not reflect the realities of working-class people who need the highway.", language="en", kind="argument", source_url="https://richmondsunsetnews.com/2026/02/08/effort-underway-to-send-ugh-compromise-back-to-voters/");
former_sfpd_t = Testimony(speaker="Former SFPD Commander", affiliation="", claim="The organized opposition never informed a large part of the city about the true impacts of Prop. K's closure.", language="en", kind="counterargument", source_url="https://richmondsunsetnews.com/2026/02/08/effort-underway-to-send-ugh-compromise-back-to-voters/");
board_of_t = Testimony(speaker="Board of Supervisors President", affiliation="Board of Supervisors", claim="This measure is divisive and an 'unfunded mandate.'", language="en", kind="argument", source_url="https://www.sfpublicpress.org/proposition-k-authorize-great-highway-to-become-car-free-possibly-a-park/");
board_of_t2 = Testimony(speaker="Board of Supervisors member", affiliation="Board of Supervisors", claim="Closing the Upper Great Highway could leave the city's Chinese American community feeling isolated.", language="en", kind="argument", source_url="https://www.sfpublicpress.org/proposition-k-authorize-great-highway-to-become-car-free-possibly-a-park/");
board_of_t3 = Testimony(speaker="Board of Supervisors member", affiliation="Board of Supervisors", claim="Proposition K is a 'once-in-a-century opportunity' to transform the road into an iconic oceanside park that could bring the Sunset to life.", language="en", kind="argument", source_url="https://www.sfpublicpress.org/proposition-k-authorize-great-highway-to-become-car-free-possibly-a-park/");
neighborhood_group_t = Testimony(speaker="Neighborhood Group", affiliation="Coalition for San Francisco Neighborhoods", claim="Permanently closing the Upper Great Highway to vehicles could worsen traffic and divert it into residential areas, as well as lengthen commutes.", language="en", kind="argument", source_url="https://www.sfpublicpress.org/proposition-k-authorize-great-highway-to-become-car-free-possibly-a-park/");
merchants_association_t2 = Testimony(speaker="Merchants Association", affiliation="Great Highway-area merchants", claim="These inconveniences would discourage long-time customers from continuing to patronize them.", language="en", kind="argument", source_url="https://www.sfpublicpress.org/proposition-k-authorize-great-highway-to-become-car-free-possibly-a-park/");
san_francisco_t = Testimony(speaker="San Francisco Controller's Office", affiliation="City Government", claim="Maintaining private vehicle access costs the city $350,000 to $700,000 per year for sand removal.", language="en", kind="evidence", source_url="https://www.spur.org/voter-guide/2024-11/sf-prop-k-upper-great-highway");
spur_t = Testimony(speaker="SPUR", affiliation="SPUR", claim="Prop. K would help fulfill goals of increasing access to shared public amenities and addressing sea level rise.", language="en", kind="argument", source_url="https://www.spur.org/voter-guide/2024-11/sf-prop-k-upper-great-highway");
trust_for_t = Testimony(speaker="Trust for Public Land", affiliation="Non-profit Organization", claim="Low-income neighborhoods would benefit from enhanced access to open space if Prop. K passes.", language="en", kind="argument", source_url="https://www.spur.org/voter-guide/2024-11/sf-prop-k-upper-great-highway");
# NOTE: wire each with `ps_anchor ++> t;` / `pk_anchor ++> t;`
# and `t +>: evidences :+> <project_var>;` by hand — anchor
# choice is a curation decision, not something the fixture encodes.

# ---- Incidents ----
