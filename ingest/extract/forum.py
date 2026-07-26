# ============================================================
# forum.py — per-thread Reddit summaries -> Incident records.
#
# Upgrades the aggregate "N threads matching <query>" Incident
# into one Incident per relevant thread, each carrying a 1-2
# sentence LLM summary of what the discussion actually says.
#
# byLLM boundary (DESIGNDOC §5.5): the LLM does framing and
# classification ONLY — it summarizes and judges topical
# relevance. It never produces deadlines, contacts, or legal
# facts, and the summary rules mirror the spec's Reddit rules:
# paraphrase, no usernames, no direct quotations. Forum content
# stays Incident-adjacent context, never Testimony.
#
# LLM runner: the `claude` CLI in headless mode (-p). It's
# already authenticated on this machine, costs no new API key,
# and is trivially fakeable in tests via the `runner` arg.
#
#   python -m ingest.extract.forum        # rebuilds fixture incidents
# ============================================================
from __future__ import annotations

import json
import re
import subprocess

from ingest.fetch.reddit import fetch_threads, search_reddit

# What each case is actually about, for the relevance judgment.
CASES = [
    {
        "case": "portsmouth-square",
        "query": "Portsmouth Square San Francisco",
        "description": (
            "The Portsmouth Square Improvement Project in SF Chinatown: the "
            "~$73M renovation, the removal of the pedestrian bridge over "
            "Kearny St, the ~2-year park closure, and community reaction "
            "to any of those."
        ),
    },
    {
        "case": "prop-k-great-highway",
        "query": "Great Highway Prop K San Francisco",
        "description": (
            "Proposition K (Nov 2024) permanently closing the Upper Great "
            "Highway to cars, the resulting park, the westside opposition, "
            "lawsuits, recall, and follow-up ballot measures."
        ),
    },
]


class ForumSummaryError(RuntimeError):
    pass


def _run_claude(prompt: str) -> str:
    result = subprocess.run(
        ["claude", "-p", prompt, "--model", "haiku"],
        capture_output=True, text=True, timeout=180,
    )
    if result.returncode != 0:
        raise ForumSummaryError(f"claude CLI failed: {result.stderr[:300]}")
    return result.stdout


def _extract_json(raw: str) -> dict:
    m = re.search(r"\{.*\}", raw, re.DOTALL)
    if not m:
        raise ForumSummaryError(f"No JSON object in LLM output: {raw[:200]!r}")
    return json.loads(m.group(0))


def summarize_thread(post: dict, comments: list[str], case_description: str,
                     runner=_run_claude) -> dict:
    """One thread -> {"summary": str, "relevant": bool}. The relevance flag
    filters out e.g. 1851 history-photo posts that keyword search drags in."""
    comment_block = "\n".join(
        f"- {c[:400]}" for c in comments[:15]
    ) or "(no comments captured)"
    prompt = f"""Summarize this Reddit thread in 1-2 neutral sentences: what is being discussed and what the prevailing sentiments are. Rules: paraphrase only — no direct quotations, no usernames, no invented specifics. Then judge whether the thread is topically about this civic case: {case_description}

THREAD TITLE: {post.get('title', '')}
POST BODY: {(post.get('body') or '(link/image post, no text)')[:1200]}
COMMENTS:
{comment_block}

Reply with ONLY a JSON object, no other text:
{{"summary": "<1-2 sentences>", "relevant": true/false}}"""
    data = _extract_json(runner(prompt))
    if "summary" not in data or "relevant" not in data:
        raise ForumSummaryError(f"LLM JSON missing keys: {data!r}")
    return {"summary": str(data["summary"]).strip(),
            "relevant": bool(data["relevant"])}


def build_incidents(case_cfg: dict, posts: list[dict], threads: dict,
                    runner=_run_claude) -> list[dict]:
    """This case's relevant threads -> fixture-shaped Incident records, one
    per thread. count = comment volume (the countable signal); summary leads
    with the subreddit and size so the LLM sentence has provenance."""
    from ingest.fetch.reddit import _thread_id

    incidents = []
    for post in posts:
        t = threads.get(_thread_id(post["permalink"]))
        if not t or not t.get("post"):
            continue
        result = summarize_thread(t["post"], t["comments"], case_cfg["description"],
                                  runner=runner)
        if not result["relevant"]:
            print(f"[forum] skip (off-topic): {post['title'][:60]!r}")
            continue
        incidents.append({
            "kind": "forum",
            "summary": (
                f"r/{post['scope']} thread, {post['num_comments']} comments: "
                f"{result['summary']}"
            ),
            "count": post["num_comments"],
            "source_url": post["permalink"],
        })
        print(f"[forum] ok: {post['title'][:60]!r}")
    return sorted(incidents, key=lambda i: -i["count"])


def main() -> int:
    import pathlib

    # One fetch_threads call across ALL cases: its cache key is the sorted
    # permalink set, so per-case subsets would miss cache and re-spend an
    # actor run (learned the expensive way).
    posts_by_case = {
        cfg["case"]: search_reddit(cfg["query"], case=cfg["case"], max_items=10)
        for cfg in CASES
    }
    all_links = [p["permalink"] for posts in posts_by_case.values() for p in posts]
    threads = fetch_threads(all_links, max_comments=15)

    fixture_path = pathlib.Path(__file__).resolve().parents[2] / "out" / "fixture.json"
    all_incidents = []
    for case_cfg in CASES:
        print(f"[forum] === {case_cfg['case']} ===")
        all_incidents.extend(
            build_incidents(case_cfg, posts_by_case[case_cfg["case"]], threads))

    fixture = json.loads(fixture_path.read_text())
    fixture["incidents"] = all_incidents
    fixture_path.write_text(json.dumps(fixture, indent=2, ensure_ascii=False) + "\n")
    print(f"[forum] wrote {len(all_incidents)} incident(s) to {fixture_path.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
