# ============================================================
# narrative.py — Testimony extraction from news coverage (Task 6).
#
# Firecrawl /search then /scrape per case. Speaker field takes a
# ROLE, not a private individual's name — "CCBA board member",
# not a full name — unless the person is a public official
# speaking officially (a supervisor, a department head).
# ============================================================
from __future__ import annotations

import yaml

from ingest.fetch.firecrawl_client import FirecrawlClient, FirecrawlError

SOURCES_CONFIG = "ingest/config/sources.yaml"

TESTIMONY_SCHEMA = {
    "type": "object",
    "properties": {
        "testimony": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "speaker": {"type": "string"},
                    "affiliation": {"type": "string"},
                    "claim": {"type": "string"},
                    "language": {"type": "string"},
                    "kind": {
                        "type": "string",
                        "enum": ["testimony", "argument", "evidence", "counterargument"],
                    },
                },
                "required": ["speaker", "claim"],
            },
        },
    },
    "required": ["testimony"],
}

TESTIMONY_PROMPT = (
    "Extract every distinct on-the-record statement of opinion, complaint, "
    "or argument made by a person or group quoted or paraphrased in this "
    "article, about the case it covers. For `speaker`, use a ROLE or TITLE "
    "("
    "'CCBA board member', 'Merchants association president', 'District 3 "
    "Supervisor'), never a private individual's full name — UNLESS they are "
    "a public official speaking in their official capacity, in which case "
    "their title is still preferred over their name. `affiliation` is the "
    "organization or office they represent, if stated. `claim` is their "
    "position in one sentence. `kind` is 'testimony' for a first-person "
    "account, 'argument' for a stated position, 'evidence' for a cited "
    "fact/statistic, 'counterargument' for a rebuttal to another quoted "
    "party. `language` is the language the original quote/article is in "
    "('en' unless it's an in-language outlet). If the article has no "
    "quoted or attributed positions, return an empty testimony list."
)


def load_news_targets() -> dict:
    with open(SOURCES_CONFIG) as f:
        cfg = yaml.safe_load(f)
    targets = cfg["firecrawl_targets"]
    return {"news": targets.get("news", []), "in_language": targets.get("in_language", [])}


def search_case_coverage(client: FirecrawlClient, case_query: str, limit: int = 5) -> list[str]:
    try:
        results = client.search(case_query, limit=limit, sources=["news", "web"])
    except FirecrawlError as e:
        print(f"[narrative] search failed for {case_query!r}: {e}")
        return []
    return [r["url"] for r in results if r.get("url")]


def extract_testimony(client: FirecrawlClient, url: str) -> list[dict]:
    try:
        result = client.scrape_json(url, schema=TESTIMONY_SCHEMA, prompt=TESTIMONY_PROMPT)
    except FirecrawlError as e:
        print(f"[narrative] scrape failed for {url}: {e}")
        return []

    data = result.get("data", result)
    fields = data.get("json", data)
    records = []
    for item in fields.get("testimony", []):
        if not item.get("speaker") or not item.get("claim"):
            continue
        records.append({
            "speaker": item["speaker"],
            "affiliation": item.get("affiliation", ""),
            "claim": item["claim"],
            "language": item.get("language", "en"),
            "kind": item.get("kind", "testimony"),
            "source_url": url,
        })
    return records


def run(case_queries: list[str], articles_per_case: int = 4) -> list[dict]:
    """case_queries: search strings, one per case, e.g.
    "Portsmouth Square Chinatown bridge removal opposition"."""
    client = FirecrawlClient()
    spent_before = client.credits_spent
    all_testimony: list[dict] = []

    for query in case_queries:
        urls = search_case_coverage(client, query, limit=articles_per_case)
        print(f"[narrative] {query!r}: {len(urls)} article(s)")
        for url in urls:
            records = extract_testimony(client, url)
            if records:
                print(f"[narrative] {len(records)} testimony record(s) from {url}")
            all_testimony.extend(records)

    print(f"[narrative] credits spent this run: {client.credits_spent - spent_before} "
          f"(lifetime: {client.credits_spent})")
    return all_testimony


if __name__ == "__main__":
    import json

    from ingest.case import list_cases

    testimony = run([m["search_terms"]["news"] for m in list_cases()])
    print(json.dumps(testimony, indent=2, ensure_ascii=False))
