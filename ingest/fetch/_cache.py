# ============================================================
# _cache.py — shared file cache for the plain HTTP API fetchers
# (socrata, legistar). Firecrawl has its own cache
# tangled up with credit accounting; these APIs are free, so a
# plain URL-hash -> JSON cache is all they need.
# ============================================================
from __future__ import annotations

import hashlib
import json
import pathlib

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
CACHE_DIR = REPO_ROOT / "cache"


def cache_key(url: str, params: dict | None = None) -> str:
    blob = json.dumps({"url": url, "params": params or {}}, sort_keys=True)
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


def cache_get(key: str, cache_dir: pathlib.Path = CACHE_DIR) -> dict | list | None:
    path = cache_dir / f"{key}.json"
    if path.exists():
        return json.loads(path.read_text())
    return None


def cache_put(key: str, value, cache_dir: pathlib.Path = CACHE_DIR) -> None:
    cache_dir.mkdir(parents=True, exist_ok=True)
    (cache_dir / f"{key}.json").write_text(json.dumps(value, indent=2))
