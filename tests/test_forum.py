# ============================================================
# test_forum.py — LLM summarizer with a fake runner; no network,
# no claude CLI calls.
# ============================================================
import pytest

from ingest.extract.forum import (
    ForumSummaryError,
    build_incidents,
    summarize_thread,
)

POST = {
    "title": "Bridge is coming down",
    "body": "Demolition starts Monday.",
    "scope": "sanfrancisco",
    "permalink": "https://www.reddit.com/r/sanfrancisco/comments/abc123/bridge/",
    "num_comments": 42,
    "score": 100,
}


def runner_relevant(prompt):
    assert "Bridge is coming down" in prompt
    return '{"summary": "Residents discuss the demolition.", "relevant": true}'


def runner_offtopic(prompt):
    return '{"summary": "A photo of 1851.", "relevant": false}'


def runner_garbage(prompt):
    return "Sorry, I cannot help with that."


def test_summarize_thread_parses_json():
    out = summarize_thread(POST, ["comment one"], "the bridge case",
                           runner=runner_relevant)
    assert out == {"summary": "Residents discuss the demolition.", "relevant": True}


def test_summarize_thread_fails_loud_on_garbage():
    with pytest.raises(ForumSummaryError):
        summarize_thread(POST, [], "the bridge case", runner=runner_garbage)


def _threads_for(post):
    return {"abc123": {"post": post, "comments": ["c1", "c2"]}}


def test_build_incidents_keeps_relevant_threads():
    case_cfg = {"case": "x", "query": "q", "description": "the bridge case"}
    incidents = build_incidents(case_cfg, [POST], _threads_for(POST),
                                runner=runner_relevant)
    assert len(incidents) == 1
    inc = incidents[0]
    assert inc["kind"] == "forum"
    assert inc["count"] == 42
    assert inc["source_url"] == POST["permalink"]
    assert "Residents discuss the demolition." in inc["summary"]
    assert inc["summary"].startswith("r/sanfrancisco thread, 42 comments:")


def test_build_incidents_drops_offtopic_threads():
    case_cfg = {"case": "x", "query": "q", "description": "the bridge case"}
    incidents = build_incidents(case_cfg, [POST], _threads_for(POST),
                                runner=runner_offtopic)
    assert incidents == []
