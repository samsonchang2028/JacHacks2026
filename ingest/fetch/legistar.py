# ============================================================
# legistar.py — Granicus Legistar Web API for SF Board of
# Supervisors legislation.
#
# Base path resolved at runtime: verified live that the SF
# client identifier is "sfgov" (webapi.legistar.com/v1/sfgov/*),
# not "sanfrancisco" or any other guess — don't hardcode past
# this file without re-checking, per the "resolve at runtime"
# rule for all endpoint paths in the ingestion spec.
#
# ⚠️ DATA IS STALE (verified live 2026-07-26): the newest matter
# in this API is Sept 2020 — SF stopped syncing it to the Granicus
# Web API. Keyword search works and returns real legislative
# records (e.g. 'Portsmouth Square' -> 6 matters, 'Great Highway'
# -> 10), but everything is 1999-2020. Neither the Portsmouth
# Square renovation (2023+) nor Prop K (2024) exists here. Treat
# this as a historical-precedent source only, never as a source
# for current/pending items — the spec's §3 assumption that this
# is "the real source for pending legislative items" is false for
# SF today.
#
#   python -m ingest.fetch.legistar --smoke
# ============================================================
from __future__ import annotations

import argparse
import sys

import requests

from ingest.fetch._cache import cache_get, cache_key, cache_put

CANDIDATE_CLIENTS = ["sfgov", "sanfrancisco"]
BASE = "https://webapi.legistar.com/v1"


def resolve_client() -> str:
    """Probe candidate client identifiers against /Bodies and cache
    whichever one actually responds. Do not trust "sfgov" as gospel —
    Legistar client slugs are per-deployment and can change."""
    key = cache_key("legistar_client", {})
    cached = cache_get(key)
    if cached is not None:
        return cached["client"]

    for client in CANDIDATE_CLIENTS:
        resp = requests.get(f"{BASE}/{client}/Bodies", params={"$top": 1}, timeout=20)
        if resp.ok:
            print(f"[legistar] resolved client -> {client!r}")
            cache_put(key, {"client": client})
            return client
    raise RuntimeError(f"No working Legistar client among {CANDIDATE_CLIENTS}")


def _get(path: str, params: dict | None = None) -> list | dict:
    client = resolve_client()
    key = cache_key(f"legistar_{path}", {"client": client, "params": params or {}})
    cached = cache_get(key)
    if cached is not None:
        return cached

    resp = requests.get(f"{BASE}/{client}/{path}", params=params or {}, timeout=30)
    resp.raise_for_status()
    data = resp.json()
    cache_put(key, data)
    return data


def get_bodies() -> list[dict]:
    return _get("Bodies", {"$top": 200})


def get_body_id(name_contains: str) -> int | None:
    for body in get_bodies():
        if name_contains.lower() in body["BodyName"].lower():
            return body["BodyId"]
    return None


def recent_matters(top: int = 25) -> list[dict]:
    """Most recently introduced legislative matters, newest first."""
    return _get("Matters", {"$top": top, "$orderby": "MatterIntroDate desc"})


def search_matters(keyword: str, top: int = 25) -> list[dict]:
    """Matters whose title mentions `keyword` (e.g. a project name)."""
    params = {
        "$top": top,
        "$filter": f"substringof('{keyword}',MatterTitle)",
        "$orderby": "MatterIntroDate desc",
    }
    return _get("Matters", params)


def get_events_for_body(body_id: int, top: int = 25) -> list[dict]:
    """Agendas/meetings for a body (e.g. Board of Supervisors, a commission)."""
    params = {
        "$top": top,
        "$filter": f"EventBodyId eq {body_id}",
        "$orderby": "EventDate desc",
    }
    return _get("Events", params)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--smoke", action="store_true",
                         help="Resolve the client and fetch recent Board of "
                              "Supervisors matters")
    args = parser.parse_args()

    if args.smoke:
        client = resolve_client()
        body_id = get_body_id("Board of Supervisors")
        matters = recent_matters(top=5)
        print(f"[legistar] client={client!r} board_id={body_id} "
              f"recent_matters={len(matters)}")
        if not matters:
            print("[legistar] FAIL: expected >0 recent matters", file=sys.stderr)
            return 1
        print("[legistar] OK")
        return 0

    parser.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
