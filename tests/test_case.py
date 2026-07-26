# ============================================================
# test_case.py — case manifests + LLM bootstrap. No network,
# no claude CLI: the bootstrap is exercised through a fake
# runner and the offline skeleton path.
# ============================================================
import pytest

from ingest.bootstrap_case import _skeleton, draft_manifest
from ingest.case import CaseError, list_cases, load_case, slugify, validate_case
from ingest.extract.forum import load_cases as forum_cases
from ingest.extract.schemas import CATEGORIES


def test_gold_manifests_validate_and_load():
    cases = list_cases()
    slugs = [c["slug"] for c in cases]
    assert "portsmouth-square" in slugs
    assert "prop-k-great-highway" in slugs
    for case in cases:
        assert case["category"] in CATEGORIES
        assert case["verified"] is True
        assert case["generated_by"] == "curated"


def test_load_case_roundtrip():
    case = load_case("portsmouth-square")
    assert case["title"] == "Portsmouth Square Improvement Project"
    assert case["geography"]["impact_bbox"]["min_lat"] == pytest.approx(37.790)


def test_load_unknown_case_fails_loud():
    with pytest.raises(CaseError):
        load_case("no-such-case")


def test_slugify():
    assert slugify("Balboa Reservoir housing development") == \
        "balboa-reservoir-housing-development"
    with pytest.raises(CaseError):
        slugify("!!!")


def test_forum_cases_come_from_manifests():
    cases = forum_cases()
    by_slug = {c["case"]: c for c in cases}
    # queries must match what the manifests say (and therefore what the
    # existing reddit cache is keyed on)
    assert by_slug["portsmouth-square"]["query"] == "Portsmouth Square San Francisco"
    assert by_slug["prop-k-great-highway"]["query"] == \
        "Great Highway Prop K San Francisco"
    for c in cases:
        assert c["description"]


def test_skeleton_is_schema_valid():
    manifest = _skeleton("Some New Development", "some-new-development")
    validate_case(manifest)
    assert manifest["verified"] is False
    assert manifest["generated_by"] == "llm-bootstrap"


def test_draft_manifest_with_fake_llm():
    def fake_runner(prompt):
        assert "Balboa Reservoir" in prompt
        return '''{
            "category": "development",
            "description": "A housing development on the Balboa Reservoir site; contested over density and parking.",
            "search_terms": {"news": "Balboa Reservoir housing opposition",
                             "forum": "Balboa Reservoir San Francisco"},
            "geography": {"impact_zones": ["Sunnyside", "Westwood Park"],
                          "decision_zone": "SF Planning Commission"},
            "news_domains": ["missionlocal.org"],
            "procedure_targets": ["sfplanning.org"],
            "org_candidates": ["Westwood Park Association"]
        }'''

    manifest = draft_manifest("Balboa Reservoir housing development", [],
                              runner=fake_runner)
    assert manifest["slug"] == "balboa-reservoir-housing-development"
    assert manifest["category"] == "development"
    assert manifest["verified"] is False
    assert manifest["generated_by"] == "llm-bootstrap"


def test_draft_manifest_rejects_bad_category():
    def fake_runner(prompt):
        return '''{"category": "not-a-category", "description": "x",
                   "search_terms": {"news": "n", "forum": "f"},
                   "geography": {"impact_zones": ["z"], "decision_zone": "d"}}'''

    with pytest.raises(CaseError):
        draft_manifest("Bad Case", [], runner=fake_runner)


def test_draft_manifest_falls_back_to_skeleton_when_llm_missing():
    def broken_runner(prompt):
        raise CaseError("claude CLI failed: not found")

    manifest = draft_manifest("Some Subject", [], runner=broken_runner)
    validate_case(manifest)
    assert "DRAFT SKELETON" in manifest["description"]
