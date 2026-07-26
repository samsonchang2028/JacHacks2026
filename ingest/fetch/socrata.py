# ============================================================
# socrata.py — DataSF / Socrata SODA client.
#
# Cheaper and more reliable than scraping (§3 of p1ingestion.md).
# Dataset IDs are NEVER hardcoded — every ID is resolved against
# the Socrata discovery catalog at runtime, logged, and cached,
# because IDs drift and a stale one fails silently with 0 rows.
#
#   python -m ingest.fetch.socrata --smoke
# ============================================================
from __future__ import annotations

import argparse
import os
import sys

import requests

from ingest.fetch._cache import cache_get, cache_key, cache_put

DOMAIN = "data.sfgov.org"
# The federated catalog needs BOTH `domains` and `search_context` set to the
# target domain, or it ranks matches from every Socrata-hosted city above
# SF's own (verified live: `domains` alone returned an unrelated Berkeley/
# Kansas City/Dallas grab-bag for a query as generic as "311 cases").
CATALOG_URL = "https://api.us.socrata.com/api/catalog/v1"
RESOURCE_BASE = "https://data.sfgov.org/resource"
VIEWS_BASE = "https://data.sfgov.org/api/views"

# Chinatown, SF bounding box (Stockton/Powell to Kearny, Bush to Broadway).
CHINATOWN_BBOX = {
    "min_lat": 37.790,
    "max_lat": 37.798,
    "min_lon": -122.410,
    "max_lon": -122.403,
}

# NOTE on 311-as-Incidents: investigated and rejected (2026-07-26). Both
# bbox queries and full-text $q searches ("Portsmouth Square" -> 994 rows,
# 609 of them Rec & Park requests) return only routine maintenance traffic
# (restrooms, trash, graffiti, recreation equipment). SF's 311 taxonomy has
# no category for opposition to a project — that signal lives in testimony
# and public comment, not 311. fixture.json's `incidents` stays [] on
# purpose; an honest empty list beats maintenance tickets dressed up as
# controversy evidence.

# Topic -> catalog search query. This is a search term, NOT a dataset id.
TOPIC_QUERIES = {
    "311_cases": "311 cases",
    "supervisor_districts": "current supervisor district boundaries",
    "analysis_neighborhoods": "analysis neighborhoods boundaries",
    "election_precinct_results": "election precinct results",
}


def _auth_kwargs() -> dict:
    """Prefer the new Socrata API Key (basic auth); fall back to the legacy
    X-App-Token header; fall back to anonymous (works, just rate-limited)."""
    key_id = os.environ.get("SOCRATA_API_ID")
    key_secret = os.environ.get("SOCRATA_API_KEY")
    app_token = os.environ.get("SOCRATA_APP_TOKEN")
    if key_id and key_secret:
        return {"auth": (key_id, key_secret)}
    if app_token:
        return {"headers": {"X-App-Token": app_token}}
    return {}


def resolve_dataset(topic: str) -> dict:
    """Query the Socrata discovery catalog for `topic`, cache and return the
    top match's {id, name, domain}. Never trust a hardcoded dataset id."""
    if topic not in TOPIC_QUERIES:
        raise ValueError(f"Unknown topic {topic!r}; add it to TOPIC_QUERIES first")

    query = TOPIC_QUERIES[topic]
    key = cache_key("socrata_catalog", {"domain": DOMAIN, "q": query})
    cached = cache_get(key)
    if cached is not None:
        return cached

    resp = requests.get(
        CATALOG_URL,
        params={
            "domains": DOMAIN,
            "search_context": DOMAIN,
            "q": query,
            "only": "datasets",
            "limit": 5,
        },
        timeout=30,
    )
    resp.raise_for_status()
    results = resp.json().get("results", [])
    if not results:
        raise RuntimeError(f"No Socrata dataset found for topic {topic!r} (query={query!r})")

    top = results[0]["resource"]
    resolved = {"id": top["id"], "name": top["name"], "domain": DOMAIN, "topic": topic}
    print(f"[socrata] resolved {topic!r} -> {resolved['id']} ({resolved['name']!r})")
    cache_put(key, resolved)
    return resolved


def get_columns(dataset_id: str) -> list[dict]:
    key = cache_key("socrata_columns", {"dataset_id": dataset_id})
    cached = cache_get(key)
    if cached is not None:
        return cached

    resp = requests.get(f"{VIEWS_BASE}/{dataset_id}.json", timeout=30)
    resp.raise_for_status()
    columns = resp.json().get("columns", [])
    cache_put(key, columns)
    return columns


def _find_point_column(columns: list[dict]) -> str | None:
    for col in columns:
        if col.get("dataTypeName") == "point":
            return col["fieldName"]
    return None


def query(dataset_id: str, where: str | None = None, select: str | None = None,
          limit: int = 1000) -> list[dict]:
    """GET /resource/{dataset_id}.json with SoQL params. Cache-first."""
    params = {"$limit": limit}
    if where:
        params["$where"] = where
    if select:
        params["$select"] = select

    key = cache_key(f"socrata_query_{dataset_id}", params)
    cached = cache_get(key)
    if cached is not None:
        return cached

    resp = requests.get(
        f"{RESOURCE_BASE}/{dataset_id}.json", params=params, timeout=30, **_auth_kwargs()
    )
    resp.raise_for_status()
    rows = resp.json()
    cache_put(key, rows)
    return rows


def query_311_in_bbox(bbox: dict = CHINATOWN_BBOX, limit: int = 1000) -> list[dict]:
    dataset = resolve_dataset("311_cases")
    columns = get_columns(dataset["id"])
    point_col = _find_point_column(columns)
    if point_col:
        where = (
            f"within_box({point_col}, {bbox['max_lat']}, {bbox['min_lon']}, "
            f"{bbox['min_lat']}, {bbox['max_lon']})"
        )
    else:
        # Fall back to separate lat/long columns if no `point` type exists.
        lat_col = next((c["fieldName"] for c in columns if "lat" in c["fieldName"].lower()), None)
        lon_col = next(
            (c["fieldName"] for c in columns if "long" in c["fieldName"].lower()), None
        )
        if not (lat_col and lon_col):
            raise RuntimeError(
                f"Could not find a geo column on dataset {dataset['id']}; "
                f"columns were: {[c['fieldName'] for c in columns]}"
            )
        where = (
            f"{lat_col} between {bbox['min_lat']} and {bbox['max_lat']} AND "
            f"{lon_col} between {bbox['min_lon']} and {bbox['max_lon']}"
        )
    print(f"[socrata] 311 query where={where!r}")
    return query(dataset["id"], where=where, limit=limit)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--smoke", action="store_true",
                         help="Run the Chinatown-bbox 311 smoke test")
    args = parser.parse_args()

    if args.smoke:
        rows = query_311_in_bbox()
        print(f"[socrata] smoke: {len(rows)} rows in Chinatown bbox")
        if len(rows) == 0:
            print("[socrata] FAIL: expected >0 rows", file=sys.stderr)
            return 1
        print("[socrata] OK")
        return 0

    parser.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
