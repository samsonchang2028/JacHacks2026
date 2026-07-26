import json

from ingest.emit import to_jac
from ingest.emit.to_jac import emit

SAMPLE_FIXTURE = {
    "projects": [
        {
            "name": "Test Project",
            "category": "renovation",
            "location": "Somewhere",
            "geo_zones": ["Test Zone"],
            "decision_bodies": ["Test Body"],
        }
    ],
    "geo_zones": [{"name": "Test Zone", "kind": "neighborhood"}],
    "decision_bodies": [
        {"name": "Test Body", "kind": "commission", "jurisdiction": "citywide",
         "accountable_to": ["Test Zone"]}
    ],
    "comment_channels": [
        {"recipient": "Test Recipient", "method": "email", "source_url": "https://example.com",
         "deadlines": [{"kind": "comment", "date": "unknown", "source_url": "https://example.com"}]}
    ],
    "organizations": [
        {"name": "Test Org", "inside_process": False, "serves": ["Test Zone"]}
    ],
    "testimony": [
        {"speaker": "A role", "claim": "A claim", "kind": "testimony"}
    ],
    "incidents": [],
}


def test_emit_produces_valid_looking_statements():
    output = emit(SAMPLE_FIXTURE)
    assert 'GeoZone(name="Test Zone"' in output
    assert 'DecisionBody(name="Test Body"' in output
    assert "accountable_to :+>" in output
    assert 'Project(' in output
    assert 'category="renovation"' in output
    assert 'CommentChannel(recipient="Test Recipient"' in output
    assert 'Deadline(kind="comment", date="unknown"' in output
    assert 'Organization(name="Test Org"' in output
    assert 'Testimony(speaker="A role"' in output


def test_emit_handles_duplicate_names_with_distinct_vars():
    fixture = dict(SAMPLE_FIXTURE)
    fixture["organizations"] = [
        {"name": "Test Org", "inside_process": False, "serves": []},
        {"name": "Test Org Two", "inside_process": False, "serves": []},
    ]
    output = emit(fixture)
    # both should get valid, distinct identifiers
    assert output.count("Organization(name=") == 2


def test_main_writes_fixture_jac_by_default(tmp_path, monkeypatch):
    fixture_path = tmp_path / "fixture.json"
    out_path = tmp_path / "fixture.jac"
    fixture_path.write_text(json.dumps(SAMPLE_FIXTURE))
    monkeypatch.setattr(to_jac, "FIXTURE_PATH", fixture_path)
    monkeypatch.setattr(to_jac, "OUT_JAC_PATH", out_path)

    to_jac.main()

    assert out_path.exists()
    written = out_path.read_text()
    assert 'Project(' in written
    assert written == emit(SAMPLE_FIXTURE) + "\n"
