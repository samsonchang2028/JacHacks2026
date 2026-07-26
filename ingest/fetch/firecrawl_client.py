# ============================================================
# firecrawl_client.py — thin wrapper around the Firecrawl v2 API.
#
# Cache-first, budget-guarded. Every fetch writes to cache/ keyed
# by a hash of (endpoint, params); every read checks cache first.
# The demo must run with the network unplugged, so the cache is
# not an optimization here — it's the offline fallback.
# ============================================================
from __future__ import annotations

import hashlib
import json
import os
import pathlib
import time
from typing import Any

import requests
import yaml

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
CACHE_DIR = REPO_ROOT / "cache"
SOURCES_CONFIG = REPO_ROOT / "ingest" / "config" / "sources.yaml"

BASE_URL = "https://api.firecrawl.dev/v2"

# Rough cost model from the spec: ~1 credit/scrape or /map, JSON extraction
# adds ~4 on top. These are estimates for the budget guard, not what
# Firecrawl actually bills — the guard exists to fail loudly before hour
# eight, not to be penny-accurate.
ESTIMATED_COST = {
    "map": 1,
    "scrape": 1,
    "scrape_json": 5,
    "extract": 5,   # per URL, multiplied by len(urls) by the caller
    "crawl": 1,     # per page crawled, added as pages complete
    "search": 1,    # per result page requested, roughly
}


class BudgetExceeded(RuntimeError):
    pass


class FirecrawlError(RuntimeError):
    pass


def _load_credit_budget() -> int:
    if SOURCES_CONFIG.exists():
        with open(SOURCES_CONFIG) as f:
            cfg = yaml.safe_load(f)
        return int(cfg.get("credit_budget", 300))
    return 300


def _cache_key(endpoint: str, payload: dict) -> str:
    blob = json.dumps({"endpoint": endpoint, "payload": payload}, sort_keys=True)
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


class FirecrawlClient:
    def __init__(
        self,
        api_key: str | None = None,
        cache_dir: pathlib.Path = CACHE_DIR,
        credit_budget: int | None = None,
        session: requests.Session | None = None,
    ):
        self.api_key = api_key or os.environ.get("FIRECRAWL_API_KEY")
        if not self.api_key:
            raise FirecrawlError(
                "FIRECRAWL_API_KEY not set. Never send unauthenticated "
                "requests; export it or put it in .env."
            )
        self.cache_dir = cache_dir
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.credit_ledger_path = self.cache_dir / "_credit_ledger.json"
        self.credit_budget = (
            credit_budget if credit_budget is not None else _load_credit_budget()
        )
        self.session = session or requests.Session()
        self._spent = self._load_ledger()

    # ---- credit ledger, persisted across runs (scoped to this cache_dir) --
    def _load_ledger(self) -> int:
        if self.credit_ledger_path.exists():
            try:
                return json.loads(self.credit_ledger_path.read_text()).get("spent", 0)
            except (json.JSONDecodeError, OSError):
                return 0
        return 0

    def _save_ledger(self) -> None:
        self.credit_ledger_path.write_text(json.dumps({"spent": self._spent}))

    def _charge(self, amount: int) -> None:
        if self._spent + amount > self.credit_budget:
            raise BudgetExceeded(
                f"Firecrawl credit budget exceeded: {self._spent} spent, "
                f"{amount} requested, budget is {self.credit_budget}. "
                "Stop and re-scope rather than burning through it silently."
            )
        self._spent += amount
        self._save_ledger()

    @property
    def credits_spent(self) -> int:
        return self._spent

    # ---- cache ------------------------------------------------------------
    def _cache_path(self, key: str) -> pathlib.Path:
        return self.cache_dir / f"{key}.json"

    def _cache_get(self, key: str) -> dict | None:
        path = self._cache_path(key)
        if path.exists():
            return json.loads(path.read_text())
        return None

    def _cache_put(self, key: str, value: dict) -> None:
        self._cache_path(key).write_text(json.dumps(value, indent=2))

    # ---- transport ----------------------------------------------------
    def _post(self, path: str, payload: dict, *, cost: int, cache_key: str) -> dict:
        cached = self._cache_get(cache_key)
        if cached is not None:
            return cached

        self._charge(cost)
        resp = self.session.post(
            f"{BASE_URL}{path}",
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
            json=payload,
            timeout=60,
        )
        if resp.status_code == 429:
            raise FirecrawlError(f"Rate limited on {path}: {resp.text}")
        if not resp.ok:
            raise FirecrawlError(f"Firecrawl {path} failed [{resp.status_code}]: {resp.text}")

        data = resp.json()
        self._cache_put(cache_key, data)
        return data

    def _get(self, path: str, *, cache_key: str) -> dict:
        cached = self._cache_get(cache_key)
        if cached is not None:
            return cached

        resp = self.session.get(
            f"{BASE_URL}{path}",
            headers={"Authorization": f"Bearer {self.api_key}"},
            timeout=60,
        )
        if not resp.ok:
            raise FirecrawlError(f"Firecrawl GET {path} failed [{resp.status_code}]: {resp.text}")
        data = resp.json()
        return data

    # ---- public API -----------------------------------------------------
    def search(self, query: str, limit: int = 5, sources: list[str] | None = None) -> list[dict]:
        """POST /v2/search — web/news search with content extraction. Used
        to find an org's own site (Task 5) and news coverage of a case
        (Task 6) without guessing a URL."""
        payload = {"query": query, "limit": limit}
        if sources:
            payload["sources"] = sources
        key = _cache_key("search", payload)
        cost = ESTIMATED_COST["search"] * limit
        data = self._post("/search", payload, cost=cost, cache_key=key)
        results = data.get("data") or data.get("web") or []
        if isinstance(results, dict):
            results = results.get("web", [])
        return results

    def map_site(self, url: str, search: str | None = None) -> list[str]:
        """POST /v2/map — candidate URLs on a site. Always call this before
        crawling or scraping anything; never crawl a .gov site broadly."""
        payload = {"url": url}
        if search:
            payload["search"] = search
        key = _cache_key("map", payload)
        data = self._post("/map", payload, cost=ESTIMATED_COST["map"], cache_key=key)
        links = data.get("links") or data.get("data", {}).get("links", [])
        return [item["url"] if isinstance(item, dict) else item for item in links]

    def scrape(self, url: str, formats: list[str] | None = None) -> dict:
        """POST /v2/scrape — single-page scrape."""
        payload = {"url": url, "formats": formats or ["markdown"]}
        key = _cache_key("scrape", payload)
        return self._post("/scrape", payload, cost=ESTIMATED_COST["scrape"], cache_key=key)

    def scrape_json(self, url: str, schema: dict, prompt: str | None = None) -> dict:
        """POST /v2/scrape with a json format — structured single-page pull."""
        json_format: dict[str, Any] = {"type": "json", "schema": schema}
        if prompt:
            json_format["prompt"] = prompt
        payload = {"url": url, "formats": [json_format]}
        key = _cache_key("scrape_json", payload)
        return self._post(
            "/scrape", payload, cost=ESTIMATED_COST["scrape_json"], cache_key=key
        )

    def extract(self, urls: list[str], prompt: str, schema: dict) -> dict:
        """POST /v2/extract — multi-page structured pull."""
        payload = {"urls": urls, "prompt": prompt, "schema": schema}
        key = _cache_key("extract", payload)
        cost = ESTIMATED_COST["extract"] * max(len(urls), 1)
        return self._post("/extract", payload, cost=cost, cache_key=key)

    def crawl(
        self,
        url: str,
        include_paths: list[str] | None = None,
        limit: int = 10,
        poll_interval: float = 2.0,
        max_wait: float = 120.0,
    ) -> dict:
        """POST /v2/crawl (async) then poll GET /v2/crawl/{id} until done.
        Cached on the *final* result, keyed by the crawl request itself, so a
        repeat call doesn't restart a job or re-charge credits."""
        payload = {"url": url, "limit": limit}
        if include_paths:
            payload["includePaths"] = include_paths
        key = _cache_key("crawl", payload)

        cached = self._cache_get(key)
        if cached is not None:
            return cached

        self._charge(ESTIMATED_COST["crawl"] * limit)
        resp = self.session.post(
            f"{BASE_URL}/crawl",
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
            json=payload,
            timeout=60,
        )
        if not resp.ok:
            raise FirecrawlError(f"Firecrawl crawl failed [{resp.status_code}]: {resp.text}")
        job_id = resp.json()["id"]

        waited = 0.0
        while waited < max_wait:
            status = self._get(f"/crawl/{job_id}", cache_key=f"crawl_status_{job_id}_{waited}")
            if status.get("status") == "completed":
                self._cache_put(key, status)
                return status
            time.sleep(poll_interval)
            waited += poll_interval

        raise FirecrawlError(f"Crawl {job_id} did not complete within {max_wait}s")
