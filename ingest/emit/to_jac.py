# ============================================================
# to_jac.py — reads out/fixture.json, writes Jac node/edge
# statements (in seed_signal.jac's style) to out/fixture.jac and
# prints them to stdout. This is a standalone handoff artifact,
# NOT a patch to seed_signal.jac — that file is hand-curated
# prose in places (see its CASE 1 / CASE 2 structure) and this
# never overwrites it. P1 pastes in whatever pieces of
# out/fixture.jac they want; nothing here writes to schemas/.
#
#   python -m ingest.emit.to_jac
# ============================================================
from __future__ import annotations

import json
import pathlib
import re
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
FIXTURE_PATH = REPO_ROOT / "out" / "fixture.json"
OUT_JAC_PATH = REPO_ROOT / "out" / "fixture.jac"


def _slug(name: str) -> str:
    """A short, valid Jac identifier derived from a name — e.g.
    "Chinese Consolidated Benevolent Association" -> "chinese_consolidated"."""
    words = re.findall(r"[A-Za-z0-9]+", name.lower())
    return "_".join(words[:2]) or "node"


def _uniquify(base: str, seen: dict) -> str:
    seen[base] = seen.get(base, 0) + 1
    return base if seen[base] == 1 else f"{base}{seen[base]}"


def _lit(value) -> str:
    if isinstance(value, bool):
        return "True" if value else "False"
    if isinstance(value, (int, float)):
        return str(value)
    return json.dumps(value, ensure_ascii=False)


def emit(fixture: dict) -> str:
    lines: list[str] = []
    seen: dict[str, int] = {}
    var_by_name: dict[str, str] = {}

    def var_for(name: str) -> str:
        return var_by_name.get(name, _slug(name))

    lines.append("# ---- GeoZones (from ingest fixture) ----")
    for gz in fixture.get("geo_zones", []):
        v = _uniquify(_slug(gz["name"]), seen)
        var_by_name[gz["name"]] = v
        lines.append(
            f'{v} = GeoZone(name={_lit(gz["name"])}, kind={_lit(gz["kind"])}, '
            f'population_est={_lit(gz.get("population_est", 0))}, '
            f'notes={_lit(gz.get("notes", ""))});'
        )

    lines.append("")
    lines.append("# ---- DecisionBodies ----")
    for db in fixture.get("decision_bodies", []):
        v = _uniquify(_slug(db["name"]), seen)
        var_by_name[db["name"]] = v
        lines.append(
            f'{v} = DecisionBody(name={_lit(db["name"])}, kind={_lit(db["kind"])}, '
            f'jurisdiction={_lit(db["jurisdiction"])});'
        )
        for zone_name in db.get("accountable_to", []):
            zone_var = var_for(zone_name)
            lines.append(f"{v} +>: accountable_to :+> {zone_var};")

    lines.append("")
    lines.append("# ---- Organizations ----")
    for org in fixture.get("organizations", []):
        v = _uniquify(_slug(org["name"]), seen)
        var_by_name[org["name"]] = v
        lines.append(
            f'{v} = Organization(name={_lit(org["name"])}, '
            f'community={_lit(org.get("community", ""))}, '
            f'language={_lit(org.get("language", "en"))}, '
            f'contact={_lit(org.get("contact", ""))}, '
            f'inside_process={_lit(org.get("inside_process", False))});'
        )
        for zone_name in org.get("serves", []):
            zone_var = var_for(zone_name)
            lines.append(f"{v} +>: serves :+> {zone_var};")

    lines.append("")
    lines.append("# ---- Projects ----")
    for proj in fixture.get("projects", []):
        v = _uniquify(_slug(proj["name"]), seen)
        var_by_name[proj["name"]] = v
        lines.append(
            f'{v} = Project(\n'
            f'    name={_lit(proj["name"])},\n'
            f'    category={_lit(proj["category"])},\n'
            f'    location={_lit(proj["location"])},\n'
            f'    description={_lit(proj.get("description", ""))},\n'
            f'    timeline={_lit(proj.get("timeline", ""))},\n'
            f'    source_url={_lit(proj.get("source_url", ""))},\n'
            f'    fetched_at={_lit(proj.get("fetched_at", ""))}\n'
            f");"
        )
        for zone_name in proj.get("geo_zones", []):
            lines.append(f"{v} +>: located_in :+> {var_for(zone_name)};")
        for body_name in proj.get("decision_bodies", []):
            lines.append(f"{v} +>: decided_by :+> {var_for(body_name)};")

    lines.append("")
    lines.append("# ---- CommentChannels + Deadlines ----")
    lines.append("# NOTE: wire each channel to its DecisionBody by hand with")
    lines.append("# `+>: accepts_input_via :+>` — the fixture doesn't carry")
    lines.append("# that link explicitly, so don't guess it here.")
    for ch in fixture.get("comment_channels", []):
        v = _uniquify(_slug(ch["recipient"]) + "_ch", seen)
        lines.append(
            f'{v} = CommentChannel(recipient={_lit(ch["recipient"])}, '
            f'method={_lit(ch["method"])}, '
            f'format_note={_lit(ch.get("format_note", ""))}, '
            f'languages={_lit(ch.get("languages", "en"))}, '
            f'source_url={_lit(ch["source_url"])});'
        )
        for dl in ch.get("deadlines", []):
            dv = _uniquify(v + "_deadline", seen)
            lines.append(
                f'{dv} = Deadline(kind={_lit(dl["kind"])}, date={_lit(dl["date"])}, '
                f'threshold={_lit(dl.get("threshold", ""))}, '
                f'source_url={_lit(dl["source_url"])});'
            )
            lines.append(f"{v} +>: governed_by :+> {dv};")

    lines.append("")
    lines.append("# ---- Testimony ----")
    for t in fixture.get("testimony", []):
        v = _uniquify(_slug(t["speaker"]) + "_t", seen)
        lines.append(
            f'{v} = Testimony(speaker={_lit(t["speaker"])}, '
            f'affiliation={_lit(t.get("affiliation", ""))}, '
            f'claim={_lit(t["claim"])}, '
            f'language={_lit(t.get("language", "en"))}, '
            f'kind={_lit(t.get("kind", "testimony"))}, '
            f'source_url={_lit(t.get("source_url", ""))});'
        )
    lines.append("# NOTE: wire each with `ps_anchor ++> t;` / `pk_anchor ++> t;`")
    lines.append("# and `t +>: evidences :+> <project_var>;` by hand — anchor")
    lines.append("# choice is a curation decision, not something the fixture encodes.")

    lines.append("")
    lines.append("# ---- Incidents ----")
    for inc in fixture.get("incidents", []):
        v = _uniquify("incident", seen)
        lines.append(
            f'{v} = Incident(kind={_lit(inc["kind"])}, summary={_lit(inc["summary"])}, '
            f'count={_lit(inc.get("count", 1))}, source_url={_lit(inc.get("source_url", ""))});'
        )

    return "\n".join(lines)


def main() -> None:
    with open(FIXTURE_PATH) as f:
        fixture = json.load(f)
    statements = emit(fixture)
    OUT_JAC_PATH.write_text(statements + "\n")
    print(statements)
    try:
        shown_path = OUT_JAC_PATH.relative_to(REPO_ROOT)
    except ValueError:
        shown_path = OUT_JAC_PATH
    print(f"\n# wrote {shown_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
