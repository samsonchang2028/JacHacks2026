# ============================================================
# case.py — case manifests: the generalization seam.
#
# A manifest (ingest/config/cases/<slug>.yaml) is how Quorum
# points at a NEW civic case without code changes. It is split
# into three trust tiers, and the split is the whole point:
#
#   1. Research knobs (an LLM may propose these): category,
#      search_terms, geography, news_domains, procedure_targets,
#      org_candidates (names only).
#   2. Fetched facts (NEVER in the manifest): comment channels,
#      deadlines, contacts, testimony — those come from the
#      deterministic fetchers, always with a source_url.
#   3. Human judgment (NEVER the model): inside_process, set by
#      hand in config/orgs.yaml.
#
# So a manifest says where to look; it never asserts a
# procedural fact. LLM-drafted manifests are written as
# <slug>.draft.yaml with verified: false and are excluded from
# list_cases() until a human reviews and renames them.
# ============================================================
from __future__ import annotations

import pathlib
import re

import jsonschema
import yaml

from ingest.extract.schemas import CATEGORIES

CASES_DIR = pathlib.Path(__file__).resolve().parent / "config" / "cases"

BBOX_SCHEMA = {
    "type": "object",
    "properties": {
        "min_lat": {"type": "number"},
        "max_lat": {"type": "number"},
        "min_lon": {"type": "number"},
        "max_lon": {"type": "number"},
    },
    "required": ["min_lat", "max_lat", "min_lon", "max_lon"],
    "additionalProperties": False,
}

CASE_SCHEMA = {
    "type": "object",
    "properties": {
        "slug": {"type": "string", "pattern": r"^[a-z0-9][a-z0-9-]*$"},
        "title": {"type": "string", "minLength": 1},
        "category": {"type": "string", "enum": CATEGORIES},
        "description": {"type": "string", "minLength": 1},
        "search_terms": {
            "type": "object",
            "properties": {
                "news": {"type": "string", "minLength": 1},
                "forum": {"type": "string", "minLength": 1},
            },
            "required": ["news", "forum"],
            "additionalProperties": False,
        },
        "geography": {
            "type": "object",
            "properties": {
                "impact_zones": {
                    "type": "array",
                    "items": {"type": "string", "minLength": 1},
                    "minItems": 1,
                },
                "decision_zone": {"type": "string", "minLength": 1},
                "impact_bbox": BBOX_SCHEMA,  # optional — 311 needs it, nothing else does
            },
            "required": ["impact_zones", "decision_zone"],
            "additionalProperties": False,
        },
        "news_domains": {"type": "array", "items": {"type": "string"}},
        "procedure_targets": {"type": "array", "items": {"type": "string"}},
        "org_candidates": {"type": "array", "items": {"type": "string"}},
        "generated_by": {"type": "string", "enum": ["curated", "llm-bootstrap"]},
        "verified": {"type": "boolean"},
    },
    "required": ["slug", "title", "category", "description", "search_terms",
                 "geography", "generated_by", "verified"],
    "additionalProperties": False,
}


class CaseError(RuntimeError):
    pass


def slugify(subject: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", subject.lower()).strip("-")
    if not slug:
        raise CaseError(f"Cannot derive a slug from {subject!r}")
    return slug


def validate_case(manifest: dict) -> dict:
    try:
        jsonschema.validate(instance=manifest, schema=CASE_SCHEMA)
    except jsonschema.ValidationError as e:
        raise CaseError(f"Invalid case manifest: {e.message}") from e
    return manifest


def load_case(slug: str) -> dict:
    """Load and validate one manifest. Accepts a draft only when asked for
    explicitly by its full '<slug>.draft' name — the pipeline should never
    pick up unreviewed LLM output by accident."""
    path = CASES_DIR / f"{slug}.yaml"
    if not path.exists():
        raise CaseError(
            f"No case manifest {path.name!r} in {CASES_DIR}. "
            f"Known cases: {[c['slug'] for c in list_cases()]}"
        )
    with open(path) as f:
        return validate_case(yaml.safe_load(f))


def list_cases(include_drafts: bool = False) -> list[dict]:
    """All valid manifests, drafts excluded unless asked. Sorted by slug so
    pipeline runs are deterministic."""
    cases = []
    for path in sorted(CASES_DIR.glob("*.yaml")):
        if path.name.endswith(".draft.yaml") and not include_drafts:
            continue
        with open(path) as f:
            cases.append(validate_case(yaml.safe_load(f)))
    return cases
