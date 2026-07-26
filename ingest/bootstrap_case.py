# ============================================================
# bootstrap_case.py — draft a case manifest for a NEW subject.
#
#   python -m ingest.bootstrap_case --subject "Balboa Reservoir housing development"
#
# Flow: Firecrawl web research (if FIRECRAWL_API_KEY is set) ->
# LLM (claude CLI, headless) fills the RESEARCH-KNOB fields of a
# manifest -> written as <slug>.draft.yaml with
# generated_by: llm-bootstrap, verified: false -> prints the
# human review checklist.
#
# The LLM only proposes where to look (category, search terms,
# zones, candidate domains/orgs). It never asserts a deadline, a
# contact, or a comment channel — those come from the fetchers,
# and inside_process stays a hand-set judgment in orgs.yaml.
# That's the boundary that keeps "add a new case" on the right
# side of the no-fabrication rules.
#
# Degrades gracefully: with no Firecrawl key it skips research;
# with no claude CLI it writes a schema-valid skeleton seeded
# from the subject. Either way you get a reviewable draft, never
# a hard failure.
# ============================================================
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess

import yaml

from ingest.case import CASES_DIR, CaseError, slugify, validate_case
from ingest.extract.schemas import CATEGORIES

CHECKLIST = """
[bootstrap] Draft written: {path}
[bootstrap] REVIEW CHECKLIST — a draft is a hypothesis, not a case:
  1. Confirm `category` is right ({categories}) — it is P2's precedent join key.
  2. Fix `geography`: are the impact zones real GeoZone names? Is the
     decision zone the body/electorate that actually decides — not just
     where the harm lands? (That divergence is the product.)
  3. Add an `impact_bbox` if you want 311 counts (fetch/socrata.py --case).
  4. Vet `org_candidates`, then add the keepers to config/orgs.yaml WITH a
     hand-set inside_process — the model must never set that flag.
  5. Run the fetchers (procedure/orgs/narrative/forum) and check output.
  6. When satisfied: set verified: true and rename {draft_name} -> {final_name}.
"""


def _run_claude(prompt: str) -> str:
    result = subprocess.run(
        ["claude", "-p", prompt, "--model", "sonnet"],
        capture_output=True, text=True, timeout=300,
    )
    if result.returncode != 0:
        raise CaseError(f"claude CLI failed: {result.stderr[:300]}")
    return result.stdout


def research_subject(subject: str, limit: int = 5) -> list[dict]:
    """Light Firecrawl web search for grounding context. Optional — returns
    [] when no key is configured rather than failing the bootstrap."""
    if not os.environ.get("FIRECRAWL_API_KEY"):
        print("[bootstrap] no FIRECRAWL_API_KEY — skipping web research")
        return []
    from ingest.fetch.firecrawl_client import FirecrawlClient, FirecrawlError

    try:
        results = FirecrawlClient().search(subject, limit=limit)
    except FirecrawlError as e:
        print(f"[bootstrap] research search failed ({e}); continuing without it")
        return []
    return [
        {"title": r.get("title", ""), "url": r.get("url", ""),
         "snippet": (r.get("description") or r.get("markdown") or "")[:400]}
        for r in results
    ]


def _skeleton(subject: str, slug: str) -> dict:
    """Schema-valid placeholder used when no LLM is available. Every value
    is either derived from the subject verbatim or an obvious stub a human
    will replace — nothing here pretends to be researched."""
    return {
        "slug": slug,
        "title": subject,
        "category": CATEGORIES[0],
        "description": f"DRAFT SKELETON — describe what {subject!r} is and what is contested.",
        "search_terms": {"news": subject, "forum": subject},
        "geography": {
            "impact_zones": ["FILL: neighborhood(s) where the harm lands"],
            "decision_zone": "FILL: body or electorate that actually decides",
        },
        "news_domains": [],
        "procedure_targets": [],
        "org_candidates": [],
        "generated_by": "llm-bootstrap",
        "verified": False,
    }


def draft_manifest(subject: str, research: list[dict], runner=_run_claude) -> dict:
    slug = slugify(subject)
    context = "\n".join(
        f"- {r['title']} ({r['url']}): {r['snippet']}" for r in research
    ) or "(no web research available)"

    prompt = f"""You are drafting the RESEARCH PLAN for a civic-action case study. Subject: {subject}

Web research context:
{context}

Fill ONLY these research knobs — where to look, never facts:
- category: exactly one of {CATEGORIES} (what kind of government action this is)
- description: 2-3 sentences on what the case is and what is contested (used for topical-relevance filtering downstream)
- search_terms.news: one search query for news coverage of opposition/controversy
- search_terms.forum: one search query for forum (Reddit) discussion
- geography.impact_zones: the neighborhood/district names where the harm lands
- geography.decision_zone: the body or electorate that actually decides (a city commission? a district supervisor? a citywide electorate?) — this is NOT always where the impact is
- news_domains: 3-6 news site domains likely to cover it (include local/in-language outlets if apt)
- procedure_targets: 2-4 government site domains where public-comment procedure would be published
- org_candidates: 3-6 NAMES of community organizations plausibly holding a position (names only — no contacts, no assessment of their role)

Do NOT invent deadlines, contacts, comment channels, or claims about what any org believes.

Reply with ONLY a JSON object with keys: category, description, search_terms (object with news, forum), geography (object with impact_zones list, decision_zone), news_domains, procedure_targets, org_candidates."""

    try:
        raw = runner(prompt)
    except (CaseError, FileNotFoundError) as e:
        print(f"[bootstrap] LLM unavailable ({e}); writing skeleton draft")
        return _skeleton(subject, slug)

    m = re.search(r"\{.*\}", raw, re.DOTALL)
    if not m:
        raise CaseError(f"No JSON in LLM output: {raw[:200]!r}")
    fields = json.loads(m.group(0))

    manifest = {
        "slug": slug,
        "title": subject,
        "category": fields["category"],
        "description": str(fields["description"]).strip(),
        "search_terms": {
            "news": str(fields["search_terms"]["news"]),
            "forum": str(fields["search_terms"]["forum"]),
        },
        "geography": {
            "impact_zones": [str(z) for z in fields["geography"]["impact_zones"]],
            "decision_zone": str(fields["geography"]["decision_zone"]),
        },
        "news_domains": [str(d) for d in fields.get("news_domains", [])],
        "procedure_targets": [str(d) for d in fields.get("procedure_targets", [])],
        "org_candidates": [str(o) for o in fields.get("org_candidates", [])],
        "generated_by": "llm-bootstrap",
        "verified": False,
    }
    return validate_case(manifest)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--subject", required=True,
                         help='e.g. "Balboa Reservoir housing development"')
    args = parser.parse_args()

    slug = slugify(args.subject)
    final_path = CASES_DIR / f"{slug}.yaml"
    draft_path = CASES_DIR / f"{slug}.draft.yaml"
    if final_path.exists():
        print(f"[bootstrap] {final_path.name} already exists — not overwriting a "
              "verified case. Edit it directly or pick a new subject.")
        return 1

    research = research_subject(args.subject)
    print(f"[bootstrap] {len(research)} research result(s)")
    manifest = draft_manifest(args.subject, research)

    header = ("# DRAFT — generated by llm-bootstrap; a hypothesis about where to\n"
              "# look, not a verified case. Review per the checklist, then set\n"
              "# verified: true and drop the .draft from the filename.\n")
    draft_path.write_text(header + yaml.safe_dump(manifest, sort_keys=False,
                                                   allow_unicode=True))
    print(CHECKLIST.format(path=draft_path, categories=CATEGORIES,
                           draft_name=draft_path.name, final_name=final_path.name))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
