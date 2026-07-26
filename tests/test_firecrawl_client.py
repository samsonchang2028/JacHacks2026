# ============================================================
# test_firecrawl_client.py — verifies the cache-first contract
# without spending real Firecrawl credits: a fake transport
# stands in for the network so we can count calls exactly.
# ============================================================
import pathlib
import shutil

import pytest

from ingest.fetch.firecrawl_client import BudgetExceeded, FirecrawlClient


class FakeResponse:
    def __init__(self, json_data, status_code=200):
        self._json = json_data
        self.status_code = status_code
        self.ok = status_code < 400
        self.text = str(json_data)

    def json(self):
        return self._json


class FakeSession:
    def __init__(self, json_data):
        self.json_data = json_data
        self.post_calls = 0
        self.get_calls = 0

    def post(self, url, headers=None, json=None, timeout=None):
        self.post_calls += 1
        return FakeResponse(self.json_data)

    def get(self, url, headers=None, timeout=None):
        self.get_calls += 1
        return FakeResponse(self.json_data)


@pytest.fixture
def tmp_cache_dir(tmp_path):
    d = tmp_path / "cache"
    d.mkdir()
    yield d
    shutil.rmtree(d, ignore_errors=True)


def test_identical_calls_hit_cache_once(tmp_cache_dir, monkeypatch):
    monkeypatch.setenv("FIRECRAWL_API_KEY", "fc-test-key")
    fake = FakeSession({"links": [{"url": "https://sfrecpark.org/agendas"}]})
    client = FirecrawlClient(cache_dir=tmp_cache_dir, credit_budget=300, session=fake)

    first = client.map_site("https://sfrecpark.org")
    second = client.map_site("https://sfrecpark.org")

    assert first == second == ["https://sfrecpark.org/agendas"]
    assert fake.post_calls == 1, "second identical call should be served from cache"


def test_different_urls_are_not_conflated(tmp_cache_dir, monkeypatch):
    monkeypatch.setenv("FIRECRAWL_API_KEY", "fc-test-key")
    fake = FakeSession({"links": []})
    client = FirecrawlClient(cache_dir=tmp_cache_dir, credit_budget=300, session=fake)

    client.map_site("https://sfrecpark.org")
    client.map_site("https://sfplanning.org")

    assert fake.post_calls == 2


def test_budget_guard_fails_loudly(tmp_cache_dir, monkeypatch):
    monkeypatch.setenv("FIRECRAWL_API_KEY", "fc-test-key")
    fake = FakeSession({"data": {"markdown": "hi"}})
    client = FirecrawlClient(cache_dir=tmp_cache_dir, credit_budget=2, session=fake)

    client.scrape("https://sfrecpark.org/one")
    with pytest.raises(BudgetExceeded):
        client.scrape_json("https://sfrecpark.org/two", schema={"type": "object"})


def test_missing_api_key_raises(tmp_cache_dir, monkeypatch):
    monkeypatch.delenv("FIRECRAWL_API_KEY", raising=False)
    from ingest.fetch.firecrawl_client import FirecrawlError

    with pytest.raises(FirecrawlError):
        FirecrawlClient(api_key=None, cache_dir=tmp_cache_dir)
