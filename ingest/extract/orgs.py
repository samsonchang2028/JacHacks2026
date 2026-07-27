# ============================================================
# orgs.py — Organization contact extraction (Task 5).
#
# Hard rule from docs/p1ingestion.md §0.2: org-level contacts only.
# Never collect named individuals, never build person-level
# records. If a page lists individuals, extract the org email
# and discard the rest. `inside_process` is set by hand in
# config/orgs.yaml — never by the model.
# ============================================================
from __future__ import annotations

import re

import yaml

from ingest.fetch.firecrawl_client import FirecrawlClient, FirecrawlError

ORGS_CONFIG = "ingest/config/orgs.yaml"

CONTACT_SCHEMA = {
    "type": "object",
    "properties": {
        "contact": {"type": "string"},
        "languages": {"type": "string"},
        "found": {"type": "boolean"},
    },
    "required": ["found"],
}

CONTACT_PROMPT = (
    "Find this organization's PUBLIC, ORG-LEVEL contact — a general email "
    "address or phone number published for public inquiries (e.g. "
    "info@org.org, a 'contact us' line). Do NOT return a named individual's "
    "personal email or phone, a staff directory entry, or anything from a "
    "membership/parent roster — if the page only lists individuals, look "
    "for a general org address instead and set found=false if there isn't "
    "one. Also note what languages the org appears to serve in (e.g. "
    "'en,zh'), if apparent from the page. If nothing appropriate is found, "
    "set found=false and leave other fields empty — never invent a contact."
)

CONTACT_KEYWORDS = re.compile(r"contact|about|reach|connect", re.IGNORECASE)


def load_orgs() -> list[dict]:
    with open(ORGS_CONFIG) as f:
        return yaml.safe_load(f)


def find_org_site(client: FirecrawlClient, org_name: str) -> str | None:
    try:
        results = client.search(f"{org_name} San Francisco official website", limit=3)
    except FirecrawlError as e:
        print(f"[orgs] search failed for {org_name!r}: {e}")
        return None
    for r in results:
        url = r.get("url")
        if url:
            return url
    return None


def resolve_contact(client: FirecrawlClient, org: dict) -> dict:
    """Return an org dict shaped for out/fixture.json's `organizations` list.
    Always resolves to either a contact or an explicit blank + notes saying
    where we looked — never silently skips an org (Task 5 acceptance)."""
    name = org["name"]
    base = {
        "name": name,
        "community": org.get("community", ""),
        "language": org.get("language", "en"),
        "contact": "",
        "inside_process": bool(org.get("inside_process", False)),
        "serves": org.get("serves", []),
    }

    site_url = find_org_site(client, name)
    if not site_url:
        base["notes"] = f"searched web for {name!r}, no site found"
        return base

    try:
        pages = client.map_site(site_url, search="contact")
    except FirecrawlError as e:
        base["notes"] = f"found site {site_url}, map_site failed: {e}"
        return base

    contact_pages = [u for u in pages if CONTACT_KEYWORDS.search(u)] or [site_url]

    for page_url in contact_pages[:2]:
        try:
            result = client.scrape_json(page_url, schema=CONTACT_SCHEMA, prompt=CONTACT_PROMPT)
        except FirecrawlError as e:
            print(f"[orgs] scrape failed for {page_url}: {e}")
            continue
        data = result.get("data", result)
        fields = data.get("json", data)
        if fields.get("found") and fields.get("contact"):
            base["contact"] = fields["contact"]
            if fields.get("languages"):
                base["language"] = fields["languages"]
            base["notes"] = f"resolved from {page_url}"
            return base

    base["notes"] = f"checked {site_url} and {len(contact_pages[:2])} contact page(s), no org-level contact found"
    return base


def run(orgs: list[dict] | None = None) -> list[dict]:
    client = FirecrawlClient()
    spent_before = client.credits_spent
    orgs = orgs or load_orgs()
    resolved = []
    for org in orgs:
        result = resolve_contact(client, org)
        status = result["contact"] or "(no contact — see notes)"
        print(f"[orgs] {org['name']}: {status}")
        resolved.append(result)
    print(f"[orgs] credits spent this run: {client.credits_spent - spent_before} "
          f"(lifetime: {client.credits_spent})")
    return resolved


if __name__ == "__main__":
    import json
    print(json.dumps(run(), indent=2, ensure_ascii=False))
