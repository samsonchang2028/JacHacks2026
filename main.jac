"""Quorum civic graph: schema, seed data, and the walkers the UI spawns.

The edges are the content. Which body decides an issue, which constituency that
body answers to, and which zone the harm lands in are three different edges --
and the gap between the last two is the whole product (see divergence below).

ponytail: schema + seed + walkers live in one file so there is no cross-module
symbol resolution to debug mid-hackathon. Split when it stops fitting on screen.
"""

# ================================================================= schema

node Issue {
    has slug: str,
        title: str,
        district: str,
        lat: float,
        lng: float,
        # "full" = complete procedural record; "thin" = seeded, no record yet
        tier: str = "thin",
        # One-sentence version for the side panel. The long `problem` brief is
        # for the workup page, where there is room for it.
        short: str = "",
        problem: str = "",
        srcs: list = [],
        # "electorate" | "channel" | "" -- the failure mode the verdict renders.
        # Zone mismatch alone is not enough: Portsmouth zones match, and the
        # failure is still real (empty channel record).
        failure_kind: str = "",
        verdict_headline: str = "",
        verdict_why: str = "",
        correction_h: str = "",
        correction_p: str = "",
        # What the channel counts / does not count. Retrieved content, not LLM.
        counts: list = [],
        not_counts: list = [];
}

node DecisionBody {
    has name: str,
        accountable_note: str = "",
        source_url: str = "",
        retrieved_at: str = "";
}

node GeoZone {
    has name: str,
        # "district" or "citywide" -- the kind is what makes divergence legible
        kind: str = "district";
}

node CommentChannel {
    has name: str,
        format: str = "",
        source_url: str = "",
        retrieved_at: str = "";
}

node Deadline {
    has label: str,
        due: str = "",
        source_url: str = "",
        retrieved_at: str = "";
}

node Organization {
    has name: str,
        initials: str = "",
        role: str = "",
        language: str = "EN";
}

node PrecedentCase {
    has title: str,
        summary: str = "",
        channel_used: str = "",
        outcome: str = "",
        source_url: str = "",
        retrieved_at: str = "";
}

node ActionStep {
    has rank: int,
        what: str,
        how: str = "";
}

"""A community note. Hangs off root -- deliberately not tied to an Issue.

ponytail: no timestamp field; the list is ordered newest-first by insertion
order. Add a datetime import if admins ever need actual dates.
"""
node Concern {
    has name: str,
        body: str;
}

edge decided_by {}
edge impacts {}
edge accountable_to {}
edge accepts_input_via {}
edge has_deadline {}
edge organized_by {}
edge analogous_to {}
edge suggests {}

# ================================================================= seed

walker:pub seed_graph {
    """Idempotent seed. Safe to spawn on every page load."""

    can build with Root entry {
        existing = [-->[?:Issue]];
        if len(existing) > 0 {
            report {"seeded": False, "issues": len(existing)};
            disengage;
        }

        # ---- zones -------------------------------------------------
        chinatown = root ++> GeoZone(name="Chinatown / District 3", kind="district");
        westside = root ++> GeoZone(name="Sunset / Richmond", kind="district");
        citywide = root ++> GeoZone(name="Citywide electorate", kind="citywide");

        # ---- Portsmouth Square ------------------------------------
        recpark = root ++> DecisionBody(
            name="SF Recreation and Park Commission",
            accountable_note="Mayor-appointed; the District 3 supervisor's office fields constituent input",
            source_url="https://sfrecpark.org/", retrieved_at="2026-07-26"
        );
        # A commission answers to the district whose park it is deciding on.
        recpark[0] +>:accountable_to:+> chinatown[0];

        rp_channel = root ++> CommentChannel(
            name="Commission general public comment",
            format="Written to the Commission Secretary, or in person at a regular meeting",
            source_url="https://sfrecpark.org/",
            retrieved_at="2026-07-26"
        );
        recpark[0] +>:accepts_input_via:+> rp_channel[0];

        # No citation for this one on purpose -- the UI must render a gap,
        # not a plausible-looking guess. See the retrieval-not-generation rule.
        rp_due = root ++> Deadline(label="Next comment deadline", due="", source_url="", retrieved_at="");
        rp_channel[0] +>:has_deadline:+> rp_due[0];

        ps = root ++> Issue(
            slug="portsmouth-square",
            title="Portsmouth Square renovation",
            district="Chinatown / District 3",
            lat=37.7947, lng=-122.4058, tier="full",
            short="A historic pedestrian bridge is being demolished. The opposition is organized -- but the supervisor's office has no record of it.",
            problem="A $73M renovation broke ground in June 2026, closing the park for roughly two years.[1] The renovation is broadly supported; the contested piece is the removal of the historic pedestrian bridge over Kearny Street, demolished to make room for a larger two-story clubhouse.[2] Opposition exists and is organized -- but District 3 Supervisor Danny Sauter said he was unaware of opposition to the bridge removal, and that his office had received no communication in support of keeping it.[3] City survey data reportedly showed 77% of residents supported the demolition; the argument here is about process, not unanimity.[4]",
            srcs=[
                "SF Recreation and Park -- Portsmouth Square Improvement Project record",
                "Local news coverage -- Kearny Street pedestrian bridge demolition",
                "Supervisor Danny Sauter (D3) -- quoted statement on constituent input",
                "City survey data on the bridge demolition, as cited in coverage"
            ],
            failure_kind="channel",
            verdict_headline="The community had a position. The official record had nothing.",
            verdict_why="The zones match here: the Rec & Park Commission answers to the same District 3 the demolition lands on. So the failure is not geography, it is routing. An organized, in-language opposition has been talking to each other and to the press, while Supervisor Sauter says his office received no communication in support of keeping the bridge.",
            correction_h="Put the position into the record, through the channel that counts.",
            correction_p="Nothing needs to be persuaded here; it needs to be filed. Written comment to the Commission Secretary and CCBA speakers on the record are what the body actually counts. Volume in the wrong place is invisible to it.",
            counts=[
                "Written comment to the Commission Secretary, one distinct submitter, in their own words",
                "In-language comment; Chinese submissions are accepted on the record",
                "An association of record (CCBA) speaking at general public comment",
                "A position formally logged by the D3 supervisor's office"
            ],
            not_counts=[
                "Bulk-generated identical emails; staff recognise and discount them",
                "Press coverage and social posts; they do not enter the Commission record",
                "Protest outside the site alone, with nothing filed"
            ]
        );
        ps[0] +>:decided_by:+> recpark[0];
        ps[0] +>:impacts:+> chinatown[0];

        ccba = root ++> Organization(
            name="CCBA", initials="CC", language="中文 / EN",
            role="176-year-old association representing Chinatown's family associations. Says it was never invited to project-related community meetings."
        );
        ng = root ++> Organization(
            name="Thomas Ng", initials="TN", language="中文",
            role="CCBA board member of five decades. Opposes the bridge removal; says he never heard the plan from city officials."
        );
        siu = root ++> Organization(
            name="Merchants United Association", initials="MU", language="中文 / EN",
            role="Ed Siu -- represents 150+ merchants. Protested the removal and the three simultaneous Chinatown construction projects."
        );
        ps[0] +>:organized_by:+> ccba[0];
        ps[0] +>:organized_by:+> ng[0];
        ps[0] +>:organized_by:+> siu[0];

        ps_a1 = root ++> ActionStep(
            rank=1, what="Submit written comment to the Rec & Park Commission Secretary",
            how="The countable unit is a distinct submitter, not a distinct email. Ask people to write in their own words -- staff recognise and discount bulk-generated comment."
        );
        ps_a2 = root ++> ActionStep(
            rank=2, what="Register CCBA speakers for general public comment",
            how="An association of record speaking on the record outweighs volume. Bring the in-language speakers."
        );
        ps_a3 = root ++> ActionStep(
            rank=3, what="Ask the D3 supervisor's office to log the position formally",
            how="The supervisor said he received no communication. Closing that gap is the whole objective."
        );
        ps[0] +>:suggests:+> ps_a1[0];
        ps[0] +>:suggests:+> ps_a2[0];
        ps[0] +>:suggests:+> ps_a3[0];

        # ---- Proposition K ----------------------------------------
        electorate = root ++> DecisionBody(
            name="Citywide electorate -- ballot measure",
            accountable_note="Answers to all 11 districts, not to the impact zone",
            source_url="https://sfelections.sfgov.org/", retrieved_at="2026-07-26"
        );
        # This is the edge that makes divergence detectable, and it exists in
        # no API -- it is the judgment that a ballot measure is decided citywide.
        electorate[0] +>:accountable_to:+> citywide[0];

        pk_channel = root ++> CommentChannel(
            name="Signature gathering, then citywide persuasion",
            format="Not district comment -- a measure is decided at the ballot",
            source_url="https://sfelections.sfgov.org/",
            retrieved_at="2026-07-26"
        );
        electorate[0] +>:accepts_input_via:+> pk_channel[0];

        pk_due = root ++> Deadline(label="Signature threshold and filing date", due="", source_url="", retrieved_at="");
        pk_channel[0] +>:has_deadline:+> pk_due[0];

        pk = root ++> Issue(
            slug="prop-k",
            title="Proposition K -- Great Highway",
            district="Sunset / Richmond / Citywide measure",
            lat=37.7597, lng=-122.5107, tier="full",
            short="The westside lost its own districts by 60-70 points and still lost the vote. The deciding audience was the rest of the city.",
            problem="Prop K passed citywide with 54.73% in November 2024, closing the Great Highway to cars.[1] It lost roughly 60-40 in the Sunset and 70-30 in the Richmond; across Districts 1, 4, 7 and 11 the split was about 61% no to 39% yes.[2] One opponent spent $269,000 against the measure.[3] They filed a CEQA challenge, lost, and appealed to the First Appellate District.[4] The opposition was well funded and well organized -- and aimed almost entirely at the districts that already agreed with it.",
            srcs=[
                "SF Department of Elections -- November 2024 certified results",
                "District-level returns, November 2024 general election",
                "Campaign finance filings -- opposition committee spending",
                "First Appellate District -- CEQA challenge and appeal record"
            ],
            failure_kind="electorate",
            verdict_headline="Your outreach is aimed at people who already agree.",
            verdict_why="Prop K passed citywide with 54.73%. It lost roughly 60-40 in the Sunset and 70-30 in the Richmond. The opposition was well funded and well organized, and it spent almost all of it inside the districts that already voted no. The impact zone and the decision zone are different graphs.",
            correction_h="Target undecided voters outside the impact zone.",
            correction_p="Every dollar spent west of Sunset Blvd is spent on people who already vote no. The persuadable surface is the eastside districts that heard 'a new park' and nothing about traffic or utilisation.",
            counts=[
                "Valid signatures from registered SF voters, citywide",
                "Persuasion of voters in districts that have not already decided",
                "Disclosed, compliant spending under FPPC and SF Ethics rules"
            ],
            not_counts=[
                "District-concentrated outreach in Sunset and Richmond, already decided",
                "Public comment to the Board of Supervisors, the wrong body for a measure",
                "Litigation after certification; the 2024 CEQA challenge lost and was appealed"
            ]
        );
        pk[0] +>:decided_by:+> electorate[0];
        pk[0] +>:impacts:+> westside[0];

        opp = root ++> Organization(
            name="Open the Great Highway", initials="OP", language="EN",
            role="Westside opposition campaign. One opponent spent $269,000 against the measure."
        );
        appellants = root ++> Organization(
            name="CEQA appellants", initials="AP", language="EN",
            role="Filed a challenge, lost, appealed to the First Appellate District. The court held that a minority of supervisors placing a measure on the ballot are not a public agency."
        );
        recall = root ++> Organization(
            name="Recall organizers", initials="RC", language="EN",
            role="Campaign prompted the successful recall of Supervisor Engardio. Now gathering signatures for a follow-up measure."
        );
        pk[0] +>:organized_by:+> opp[0];
        pk[0] +>:organized_by:+> appellants[0];
        pk[0] +>:organized_by:+> recall[0];

        pk_a1 = root ++> ActionStep(
            rank=1, what="Retarget persuasion to the eastside districts, not the westside",
            how="The westside is already convinced. Every dollar spent there is a dollar not spent on the deciding constituency."
        );
        pk_a2 = root ++> ActionStep(
            rank=2, what="Lead with local traffic impact, not park opposition",
            how="Eastside voters heard 'a new park' and little about utilisation or traffic. That information gap is the persuadable surface."
        );
        pk_a3 = root ++> ActionStep(
            rank=3, what="Check FPPC and SF Ethics disclosure before any spend",
            how="Ballot-measure spending triggers disclosure obligations; issue ads need platform authorisation and disclaimers."
        );
        pk[0] +>:suggests:+> pk_a1[0];
        pk[0] +>:suggests:+> pk_a2[0];
        pk[0] +>:suggests:+> pk_a3[0];

        # ---- precedent (hand-seeded; teammate's scraper replaces these) ----
        p1 = root ++> PrecedentCase(
            title="Chinatown Central Subway community review",
            summary="In-language written comment submitted at commission hearings.",
            channel_used="Commission written comment, in-language",
            outcome="win",
            source_url="https://www.sfmta.com/", retrieved_at="2026-07-26"
        );
        p2 = root ++> PrecedentCase(
            title="Prop K first campaign (2024)",
            summary="District-concentrated outreach plus litigation.",
            channel_used="CEQA challenge + district campaign",
            outcome="loss",
            source_url="https://sfelections.sfgov.org/", retrieved_at="2026-07-26"
        );
        ps[0] +>:analogous_to:+> p1[0];
        ps[0] +>:analogous_to:+> p2[0];
        pk[0] +>:analogous_to:+> p2[0];
        pk[0] +>:analogous_to:+> p1[0];

        # ---- thin pins: real open issues, no procedural record yet ----
        root ++> Issue(slug="panhandle-bike-lane", title="Panhandle bike lane redesign",
            district="Haight Ashbury / D5", lat=37.7699, lng=-122.4269, tier="thin");
        root ++> Issue(slug="tenderloin-sro", title="Tenderloin SRO habitability cases",
            district="Tenderloin / D6", lat=37.7841, lng=-122.4078, tier="thin");
        root ++> Issue(slug="mission-bus-lane", title="Mission St bus lane extension",
            district="Mission / D9", lat=37.7509, lng=-122.4184, tier="thin");
        root ++> Issue(slug="balboa-station", title="Balboa Park station access",
            district="Excelsior / D11", lat=37.7350, lng=-122.4340, tier="thin");
        root ++> Issue(slug="north-beach-parking", title="North Beach parking removal",
            district="North Beach / D3", lat=37.8020, lng=-122.4190, tier="thin");
        root ++> Issue(slug="lake-merced-erosion", title="Lake Merced shoreline erosion",
            district="Lakeshore / D7", lat=37.7280, lng=-122.4750, tier="thin");
        root ++> Issue(slug="bayview-rezoning", title="Bayview industrial rezoning",
            district="Bayview / D10", lat=37.7440, lng=-122.3900, tier="thin");

        report {"seeded": True, "issues": len([-->[?:Issue]])};
    }
}

# ================================================================= walkers

walker:pub find_issues {
    """Map payload. One hop from root."""

    can collect with Root entry {
        pins: list = [];
        for i in [-->[?:Issue]] {
            pins.append({
                "slug": i.slug, "title": i.title, "district": i.district,
                "lat": i.lat, "lng": i.lng, "tier": i.tier
            });
        }
        report pins;
    }
}

walker:pub issue_detail {
    """Everything the side panel and detail page render.

    Also reports `path` -- the nodes this walker actually visited -- which is
    what the graph traversal panel draws. The divergence answer lives in no
    single node: it is the comparison of two different terminal GeoZones.
    """

    has slug: str;

    can look_up with Root entry {
        matches = [i for i in [-->[?:Issue]] if i.slug == self.slug];
        if len(matches) == 0 {
            report {"found": False, "slug": self.slug};
            disengage;
        }
        issue = matches[0];
        # Annotated `list` on purpose: the checker otherwise pins the element
        # type to the first literal's shape and rejects every later hop.
        path: list = [];
        path.append({"kind": "Issue", "label": issue.title, "via": "root"});

        # --- decision zone: Issue -> DecisionBody -> accountable_to -> GeoZone
        body = None;
        decision_zone = None;
        channel = None;
        deadline = None;
        bodies = [issue->:decided_by:->][?:DecisionBody];
        if len(bodies) > 0 {
            body = bodies[0];
            path.append({"kind": "DecisionBody", "label": body.name, "via": "decided_by"});

            zones = [body->:accountable_to:->][?:GeoZone];
            if len(zones) > 0 {
                decision_zone = zones[0];
                path.append({"kind": "GeoZone", "label": decision_zone.name, "via": "accountable_to"});
            }

            channels = [body->:accepts_input_via:->][?:CommentChannel];
            if len(channels) > 0 {
                channel = channels[0];
                path.append({"kind": "CommentChannel", "label": channel.name, "via": "accepts_input_via"});

                dues = [channel->:has_deadline:->][?:Deadline];
                if len(dues) > 0 {
                    deadline = dues[0];
                    path.append({"kind": "Deadline", "label": deadline.label, "via": "has_deadline"});
                }
            }
        }

        # --- impact zone: Issue -> impacts -> GeoZone
        impact_zone = None;
        izones = [issue->:impacts:->][?:GeoZone];
        if len(izones) > 0 {
            impact_zone = izones[0];
            path.append({"kind": "GeoZone", "label": impact_zone.name, "via": "impacts"});
        }

        # --- zones + divergence ------------------------------------------
        # The divergence answer lives in no single node: it is either the
        # comparison of two terminal GeoZones, or an explicit channel failure
        # seeded on the Issue when the zones already match.
        zones_match = False;
        if decision_zone is not None and impact_zone is not None {
            zones_match = decision_zone.name == impact_zone.name;
        }

        kind = issue.failure_kind;
        if kind == "" and decision_zone is not None and impact_zone is not None {
            if not zones_match {
                kind = "electorate" if decision_zone.kind == "citywide" else "channel";
            }
        }

        divergence = None;
        if kind != "" {
            divergence = {
                "impact": impact_zone.name if impact_zone is not None else "",
                "decision": decision_zone.name if decision_zone is not None else "",
                "kind": kind,
                "match": zones_match,
                "headline": issue.verdict_headline,
                "why": issue.verdict_why,
                "correction_h": issue.correction_h,
                "correction_p": issue.correction_p
            };
        }

        # Human-readable route hops for the decision-routing page. Separate
        # from `path`, which also carries impact / precedent hops for the
        # engineer-facing traversal.
        route: list = [];
        route.append({
            "role": "The issue",
            "name": issue.title,
            "note": issue.district,
            "edge": "root",
            "deadline": False,
            "unverified": False
        });
        if body is not None {
            route.append({
                "role": "Is decided by",
                "name": body.name,
                "note": body.accountable_note,
                "edge": "decided_by",
                "deadline": False,
                "unverified": body.source_url == ""
            });
        }
        if decision_zone is not None {
            route.append({
                "role": "Which answers to",
                "name": decision_zone.name,
                "note": "Not the impact zone." if not zones_match else "The same zone the impact lands on.",
                "edge": "accountable_to",
                "deadline": False,
                "unverified": False
            });
        }
        if channel is not None {
            route.append({
                "role": "Accepts input via",
                "name": channel.name,
                "note": channel.format,
                "edge": "accepts_input_via",
                "deadline": False,
                "unverified": channel.source_url == ""
            });
        }
        if deadline is not None {
            due_missing = deadline.source_url == "" or deadline.due == "";
            route.append({
                "role": "By",
                "name": deadline.label,
                "note": "No verified source found. Quorum will not guess." if due_missing else deadline.due,
                "edge": "has_deadline",
                "deadline": True,
                "unverified": due_missing
            });
        }

        resources: list = [];
        if body is not None {
            resources.append({
                "label": "Who decides", "value": body.name,
                "source_url": body.source_url, "retrieved_at": body.retrieved_at
            });
            if body.accountable_note != "" {
                resources.append({
                    "label": "Accountable to", "value": body.accountable_note,
                    "source_url": body.source_url, "retrieved_at": body.retrieved_at
                });
            }
        }
        if channel is not None {
            resources.append({
                "label": "Channel that counts",
                "value": channel.name + " -- " + channel.format,
                "source_url": channel.source_url, "retrieved_at": channel.retrieved_at
            });
        }
        if deadline is not None {
            resources.append({
                "label": deadline.label,
                "value": deadline.due if deadline.due != "" else "No record retrieved",
                "source_url": deadline.source_url, "retrieved_at": deadline.retrieved_at
            });
        }

        # Sources table rows -- same facts as resources, plus an explicit
        # verified flag so the UI never has to infer it.
        sources: list = [];
        for r in resources {
            sources.append({
                "fact": r["label"] + ": " + r["value"],
                "source": r["source_url"] if r["source_url"] != "" else "Not found",
                "retrieved": r["retrieved_at"] if r["retrieved_at"] != "" else "Not found",
                "verified": r["source_url"] != ""
            });
        }

        orgs: list = [];
        for o in [issue->:organized_by:->][?:Organization] {
            orgs.append({
                "name": o.name, "initials": o.initials,
                "role": o.role, "language": o.language
            });
        }

        precedents: list = [];
        for p in [issue->:analogous_to:->][?:PrecedentCase] {
            precedents.append({
                "title": p.title, "summary": p.summary,
                "channel_used": p.channel_used, "outcome": p.outcome,
                "source_url": p.source_url, "retrieved_at": p.retrieved_at
            });
        }
        if len(precedents) > 0 {
            path.append({"kind": "PrecedentCase", "label": str(len(precedents)) + " matched", "via": "analogous_to"});
        }

        # Edges come back in insertion order and the seed writes them ranked,
        # so no sort is needed here.
        actions: list = [];
        for s in [issue->:suggests:->][?:ActionStep] {
            actions.append({"rank": s.rank, "what": s.what, "how": s.how});
        }

        report {
            "found": True,
            "slug": issue.slug, "title": issue.title, "district": issue.district,
            "tier": issue.tier, "short": issue.short,
            "problem": issue.problem, "srcs": issue.srcs,
            "divergence": divergence,
            "zones_match": zones_match,
            "impact_zone": impact_zone.name if impact_zone is not None else "",
            "decision_zone": decision_zone.name if decision_zone is not None else "",
            "organizers": orgs,
            "resources": resources,
            "sources": sources,
            "route": route,
            "counts": issue.counts,
            "not_counts": issue.not_counts,
            "precedents": precedents,
            "actions": actions,
            "path": path
        };
    }
}

glob NAME_MAX = 80;
glob BODY_MAX = 1000;


"""Every community note, newest first."""
def notes_payload() -> list {
    out: list = [];
    for c in [root-->[?:Concern]] {
        out.append({"name": c.name, "body": c.body});
    }
    out.reverse();
    return out;
}


walker:pub list_notes {
    """Read the community-notes wall."""

    can collect with Root entry {
        report notes_payload();
    }
}


walker:pub add_note {
    """Write a community note. Untrusted input -- validate before it lands.

    Reports the refreshed wall so the client re-renders from one spawn.
    """

    has name: str = "";
    has body: str = "";

    can write with Root entry {
        clean_body = self.body.strip();
        if clean_body == "" {
            report {"ok": False, "error": "Write a concern before submitting."};
            disengage;
        }
        clean_name = self.name.strip();
        if clean_name == "" {
            clean_name = "Anonymous";
        }

        root ++> Concern(name=clean_name[:NAME_MAX], body=clean_body[:BODY_MAX]);
        report {"ok": True, "notes": notes_payload()};
    }
}

# ================================================================= client

cl import "leaflet/dist/leaflet.css";
cl import "./assets/quorum.css";
cl import "./assets/landing.css";
cl import "./assets/actions.css";

cl {
    def:pub app(children: any = None) -> JsxElement {
        return <>{children}</>;
    }
}
