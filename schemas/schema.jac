# ============================================================
# schema.jac — FROZEN CONTRACT. Do not edit without telling the team.
# Owner: <name>
#
# Tier 1 = build now.  Tier 2 = stretch, do not block on it.
#
# P1 seeds instances in seed_signal.jac
# P2 seeds instances in seed_precedent.jac
# Both include THIS file. Neither edits it.
# ============================================================


# ------------------------------------------------------------
# JOIN CONTRACT — the one thing that breaks integration.
#
# Project.category (P1) is matched against PrecedentCase.category (P2).
# Both MUST come from this closed list. Adding a value = tell the team.
# ------------------------------------------------------------
glob CATEGORIES: list = [
    "renovation",       # park / facility rebuild
    "road_closure",     # street or highway closure, traffic reroute
    "zoning",           # land use / upzoning / downzoning
    "development",      # new construction, garage, private project
    "service_cut"       # transit line, clinic, library closure
];


# ------------------------------------------------------------
# ANCHORS — subgraph roots hanging off `root`
# ------------------------------------------------------------
node CaseAnchor    { has slug: str; has title: str; }     # one per demo case
node ActionAnchor  { has label: str = "precedents"; }     # P2's graph
node LawAnchor     { has label: str = "law"; }            # Tier 2


# ------------------------------------------------------------
# ISSUE — fetched at runtime, flat on arrival  (P1)
# ------------------------------------------------------------
node Project {
    has name: str;
    has category: str;              # renovation | road_closure | zoning | ...
    has location: str;
    has description: str = "";
    has timeline: str = "";
    has source_url: str = "";
    has fetched_at: str = "";       # empty string => curated, not fetched
}

node GeoZone {
    has name: str;
    has kind: str;                  # district | neighborhood | citywide
    has population_est: int = 0;
    has notes: str = "";
}

node Incident {
    has kind: str;                  # 311 | complaint_log
    has summary: str;
    has count: int = 1;
    has source_url: str = "";
}


# ------------------------------------------------------------
# NARRATIVE — fetched, flat on arrival, bound by Ingest  (P1)
# ------------------------------------------------------------
node Testimony {
    has speaker: str;
    has affiliation: str = "";
    has claim: str;
    has language: str = "en";
    has kind: str = "testimony";    # testimony | argument | evidence | counterargument
    has source_url: str = "";
}


# ------------------------------------------------------------
# INSTITUTION SKELETON — CURATED. Small, and load-bearing.  (P1)
# This is the part you cannot flatten: `accountable_to` exists in no API.
# ------------------------------------------------------------
node DecisionBody {
    has name: str;
    has kind: str;                  # commission | supervisor | board | electorate
    has jurisdiction: str;
}

node Organization {
    has name: str;
    has community: str = "";
    has language: str = "en";
    has contact: str = "";
    has inside_process: bool = false;   # was it in the official consultation?
}


# ------------------------------------------------------------
# PROCEDURE — CURATED, CHEAP, NON-NEGOTIABLE.  (P1)
# Split out of "Law" deliberately: this is what the playbook is made of.
# Every instance MUST carry source_url. No citation => do not create the node.
# ------------------------------------------------------------
node CommentChannel {
    has recipient: str;
    has method: str;                # email | web_form | in_person | mail
    has format_note: str = "";
    has languages: str = "en";
    has source_url: str;
}

node Deadline {
    has kind: str;                  # comment | appeal | signature | hearing
    has date: str;                  # ISO. "unknown" is allowed; a guess is not.
    has threshold: str = "";        # e.g. signature count, if applicable
    has source_url: str;
}


# ------------------------------------------------------------
# ACTION — CURATED precedent graph  (P2, primary owner)
# ------------------------------------------------------------
node PrecedentCase {
    has name: str;
    has category: str;
    has location: str;
    has year: int = 0;
    has source_url: str = "";
}

node Tactic {
    has name: str;                  # public_comment | ballot_measure | litigation | recall | petition
    has description: str = "";
}

node Outcome {
    has result: str;                # succeeded | failed | partial | unresolved
    has note: str = "";
    has verified: bool = false;     # false => do NOT claim it on stage
}


# ------------------------------------------------------------
# LAW — TIER 2. Schema only for now. Do not block on instances.
# ------------------------------------------------------------
node LegalStandard {
    has name: str;                  # e.g. environmental review, landmark preservation
    has authority: str = "";
    has test: str = "";             # what a claim must show to satisfy it
    has source_url: str = "";
}


# ------------------------------------------------------------
# EDGES
# curated = written by hand in seed.jac
# ingest  = created at runtime by the Ingest walker
# ------------------------------------------------------------
edge located_in       {}                              # Project  -> GeoZone     (ingest)
edge decided_by       {}                              # Project  -> DecisionBody(ingest)
edge accountable_to   {}                              # DecisionBody -> GeoZone (CURATED — hero edge)
edge accepts_input_via{}                              # DecisionBody -> CommentChannel (curated)
edge governed_by      {}                              # CommentChannel -> Deadline (curated)
edge serves           {}                              # Organization -> GeoZone (curated)
edge evidences        { has confidence: float = 0.0; } # Testimony -> Project   (ingest)
edge rebuts           {}                              # Testimony -> Testimony  (ingest)
edge analogous_to     { has score: float = 0.0; }     # Project -> PrecedentCase(ingest)
edge used             {}                              # PrecedentCase -> Tactic (curated)
edge resulted_in      {}                              # Tactic -> Outcome       (curated)

# --- Tier 2 edges: declare now, populate later ---
edge supports_claim_under { has confidence: float = 0.0; }  # Testimony -> LegalStandard
edge relied_on            {}                                # Tactic -> LegalStandard
