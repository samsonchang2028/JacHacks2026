# ============================================================
# reddit.py — Reddit ingestion via Apify's Reddit Scraper.
#
# Why not the Reddit API: self-service OAuth registration closed
# Nov 2025; unauthenticated .json endpoints started 403ing May
# 2026. There is no sanctioned API path for a new hackathon
# project, so this rides Apify's maintained actor
# (trudax/reddit-scraper — verified to exist and its input schema
# fetched live 2026-07-26) rather than a homemade Playwright
# script that Reddit's anti-bot churn would break mid-demo.
# Playwright remains a documented fallback in the plan, not here.
#
# Disclosure (per the plan): scraping Reddit sits against
# Reddit's user agreement whether done locally or via a vendor;
# this is a small, non-commercial civic-hackathon ingest and the
# team has chosen to accept that, stated plainly.
#
# Hard rules carried over from docs/p1ingestion.md §0:
#   - usernames are NEVER stored. Every author is scrubbed to the
#     generic role "resident commenter" before anything is cached
#     or returned. Forum posts are Incident-adjacent context, not
#     Testimony.
#   - cache-first: an Apify run costs real credits (~$3.40/1k
#     results), so repeated queries must be served from cache/.
#
#   python -m ingest.fetch.reddit --smoke   # spends ~a cent, 10 items
# ============================================================
from __future__ import annotations

import argparse
import os
import sys

from ingest.fetch._cache import cache_get, cache_key, cache_put

# The plan names trudax/reddit-scraper "(aka Reddit Scraper Lite)" but those
# are two different actors: plain reddit-scraper moved to a paid-rental model
# (403s: "You must rent a paid Actor"), while reddit-scraper-lite is the
# same maintainer's pay-per-event variant with an identical input schema and
# the largest user base of any Reddit actor (verified live 2026-07-26).
ACTOR_ID = "trudax/reddit-scraper-lite"

AUTHOR_ROLE = "resident commenter"


class RedditFetchError(RuntimeError):
    pass


def _api_token() -> str:
    # Plan names the var APIFY_API_TOKEN; the .env this repo actually
    # carries uses APIFY_API_KEY. Accept both, prefer the plan's name.
    token = os.environ.get("APIFY_API_TOKEN") or os.environ.get("APIFY_API_KEY")
    if not token:
        raise RedditFetchError(
            "APIFY_API_TOKEN (or APIFY_API_KEY) not set — refusing to run. "
            "Add it to .env; never hardcode it."
        )
    return token


def _make_client():
    from apify_client import ApifyClient  # deferred so tests can fake it

    return ApifyClient(_api_token())


def _scrub(item: dict, case: str, query: str) -> dict | None:
    """Map one raw actor item onto the stable output schema, dropping the
    username entirely. Field names are defensive .get chains because the
    actor's output shape shifts between builds."""
    post_id = item.get("parsedId") or item.get("id") or ""
    title = (item.get("title") or "").strip()
    body = (item.get("body") or item.get("text") or "").strip()
    if not post_id or not (title or body):
        return None
    return {
        "case": case,
        "source": "reddit",
        "scope": item.get("parsedCommunityName") or item.get("communityName") or "",
        "query": query,
        "post_id": post_id,
        "title": title,
        "body": body,
        "author_role": AUTHOR_ROLE,  # username deliberately discarded
        "permalink": item.get("url") or item.get("link") or "",
        "created_at": item.get("createdAt") or "",
        "score": int(item.get("upVotes") or 0),
        "num_comments": int(item.get("numberOfComments") or 0),
    }


def search_reddit(query: str, case: str, max_items: int = 25,
                  client=None) -> list[dict]:
    """Search Reddit posts for `query`, tied to decision-zone `case`
    (per-case keyword searches, never a subreddit firehose). Cache-first;
    a cache hit spends zero Apify credits."""
    key = cache_key("reddit_apify", {"query": query, "max_items": max_items})
    cached = cache_get(key)
    if cached is not None:
        return cached

    client = client or _make_client()
    run_input = {
        "searches": [query],
        "searchPosts": True,
        "searchComments": False,
        "searchCommunities": False,
        "searchUsers": False,
        "skipComments": True,
        "skipUserPosts": True,
        "skipCommunity": True,
        "includeMediaLinks": True,  # actor gates upvotes/comment counts behind this
        "sort": "relevance",
        "maxItems": max_items,
        "maxPostCount": max_items,
    }
    items = _run_actor(client, run_input, context=f"search {query!r}")
    records = []
    for item in items:
        rec = _scrub(item, case=case, query=query)
        if rec:
            records.append(rec)

    cache_put(key, records)
    return records


def _run_actor(client, run_input: dict, context: str) -> list[dict]:
    run = client.actor(ACTOR_ID).call(run_input=run_input)
    # apify-client >=2.x returns a pydantic Run model; older versions (and
    # test fakes) return a plain dict. Support both.
    if isinstance(run, dict):
        dataset_id = run.get("defaultDatasetId")
    else:
        dataset_id = getattr(run, "default_dataset_id", None)
    if not dataset_id:
        raise RedditFetchError(f"Apify run ({context}) returned no dataset: {run!r}")
    return list(client.dataset(dataset_id).iterate_items())


def _thread_id(url: str) -> str:
    """The base36 id shared by a post URL and all its comment URLs
    (/r/<sub>/comments/<id>/...)."""
    import re

    m = re.search(r"/comments/([a-z0-9]+)", url or "")
    return m.group(1) if m else ""


def fetch_threads(permalinks: list[str], max_comments: int = 15,
                  client=None) -> dict[str, dict]:
    """Open each thread and pull its top comments in ONE actor run
    (startUrls, not searches). Returns {thread_id: {"post": {...},
    "comments": [str, ...]}} — comment bodies only, usernames never kept,
    per the same scrub rule as posts. Cache-first."""
    permalinks = sorted(set(p for p in permalinks if p))
    key = cache_key("reddit_apify_threads",
                    {"urls": permalinks, "max_comments": max_comments})
    cached = cache_get(key)
    if cached is not None:
        return cached

    client = client or _make_client()
    run_input = {
        "startUrls": [{"url": u} for u in permalinks],
        "skipComments": False,
        "skipUserPosts": True,
        "skipCommunity": True,
        "includeMediaLinks": True,
        "maxComments": max_comments,
        "maxItems": len(permalinks) * (max_comments + 2),
    }
    items = _run_actor(client, run_input, context=f"{len(permalinks)} thread(s)")

    threads: dict[str, dict] = {}
    for item in items:
        tid = _thread_id(item.get("url") or item.get("link") or "")
        if not tid:
            continue
        slot = threads.setdefault(tid, {"post": None, "comments": []})
        if item.get("dataType") == "comment":
            body = (item.get("body") or "").strip()
            if body:
                slot["comments"].append(body)  # body only — username dropped
        else:
            slot["post"] = _scrub(item, case="", query="")

    cache_put(key, threads)
    return threads


def summarize_incident(records: list[dict]) -> dict | None:
    """Aggregate one case's posts into a single fixture-shaped Incident
    (docs/p1ingestion.md Task 7: thread counts and topic frequency only — never
    usernames, never quoted comments as Testimony). kind='forum' rather
    than shoehorning into '311'/'complaint_log'; source_url is the
    most-engaged thread's permalink so the citation resolves to something
    a human can actually read."""
    if not records:
        return None
    # Rank by comment count, not upvotes: an Incident is about discussion
    # volume, and upvote-ranking surfaces high-karma photo posts (verified
    # live: an 1851 history photo beat the bridge-demolition thread).
    top = max(records, key=lambda r: r["num_comments"])
    subs = sorted({r["scope"] for r in records if r["scope"]})
    query = records[0]["query"]
    return {
        "kind": "forum",
        "summary": (
            f"{len(records)} Reddit thread(s) matching {query!r} "
            f"across {', '.join(subs)}; most-discussed: {top['title'][:80]!r} "
            f"({top['num_comments']} comments, {top['score']} upvotes)"
        ),
        "count": len(records),
        "source_url": top["permalink"],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--smoke", action="store_true",
                         help="One small live run (10 items) against the "
                              "Portsmouth Square query; costs ~a cent uncached")
    args = parser.parse_args()

    if args.smoke:
        records = search_reddit("Portsmouth Square San Francisco",
                                case="portsmouth-square", max_items=10)
        print(f"[reddit] {len(records)} post(s)")
        for r in records[:5]:
            print(f"    r/{r['scope']} | score {r['score']} | {r['title'][:70]}")
        if any("author" in r and r["author_role"] != AUTHOR_ROLE for r in records):
            print("[reddit] FAIL: unscrubbed author", file=sys.stderr)
            return 1
        print("[reddit] OK")
        return 0

    parser.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
