# ============================================================
# test_contract.py — validates out/fixture.json against the
# frozen contract (schemas/schema.jac, mirrored in
# ingest/extract/schemas.py). This is the test P2 and P3 trust
# to build against; keep it strict.
# ============================================================
import json
import pathlib

import jsonschema
import pytest

from ingest.extract.schemas import CATEGORIES, FIXTURE_SCHEMA

REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
FIXTURE_PATH = REPO_ROOT / "out" / "fixture.json"


@pytest.fixture(scope="module")
def fixture():
    with open(FIXTURE_PATH) as f:
        return json.load(f)


def test_fixture_exists():
    assert FIXTURE_PATH.exists(), "out/fixture.json must be committed"


def test_fixture_matches_schema(fixture):
    jsonschema.validate(instance=fixture, schema=FIXTURE_SCHEMA)


def test_every_project_category_is_valid(fixture):
    for proj in fixture["projects"]:
        assert proj["category"] in CATEGORIES, (
            f"{proj['name']!r} has category {proj['category']!r} "
            f"not in CATEGORIES {CATEGORIES}"
        )


def test_comment_channels_have_source_urls(fixture):
    for ch in fixture["comment_channels"]:
        assert ch.get("source_url"), (
            f"CommentChannel for {ch.get('recipient')!r} is missing a "
            "source_url — no comment channel may be emitted without one"
        )
        for dl in ch.get("deadlines", []):
            assert dl.get("source_url"), (
                f"Deadline ({dl.get('kind')}) under {ch.get('recipient')!r} "
                "is missing a source_url"
            )


def test_no_fabricated_deadline_dates(fixture):
    """A deadline date is never blank: it's either the literal 'unknown'
    (nothing found — the honest gap) or real text pulled from the source
    page, ideally normalized to ISO. Extraction normalizes to ISO where it
    can (see extract/procedure.normalize_date) but keeps the original text
    if normalization fails, rather than fabricating a shape for it."""
    for ch in fixture["comment_channels"]:
        for dl in ch.get("deadlines", []):
            assert dl["date"], "Deadline date must not be blank"


def test_orgs_resolved_to_contact_or_explicit_blank(fixture):
    for org in fixture["organizations"]:
        if not org.get("contact"):
            assert "notes" in org and org["notes"], (
                f"Org {org['name']!r} has no contact and no notes explaining "
                "where P1 looked — see Task 5 acceptance criteria"
            )
