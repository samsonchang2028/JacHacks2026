# ============================================================
# schemas.py — JSON Schemas mirroring schemas/schema.jac.
# This is the P1 side of the frozen contract. If schema.jac
# changes, this file changes with it — never the other way.
# ============================================================

# Kept identical to `CATEGORIES` in schemas/schema.jac. This is the
# join key P2's PrecedentMatcher uses; do not add values here without
# adding them there too.
CATEGORIES = [
    "renovation",
    "road_closure",
    "zoning",
    "development",
    "service_cut",
]

COMMENT_METHODS = ["email", "web_form", "in_person", "mail"]
DEADLINE_KINDS = ["comment", "appeal", "signature", "hearing"]
GEOZONE_KINDS = ["district", "neighborhood", "citywide"]
INCIDENT_KINDS = ["311", "complaint_log"]
TESTIMONY_KINDS = ["testimony", "argument", "evidence", "counterargument"]

PROJECT_SCHEMA = {
    "type": "object",
    "properties": {
        "name": {"type": "string", "minLength": 1},
        "category": {"type": "string", "enum": CATEGORIES},
        "location": {"type": "string", "minLength": 1},
        "description": {"type": "string"},
        "timeline": {"type": "string"},
        "source_url": {"type": "string"},
        "fetched_at": {"type": "string"},
        "geo_zones": {"type": "array", "items": {"type": "string"}},
        "decision_bodies": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["name", "category", "location"],
    "additionalProperties": False,
}

GEOZONE_SCHEMA = {
    "type": "object",
    "properties": {
        "name": {"type": "string", "minLength": 1},
        "kind": {"type": "string", "enum": GEOZONE_KINDS},
        "population_est": {"type": "integer", "minimum": 0},
        "notes": {"type": "string"},
    },
    "required": ["name", "kind"],
    "additionalProperties": False,
}

DECISION_BODY_SCHEMA = {
    "type": "object",
    "properties": {
        "name": {"type": "string", "minLength": 1},
        "kind": {"type": "string"},
        "jurisdiction": {"type": "string"},
        "accountable_to": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["name", "kind", "jurisdiction"],
    "additionalProperties": False,
}

DEADLINE_SCHEMA = {
    "type": "object",
    "properties": {
        "kind": {"type": "string", "enum": DEADLINE_KINDS},
        "date": {"type": "string", "minLength": 1},  # "unknown" is valid; empty is not
        "threshold": {"type": "string"},
        "source_url": {"type": "string", "minLength": 1},
    },
    "required": ["kind", "date", "source_url"],
    "additionalProperties": False,
}

COMMENT_CHANNEL_SCHEMA = {
    "type": "object",
    "properties": {
        "recipient": {"type": "string", "minLength": 1},
        "method": {"type": "string", "enum": COMMENT_METHODS},
        "format_note": {"type": "string"},
        "languages": {"type": "string"},
        "source_url": {"type": "string", "minLength": 1},
        "deadlines": {"type": "array", "items": DEADLINE_SCHEMA},
    },
    "required": ["recipient", "method", "source_url"],
    "additionalProperties": False,
}

ORGANIZATION_SCHEMA = {
    "type": "object",
    "properties": {
        "name": {"type": "string", "minLength": 1},
        "community": {"type": "string"},
        "language": {"type": "string"},
        "contact": {"type": "string"},
        "inside_process": {"type": "boolean"},
        "serves": {"type": "array", "items": {"type": "string"}},
        "notes": {"type": "string"},
    },
    "required": ["name", "inside_process"],
    "additionalProperties": False,
}

TESTIMONY_SCHEMA = {
    "type": "object",
    "properties": {
        "speaker": {"type": "string", "minLength": 1},
        "affiliation": {"type": "string"},
        "claim": {"type": "string", "minLength": 1},
        "language": {"type": "string"},
        "kind": {"type": "string", "enum": TESTIMONY_KINDS},
        # Matches schema.jac's `has source_url: str = "";` — curated quotes
        # (not yet tied to a fetched article) may be empty. Task 6's fetched
        # testimony must fill this in; only CommentChannel/Deadline are
        # non-negotiable per the no-fabrication rule.
        "source_url": {"type": "string"},
    },
    "required": ["speaker", "claim", "kind", "source_url"],
    "additionalProperties": False,
}

INCIDENT_SCHEMA = {
    "type": "object",
    "properties": {
        "kind": {"type": "string", "enum": INCIDENT_KINDS},
        "summary": {"type": "string", "minLength": 1},
        "count": {"type": "integer", "minimum": 0},
        "source_url": {"type": "string"},
    },
    "required": ["kind", "summary"],
    "additionalProperties": False,
}

FIXTURE_SCHEMA = {
    "type": "object",
    "properties": {
        "projects": {"type": "array", "items": PROJECT_SCHEMA},
        "geo_zones": {"type": "array", "items": GEOZONE_SCHEMA},
        "decision_bodies": {"type": "array", "items": DECISION_BODY_SCHEMA},
        "comment_channels": {"type": "array", "items": COMMENT_CHANNEL_SCHEMA},
        "organizations": {"type": "array", "items": ORGANIZATION_SCHEMA},
        "testimony": {"type": "array", "items": TESTIMONY_SCHEMA},
        "incidents": {"type": "array", "items": INCIDENT_SCHEMA},
    },
    "required": [
        "projects",
        "geo_zones",
        "decision_bodies",
        "comment_channels",
        "organizations",
        "testimony",
        "incidents",
    ],
    "additionalProperties": False,
}
