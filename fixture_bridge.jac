# ============================================================
# fixture_bridge.jac — UI-side reader for the backend artifact.
#
# The ingestion pipeline's one interface is out/fixture.json ("THE
# CONTRACT", ingest/README.md §1). This module reads that file — offline,
# no network — and anchors its records in the UI graph so the walkers in
# main.jac can report them. It never generates deadlines, contacts,
# channels, or authorities: a record either exists in the fixture with a
# source, or it is not here.
#
# Case mapping is provenance, not judgment:
#   - testimony / forum threads map to an issue by the case's own research
#     markers (subject terms that appear in the claim, affiliation, or
#     source URL). A record matching neither case — or both — stays
#     anchored to root, unmapped and counted, never force-assigned.
#   - organizations map by the case manifests' org_candidates lists
#     (ingest/config/cases/*.yaml) — the pipeline's own record of which
#     orgs were researched for which case. Mapping an org to an issue
#     asserts reachability only, never a position on the issue.
#   - comment channels are deliberately mapped to NOTHING. The fixture
#     contract carries no channel→body binding, so the UI shows them as
#     unbound pipeline records rather than guessing (the GAP is a finding).
# ============================================================

import json;
import from pathlib { Path }


# ---- pipeline-record archetypes -----------------------------------------
# Names follow the fixture contract's collections (testimony, incidents),
# so the graph vocabulary matches ingest/extract/schemas.py.

node Testimony {
    has speaker: str,
        claim: str,
        affiliation: str = "",
        language: str = "en",
        kind: str = "testimony",
        source_url: str = "";
}

"""One community-forum thread from the fixture's `incidents` collection."""
node Incident {
    has summary: str,
        count: int = 0,
        kind: str = "forum",
        source_url: str = "";
}

"""A verified comment channel on file. Never bound to a decision body:
the fixture contract has no such binding and this module will not invent
one — the walkers surface that as the gap it is."""
node PipelineChannel {
    has recipient: str,
        method: str = "",
        format_note: str = "",
        languages: str = "en",
        source_url: str = "",
        deadline_kind: str = "",
        deadline_date: str = "",
        deadline_source: str = "";
}

"""An organization from the pipeline's contact research. `inside_process`
is the hand-set judgment from config/orgs.yaml ("true"/"false", "" when the
fixture had none). A blank contact is an honest blank — `notes` says where
the pipeline looked."""
node PipelineOrg {
    has name: str,
        initials: str = "",
        community: str = "",
        language: str = "en",
        contact: str = "",
        inside_process: str = "",
        notes: str = "";
}

edge has_testimony {}
edge has_signal {}
edge has_outreach_org {}


# ---- case mapping tables -------------------------------------------------
# Subject markers drawn from the two case manifests' own search terms and
# descriptions (ingest/config/cases/{portsmouth-square,prop-k-great-highway}
# .yaml). Lowercase; matched against claim + affiliation + source URL.

glob PORTSMOUTH_MARKERS: list[str] = [
    "portsmouth", "kearny", "chinatown", "ccba",
    "pedestrian bridge", "the bridge",
];
glob PROP_K_MARKERS: list[str] = [
    "great highway", "great-highway", "great_highway",
    "prop k", "prop. k", "prop-k", "prop_k", "proposition k",
    "no on k", "ugh compromise", "ugh-compromise",
];

# Mirrors org_candidates in the two verified case manifests. The manifest
# slug prop-k-great-highway is the UI issue slug "prop-k". A new case means
# extending this table alongside its manifest (kept literal here so the UI
# has no YAML dependency).
glob CASE_ORG_CANDIDATES: dict[str, list[str]] = {
    "portsmouth-square": [
        "Chinese Consolidated Benevolent Association",
        "Merchants United Association of San Francisco",
        "Chinatown Community Development Center",
        "Community Youth Center",
        "SF Chamber of Commerce",
    ],
    "prop-k": [
        "Richmond Neighborhood Center",
        "Geary Merchants Association",
        "Lowell High School PTSA",
        "Sunset churches",
    ],
};

# Fixture org name -> curated organizer node name in main.jac's seed.
# These two are the same real-world org under two names; the pipeline's
# contact and inside_process land on the existing organizer card instead
# of duplicating it.
glob UI_ORG_ALIASES: dict[str, str] = {
    "Chinese Consolidated Benevolent Association": "CCBA",
    "Merchants United Association of San Francisco": "Merchants United Association",
};


# ---- fixture loading -----------------------------------------------------

def fixture_path() -> str {
    return str(Path(__file__ or "").resolve().parent / "out" / "fixture.json");
}


"""Read out/fixture.json; {} when missing or unreadable (the UI renders
that as 'pipeline record not loaded', never as an error page)."""
def load_fixture() -> dict {
    path = Path(fixture_path());
    if not path.exists() {
        return {};
    }
    try {
        with open(str(path), "r", encoding="utf-8") as fixture_file {
            loaded = json.load(fixture_file);
        }
    } except Exception {
        return {};
    }
    if isinstance(loaded, dict) {
        return loaded;
    }
    return {};
}


def fixture_list(fixture: dict, key: str) -> list {
    value = fixture.get(key);
    if isinstance(value, list) {
        return value;
    }
    return [];
}


def text_of(record: dict, key: str) -> str {
    value = record.get(key);
    return value if isinstance(value, str) else "";
}


def int_of(record: dict, key: str, fallback: int) -> int {
    value = record.get(key);
    return value if isinstance(value, int) else fallback;
}


# ---- deterministic case mapping -------------------------------------------

"""Which issue a record was collected for, by subject markers in its own
text. Ambiguous or unmatched -> "" (kept unmapped, not force-assigned)."""
def case_slug_for(text: str) -> str {
    hay = text.lower();
    is_ps = False;
    is_pk = False;
    for marker in PORTSMOUTH_MARKERS {
        if marker in hay {
            is_ps = True;
        }
    }
    for marker in PROP_K_MARKERS {
        if marker in hay {
            is_pk = True;
        }
    }
    if is_ps and not is_pk {
        return "portsmouth-square";
    }
    if is_pk and not is_ps {
        return "prop-k";
    }
    return "";
}


def org_case_slug(org_name: str) -> str {
    for slug in CASE_ORG_CANDIDATES {
        for candidate in CASE_ORG_CANDIDATES[slug] {
            if candidate == org_name {
                return slug;
            }
        }
    }
    return "";
}


def initials_for(name: str) -> str {
    parts = [p for p in name.split() if len(p) > 0];
    if len(parts) >= 2 {
        return (parts[0][:1] + parts[1][:1]).upper();
    }
    if len(parts) == 1 {
        return parts[0][:2].upper();
    }
    return "?";
}


# ---- attach ----------------------------------------------------------------

"""Idempotent: attaches the fixture once per graph (guarded on any pipeline
node already existing), then only reports what is there. Every node is
anchored to root so it persists and so the guard can see it; mapped records
additionally hang off their issue via a typed edge."""
def attach_fixture(issues: list, organizers: list) -> dict {
    already = 0;
    for item in [root -->] {
        if (
            isinstance(item, Testimony)
            or isinstance(item, Incident)
            or isinstance(item, PipelineChannel)
            or isinstance(item, PipelineOrg)
        ) {
            already += 1;
        }
    }
    if already > 0 {
        return pipeline_status();
    }

    fixture = load_fixture();
    if len(fixture) == 0 {
        return pipeline_status();
    }

    by_slug: dict = {};
    for issue in issues {
        by_slug[issue.slug] = issue;
    }
    org_by_name: dict = {};
    for org in organizers {
        org_by_name[org.name] = org;
    }

    for record in fixture_list(fixture, "testimony") {
        if not isinstance(record, dict) {
            continue;
        }
        speaker = text_of(record, "speaker");
        claim = text_of(record, "claim");
        if speaker == "" or claim == "" {
            continue;
        }
        affiliation = text_of(record, "affiliation");
        source_url = text_of(record, "source_url");
        t = Testimony(
            speaker=speaker,
            claim=claim,
            affiliation=affiliation,
            language=text_of(record, "language"),
            kind=text_of(record, "kind"),
            source_url=source_url,
        );
        root ++> t;
        slug = case_slug_for(claim + " " + affiliation + " " + source_url);
        if slug in by_slug {
            by_slug[slug] +>:has_testimony:+> t;
        }
    }

    for record in fixture_list(fixture, "incidents") {
        if not isinstance(record, dict) {
            continue;
        }
        summary = text_of(record, "summary");
        if summary == "" {
            continue;
        }
        source_url = text_of(record, "source_url");
        sig = Incident(
            summary=summary,
            count=int_of(record, "count", 1),
            kind=text_of(record, "kind"),
            source_url=source_url,
        );
        root ++> sig;
        slug = case_slug_for(summary + " " + source_url);
        if slug in by_slug {
            by_slug[slug] +>:has_signal:+> sig;
        }
    }

    for record in fixture_list(fixture, "comment_channels") {
        if not isinstance(record, dict) {
            continue;
        }
        recipient = text_of(record, "recipient");
        source_url = text_of(record, "source_url");
        if recipient == "" or source_url == "" {
            continue;
        }
        # The contract allows several deadlines; the current fixture carries
        # at most one per channel, so the first is kept and shown.
        d_kind = "";
        d_date = "";
        d_source = "";
        deadlines = record.get("deadlines");
        if isinstance(deadlines, list) and len(deadlines) > 0 {
            first = deadlines[0];
            if isinstance(first, dict) {
                d_kind = text_of(first, "kind");
                d_date = text_of(first, "date");
                d_source = text_of(first, "source_url");
            }
        }
        chan = PipelineChannel(
            recipient=recipient,
            method=text_of(record, "method"),
            format_note=text_of(record, "format_note"),
            languages=text_of(record, "languages"),
            source_url=source_url,
            deadline_kind=d_kind,
            deadline_date=d_date,
            deadline_source=d_source,
        );
        root ++> chan;
    }

    for record in fixture_list(fixture, "organizations") {
        if not isinstance(record, dict) {
            continue;
        }
        name = text_of(record, "name");
        if name == "" {
            continue;
        }
        inside = record.get("inside_process");
        inside_str = "";
        if isinstance(inside, bool) {
            inside_str = "true" if inside else "false";
        }
        contact = text_of(record, "contact");
        community = text_of(record, "community");
        notes = text_of(record, "notes");
        language = text_of(record, "language");

        alias = UI_ORG_ALIASES.get(name, "");
        if alias != "" and alias in org_by_name {
            ui_org = org_by_name[alias];
            ui_org.community = community;
            ui_org.contact = contact;
            ui_org.inside_process = inside_str;
            ui_org.notes = notes;
            continue;
        }

        po = PipelineOrg(
            name=name,
            initials=initials_for(name),
            community=community,
            language=language,
            contact=contact,
            inside_process=inside_str,
            notes=notes,
        );
        root ++> po;
        slug = org_case_slug(name);
        if slug in by_slug {
            by_slug[slug] +>:has_outreach_org:+> po;
        }
    }

    return pipeline_status();
}


# ---- projections the walkers report ----------------------------------------

def pipeline_status() -> dict {
    testimony_n = 0;
    signal_n = 0;
    org_n = 0;
    channels: list = [];
    for item in [root -->] {
        if isinstance(item, Testimony) {
            testimony_n += 1;
        } elif isinstance(item, Incident) {
            signal_n += 1;
        } elif isinstance(item, PipelineOrg) {
            org_n += 1;
        } elif isinstance(item, PipelineChannel) {
            channels.append({
                "recipient": item.recipient,
                "method": item.method,
                "format_note": item.format_note,
                "languages": item.languages,
                "source_url": item.source_url,
                "deadline_kind": item.deadline_kind,
                "deadline_date": item.deadline_date,
                "deadline_source": item.deadline_source,
            });
        }
    }
    loaded = (testimony_n + signal_n + org_n + len(channels)) > 0;
    return {
        "loaded": loaded,
        "source": "out/fixture.json",
        "testimony_n": testimony_n,
        "signal_n": signal_n,
        "org_n": org_n,
        "channel_n": len(channels),
        "channels": channels,
    };
}


def testimony_for(issue: any) -> list {
    out: list = [];
    for t in [issue ->:has_testimony:->] {
        if isinstance(t, Testimony) {
            out.append({
                "speaker": t.speaker,
                "claim": t.claim,
                "affiliation": t.affiliation,
                "language": t.language,
                "kind": t.kind,
                "source_url": t.source_url,
            });
        }
    }
    return out;
}


"""Fixture order is already largest-thread-first per case; no resort."""
def signals_for(issue: any) -> list {
    out: list = [];
    for sig in [issue ->:has_signal:->] {
        if isinstance(sig, Incident) {
            out.append({
                "summary": sig.summary,
                "count": sig.count,
                "kind": sig.kind,
                "source_url": sig.source_url,
            });
        }
    }
    return out;
}


def outreach_for(issue: any) -> list {
    out: list = [];
    for org in [issue ->:has_outreach_org:->] {
        if isinstance(org, PipelineOrg) {
            out.append({
                "name": org.name,
                "initials": org.initials,
                "community": org.community,
                "language": org.language,
                "contact": org.contact,
                "inside_process": org.inside_process,
                "notes": org.notes,
            });
        }
    }
    return out;
}


def record_count(issue: any) -> int {
    return len([issue ->:has_testimony:->]) + len([issue ->:has_signal:->]);
}
