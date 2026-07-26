# ============================================================
# procedure.py — CommentChannel + Deadline extraction.
#
# Highest-value output in the pipeline: this backs the headline
# demo artifact (a real, deadlined, correctly-addressed comment
# ask). Hard rule from p1ingestion.md §0.3: a Deadline or
# CommentChannel without a working source_url does not get
# written. `found: false` -> emit nothing. Never let the model
# guess a date — "unknown" is a literal string, not a fallback
# we compute.
# ============================================================
from __future__ import annotations

import re

import requests
import yaml
from dateutil import parser as dateparser

from ingest.fetch.firecrawl_client import FirecrawlClient, FirecrawlError

REPO_ROOT_CONFIG = "ingest/config/sources.yaml"

PROCEDURE_SCHEMA = {
    "type": "object",
    "properties": {
        "recipient": {"type": "string"},
        "method": {"type": "string", "enum": ["email", "web_form", "in_person", "mail"]},
        "format_note": {"type": "string"},
        "languages": {"type": "string"},
        "deadline_kind": {"type": "string",
                          "enum": ["comment", "appeal", "signature", "hearing"]},
        "deadline_date": {"type": "string"},
        "found": {"type": "boolean"},
    },
    "required": ["found"],
}

PROCEDURE_PROMPT = (
    "This page may describe how to submit public comment to a government "
    "body (a commission, board, or department) — e.g. an agenda, a notice, "
    "or a 'how to comment' page. If it does NOT contain concrete comment "
    "submission instructions (a recipient, a method, and ideally a "
    "deadline), set found=false and leave every other field empty — do not "
    "guess. If it DOES, extract the recipient (office/body name), the "
    "method (email, web_form, in_person, or mail), any format note (e.g. "
    "'reference agenda item number'), the languages the process accepts "
    "comment in, the deadline kind, and the deadline date. "
    "CRITICAL: if you cannot find an explicit date, set deadline_date to "
    "the literal string 'unknown' — never estimate, infer, or guess a date "
    "from context. A wrong deadline is worse than no deadline."
)

# Keywords used to filter a mapped site down to the 3-5 pages that
# plausibly hold comment/agenda instructions, per the "map first, filter,
# then scrape_json only those" rule — never crawl a .gov site broadly.
AGENDA_KEYWORDS = re.compile(
    r"agenda|public[-_]?comment|comment[-_]?period|meeting|notice|hearing",
    re.IGNORECASE,
)


def load_targets() -> list[str]:
    with open(REPO_ROOT_CONFIG) as f:
        cfg = yaml.safe_load(f)
    return cfg["firecrawl_targets"]["procedure"]


def candidate_pages(client: FirecrawlClient, site: str, limit: int = 5) -> list[str]:
    links = client.map_site(f"https://{site}", search="public comment agenda")
    filtered = [u for u in links if AGENDA_KEYWORDS.search(u)]
    return (filtered or links)[:limit]


def normalize_date(raw: str) -> str:
    """Reformat an already-extracted date string to ISO (YYYY-MM-DD).
    This is normalization, not inference: the date text came from the
    page. If it doesn't parse cleanly, keep the original text rather than
    downgrading it to 'unknown' — that would replace real, sourced
    information with false ignorance, which is the opposite failure mode
    the no-fabrication rule is guarding against."""
    if not raw or raw == "unknown":
        return "unknown"
    try:
        return dateparser.parse(raw, fuzzy=False).date().isoformat()
    except (ValueError, OverflowError):
        return raw


def url_is_live(url: str) -> bool:
    """A source_url that 404s is functionally a fabricated fact — the page
    it once cited to no longer backs it up. Verify liveness before we ever
    write a CommentChannel out, per the no-fabrication rule."""
    try:
        resp = requests.get(url, timeout=15, allow_redirects=True)
        return resp.ok
    except requests.RequestException:
        return False


def extract_comment_channel(client: FirecrawlClient, url: str) -> dict | None:
    """scrape_json a single page; return a fixture-shaped comment_channel
    dict (with a nested deadlines list) or None if nothing was found."""
    try:
        result = client.scrape_json(url, schema=PROCEDURE_SCHEMA, prompt=PROCEDURE_PROMPT)
    except FirecrawlError as e:
        print(f"[procedure] scrape failed for {url}: {e}")
        return None

    data = result.get("data", result)
    fields = data.get("json", data)
    if not fields.get("found"):
        return None

    if not url_is_live(url):
        print(f"[procedure] SKIP {url}: page found content but URL no longer resolves (dead link)")
        return None

    channel = {
        "recipient": fields.get("recipient") or "unknown",
        "method": fields.get("method") or "web_form",
        "format_note": fields.get("format_note", ""),
        "languages": fields.get("languages", "en"),
        "source_url": url,
        "deadlines": [],
    }
    if fields.get("deadline_kind"):
        channel["deadlines"].append({
            "kind": fields["deadline_kind"],
            "date": normalize_date(fields.get("deadline_date") or "unknown"),
            "threshold": "",
            "source_url": url,
        })
    return channel


def run(sites: list[str] | None = None, pages_per_site: int = 5) -> list[dict]:
    client = FirecrawlClient()
    spent_before = client.credits_spent
    sites = sites or load_targets()
    found: list[dict] = []

    for site in sites:
        try:
            pages = candidate_pages(client, site, limit=pages_per_site)
        except FirecrawlError as e:
            print(f"[procedure] map_site failed for {site}: {e}")
            continue
        print(f"[procedure] {site}: {len(pages)} candidate page(s)")

        for url in pages:
            channel = extract_comment_channel(client, url)
            if channel:
                print(f"[procedure] FOUND comment channel at {url}")
                found.append(channel)

    print(f"[procedure] credits spent this run: {client.credits_spent - spent_before} "
          f"(lifetime: {client.credits_spent})")
    return found


if __name__ == "__main__":
    channels = run()
    print(f"[procedure] {len(channels)} comment channel(s) found")
    for ch in channels:
        print(f"  - {ch['recipient']} ({ch['method']}) -> {ch['source_url']}")
