# ============================================================
# test_reddit.py — fakes the Apify client (same spirit as the
# Firecrawl fake transport in test_firecrawl_client.py). Zero
# network; asserts the two things that actually matter: authors
# are scrubbed before anything is cached, and a cache hit spends
# zero actor calls.
# ============================================================
import pytest

import ingest.fetch.reddit as reddit_mod
from ingest.fetch.reddit import AUTHOR_ROLE, RedditFetchError, search_reddit

RAW_ITEMS = [
    {
        "id": "t3_abc123",
        "parsedId": "abc123",
        "url": "https://www.reddit.com/r/sanfrancisco/comments/abc123/portsmouth/",
        "username": "u/real_person_name",   # must never survive scrubbing
        "title": "Portsmouth Square bridge demolition",
        "body": "The pedestrian bridge is coming down and nobody asked us.",
        "communityName": "r/sanfrancisco",
        "createdAt": "2026-06-01T12:00:00.000Z",
        "upVotes": 321,
        "numberOfComments": 87,
    },
    {
        # no id and no content -> dropped
        "username": "u/other_person",
        "title": "",
        "body": "",
    },
]


class FakeActor:
    def __init__(self, tracker):
        self.tracker = tracker

    def call(self, run_input=None):
        self.tracker["calls"] += 1
        self.tracker["last_input"] = run_input
        return {"defaultDatasetId": "ds1"}


class FakeDataset:
    def iterate_items(self):
        yield from RAW_ITEMS


class FakeApifyClient:
    def __init__(self):
        self.tracker = {"calls": 0, "last_input": None}

    def actor(self, actor_id):
        return FakeActor(self.tracker)

    def dataset(self, dataset_id):
        return FakeDataset()


@pytest.fixture(autouse=True)
def isolated_cache(tmp_path, monkeypatch):
    import ingest.fetch._cache as cache_mod

    monkeypatch.setattr(cache_mod, "CACHE_DIR", tmp_path)
    monkeypatch.setattr(reddit_mod, "cache_get",
                        lambda key: cache_mod.cache_get(key, cache_dir=tmp_path))
    monkeypatch.setattr(reddit_mod, "cache_put",
                        lambda key, value: cache_mod.cache_put(key, value, cache_dir=tmp_path))


def test_usernames_are_scrubbed_to_role():
    client = FakeApifyClient()
    records = search_reddit("Portsmouth Square", case="portsmouth-square", client=client)
    assert len(records) == 1
    rec = records[0]
    assert rec["author_role"] == AUTHOR_ROLE
    assert "username" not in rec
    assert "real_person_name" not in str(rec)


def test_output_schema_is_stable():
    client = FakeApifyClient()
    rec = search_reddit("Portsmouth Square", case="portsmouth-square", client=client)[0]
    assert set(rec) == {"case", "source", "scope", "query", "post_id", "title",
                        "body", "author_role", "permalink", "created_at",
                        "score", "num_comments"}
    assert rec["case"] == "portsmouth-square"
    assert rec["source"] == "reddit"
    assert rec["score"] == 321
    assert rec["num_comments"] == 87


def test_cache_hit_spends_no_actor_calls():
    client = FakeApifyClient()
    search_reddit("Great Highway", case="prop-k-great-highway", client=client)
    search_reddit("Great Highway", case="prop-k-great-highway", client=client)
    assert client.tracker["calls"] == 1


def test_search_is_per_case_keyword_not_firehose():
    client = FakeApifyClient()
    search_reddit("Prop K Great Highway", case="prop-k-great-highway", client=client)
    run_input = client.tracker["last_input"]
    assert run_input["searches"] == ["Prop K Great Highway"]
    assert run_input["searchPosts"] is True
    assert run_input["searchComments"] is False


def test_summarize_incident_aggregates_by_discussion_volume():
    from ingest.fetch.reddit import summarize_incident

    records = [
        {"query": "q", "scope": "CityPorn", "title": "Pretty photo, huge karma",
         "permalink": "https://reddit.com/1", "score": 999, "num_comments": 2},
        {"query": "q", "scope": "sanfrancisco", "title": "Actual controversy thread",
         "permalink": "https://reddit.com/2", "score": 10, "num_comments": 50},
    ]
    inc = summarize_incident(records)
    assert inc["kind"] == "forum"
    assert inc["count"] == 2
    # ranked by comments (discussion volume), not upvotes
    assert inc["source_url"] == "https://reddit.com/2"
    assert "Actual controversy thread" in inc["summary"]
    assert summarize_incident([]) is None


def test_missing_token_fails_loud(monkeypatch):
    monkeypatch.delenv("APIFY_API_TOKEN", raising=False)
    monkeypatch.delenv("APIFY_API_KEY", raising=False)
    with pytest.raises(RedditFetchError):
        search_reddit("anything", case="x")
