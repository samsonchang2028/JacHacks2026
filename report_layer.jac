# ============================================================
# report_layer.jac — the LLM briefing layer over the issue workup.
#
# Takes everything the graph reports for one issue (issue_payload in
# main.jac) and congregates it into a compact briefing, because the full
# workup is a lot of text. The LLM SUMMARIZES retrieved content only —
# same boundary as everywhere else in this repo:
#
#   - runner: the `claude` CLI in headless mode, mirroring
#     ingest/extract/forum.py (already authenticated, no new key);
#   - the prompt forbids new facts, and a validator enforces it: any URL
#     or email in the output, any multi-digit number absent from the
#     source payload, any legal-conclusion phrase, or any structural
#     violation rejects the whole summary;
#   - rejection (or a missing CLI) falls back to a deterministic extract
#     of the same payload — the endpoint never fails because a model did
#     (the RecommendRecourse pattern);
#   - output is cached to out/reports/<slug>.json, a disk artifact like
#     every other pipeline stage, so the demo never blocks on a live call.
#
# Nothing here invents deadlines, contacts, channels, or standards, and
# `legal_reviewed` is always false.
# ============================================================

import json;
import re;
import subprocess;
import from datetime { datetime }
import from pathlib { Path }


glob REPORT_MODEL: str = "haiku";
glob REPORT_TIMEOUT_S: int = 120;

# Lowercased contains-check. The briefing states process facts, never
# legal conclusions; these phrases mark a summary that crossed the line.
glob FORBIDDEN_PHRASES: list[str] = [
    "satisfies", "proves", "legally required", "legal advice",
    "guarantee", "entitled to", "violates",
];


# ---- artifact I/O ----------------------------------------------------------

def reports_dir() -> str {
    return str(Path(__file__ or "").resolve().parent / "out" / "reports");
}


def report_path(slug: str) -> str {
    return str(Path(reports_dir()) / (slug + ".json"));
}


def load_cached_report(slug: str) -> dict {
    path = Path(report_path(slug));
    if not path.exists() {
        return {};
    }
    try {
        with open(str(path), "r", encoding="utf-8") as report_file {
            loaded = json.load(report_file);
        }
    } except Exception {
        return {};
    }
    if isinstance(loaded, dict) {
        return loaded;
    }
    return {};
}


def save_report(slug: str, briefing: dict) {
    try {
        Path(reports_dir()).mkdir(parents=True, exist_ok=True);
        with open(report_path(slug), "w", encoding="utf-8") as report_file {
            json.dump(briefing, report_file, indent=2, ensure_ascii=False);
        }
    } except Exception {
        # A read-only disk should not take the endpoint down; the briefing
        # is still returned, just not cached.
        return;
    }
}


# ---- typed accessors over payload dicts -------------------------------------
# The payload comes from our own issue_payload, but the checker (and any
# hand-edited cached report) gets honest narrowing instead of `any` flow.

def text_field(source: dict, key: str) -> str {
    value = source.get(key);
    if isinstance(value, str) {
        return value;
    }
    return "";
}


def list_field(source: dict, key: str) -> list {
    value = source.get(key);
    if isinstance(value, list) {
        return value;
    }
    return [];
}


def dict_field(source: dict, key: str) -> dict {
    value = source.get(key);
    if isinstance(value, dict) {
        return value;
    }
    return {};
}


# ---- LLM-facing source -----------------------------------------------------

def strip_refs(text: str) -> str {
    return re.sub(r"\[\d+\]", "", text).strip();
}


"""The trimmed, LLM-facing subset of the workup. Deliberately excludes
every URL, email, and pipeline channel record so the model cannot echo a
contact or a deadline into prose — those render only in the cited tables."""
def briefing_source(payload: dict) -> dict {
    route: list = [];
    for hop in list_field(payload, "route") {
        if isinstance(hop, dict) {
            route.append({
                "role": text_field(hop, "role"),
                "name": text_field(hop, "name"),
                "note": text_field(hop, "note"),
            });
        }
    }
    organizers: list = [];
    for org in list_field(payload, "organizers") {
        if isinstance(org, dict) {
            organizers.append({
                "name": text_field(org, "name"),
                "role": text_field(org, "role"),
            });
        }
    }
    outreach_names: list = [];
    for org in list_field(payload, "outreach") {
        if isinstance(org, dict) {
            outreach_names.append(text_field(org, "name"));
        }
    }
    testimony: list = [];
    for t in list_field(payload, "testimony") {
        if isinstance(t, dict) {
            testimony.append({
                "speaker": text_field(t, "speaker"),
                "kind": text_field(t, "kind"),
                "claim": text_field(t, "claim"),
            });
        }
    }
    signals: list = [];
    comment_total = 0;
    for sig in list_field(payload, "signals") {
        if isinstance(sig, dict) {
            signals.append({
                "count": sig.get("count"),
                "summary": text_field(sig, "summary"),
            });
            count_value = sig.get("count");
            if isinstance(count_value, int) {
                comment_total += count_value;
            }
        }
    }
    return {
        "title": text_field(payload, "title"),
        "district": text_field(payload, "district"),
        "problem": strip_refs(text_field(payload, "problem")),
        "divergence": payload.get("divergence"),
        "impact_zone": text_field(payload, "impact_zone"),
        "decision_zone": text_field(payload, "decision_zone"),
        "zones_match": payload.get("zones_match"),
        "route": route,
        "counts": list_field(payload, "counts"),
        "not_counts": list_field(payload, "not_counts"),
        "organizers": organizers,
        "outreach_organizations": outreach_names,
        "testimony": testimony,
        "forum_threads": signals,
        # Deterministic arithmetic on retrieved counts, computed here so a
        # summary wanting a total has the exact one to copy (a model-derived
        # sum or rounding would be rejected by the number validator).
        "forum_comment_total": comment_total,
        "testimony_count": len(testimony),
        "forum_thread_count": len(signals),
        "actions": list_field(payload, "actions"),
    };
}


def briefing_prompt(source_text: str) -> str {
    return (
        "You write Quorum's issue briefing. Compress the civic-issue workup "
        + "JSON below into a compact briefing.\n\n"
        + "Hard rules:\n"
        + "- Use ONLY facts present in the JSON. Do not introduce any number, "
        + "date, percentage, deadline, person, organization, URL, or email "
        + "that does not appear in it.\n"
        + "- Never compute, total, round, or estimate a number ('over N', "
        + "'about N', 'N+'). Copy numbers exactly as they appear, or write "
        + "none at all.\n"
        + "- No URLs and no email addresses anywhere in the output.\n"
        + "- Never state or imply that a legal standard is met; no legal advice.\n"
        + "- Neutral on the outcome. The only stance allowed is about process: "
        + "getting the community's input counted where it decides.\n"
        + "- Plain, direct sentences. No hype.\n\n"
        + "Reply with ONLY a JSON object, no other text:\n"
        + "{\"verdict_line\": \"<= 20 words, the one-sentence verdict\",\n"
        + " \"stakes\": \"<= 45 words: what this issue is and who actually decides it\",\n"
        + " \"record_gap\": \"<= 45 words: what signal exists (testimony, forum threads) versus what the official record holds\",\n"
        + " \"do_next\": [\"<= 16 words each: exactly three concrete steps, one per action in the JSON, in rank order\"]}\n\n"
        + "WORKUP JSON:\n"
        + source_text
    );
}


def run_claude(prompt: str) -> str {
    try {
        result = subprocess.run(
            ["claude", "-p", prompt, "--model", REPORT_MODEL],
            capture_output=True, text=True, timeout=REPORT_TIMEOUT_S,
        );
    } except Exception {
        return "";
    }
    if result.returncode != 0 {
        return "";
    }
    return result.stdout;
}


def extract_json(raw: str) -> dict {
    # (?s): dot matches newlines — inline form of re.DOTALL.
    matched = re.search(r"(?s)\{.*\}", raw);
    if matched is None {
        return {};
    }
    fragment = matched.group(0);
    if not isinstance(fragment, str) {
        return {};
    }
    try {
        loaded = json.loads(fragment);
    } except Exception {
        return {};
    }
    if isinstance(loaded, dict) {
        return loaded;
    }
    return {};
}


# ---- validation: the summary may compress facts, never add them ------------

def clean_text(value: any) -> str {
    if isinstance(value, str) {
        return value.strip();
    }
    return "";
}


def over_words(text: str, cap: int) -> bool {
    return len(text.split()) > cap;
}


"""Number tokens with thousands-separators normalized away — but only
separators *inside* one number ("269,000" -> "269000"). A blanket comma
strip is wrong: it glues lists like "1,4,7,11" into one fake run."""
def number_tokens(text: str) -> list[str] {
    tokens: list[str] = [];
    for run in re.findall(r"\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?", text) {
        if isinstance(run, str) {
            tokens.append(run.replace(",", ""));
        }
    }
    return tokens;
}


"""Every number token of length >= 2 in the briefing must appear among the
source payload's number tokens. Single digits pass: the false-positive
cost of banning "2 years" outweighs the fabrication risk. The substring
check keeps "54" valid against a source "54.73"."""
def novel_numbers(briefing_text: str, source_text: str) -> list[str] {
    haystack = " " + " ".join(number_tokens(source_text)) + " ";
    novel: list[str] = [];
    for token in number_tokens(briefing_text) {
        if len(token) < 2 {
            continue;
        }
        if token not in haystack {
            novel.append(token);
        }
    }
    return novel;
}


def validate_briefing(candidate: dict, source_text: str) -> list[str] {
    errors: list[str] = [];
    verdict_line = clean_text(candidate.get("verdict_line"));
    stakes = clean_text(candidate.get("stakes"));
    record_gap = clean_text(candidate.get("record_gap"));
    if verdict_line == "" or stakes == "" or record_gap == "" {
        errors.append("missing or blank briefing field");
    }
    if over_words(verdict_line, 26) or over_words(stakes, 60) or over_words(record_gap, 60) {
        errors.append("briefing field over word cap");
    }

    steps_value = candidate.get("do_next");
    steps: list[str] = [];
    if isinstance(steps_value, list) {
        for step in steps_value {
            cleaned = clean_text(step);
            if cleaned != "" and not over_words(cleaned, 24) {
                steps.append(cleaned);
            }
        }
    }
    if len(steps) != 3 {
        errors.append("do_next must be exactly three non-blank steps");
    }

    combined = verdict_line + " " + stakes + " " + record_gap + " " + " ".join(steps);
    if re.search(r"https?://", combined) or re.search(r"\S+@\S+\.\S+", combined) {
        errors.append("briefing may not contain URLs or email addresses");
    }
    lowered = combined.lower();
    for phrase in FORBIDDEN_PHRASES {
        if phrase in lowered {
            errors.append("forbidden phrase: " + phrase);
        }
    }
    for run in novel_numbers(combined, source_text) {
        errors.append("number not present in the retrieved payload: " + run);
    }
    return errors;
}


# ---- deterministic fallback -------------------------------------------------

def first_sentences(text: str, how_many: int) -> str {
    parts = re.split(r"(?<=[.!?])\s+", strip_refs(text));
    kept: list[str] = [];
    for part in parts {
        if isinstance(part, str) and len(part.strip()) > 0 and len(kept) < how_many {
            kept.append(part);
        }
    }
    return " ".join(kept);
}


"""No model involved: verdict and stakes are extracts of curated fields,
the record-gap line is composed from retrieved counts, and the steps are
the curated ActionSteps verbatim."""
def deterministic_briefing(payload: dict) -> dict {
    divergence = dict_field(payload, "divergence");
    verdict_line = text_field(payload, "short");
    record_gap = "";
    if len(divergence) > 0 {
        verdict_line = text_field(divergence, "headline");
        record_gap = first_sentences(text_field(divergence, "why"), 1) + " ";
    }
    record_gap = record_gap + (
        str(len(list_field(payload, "testimony"))) + " statements and "
        + str(len(list_field(payload, "signals")))
        + " community threads are on file for this case."
    );
    steps: list[str] = [];
    for action in list_field(payload, "actions") {
        if isinstance(action, dict) and len(steps) < 3 {
            steps.append(text_field(action, "what"));
        }
    }
    return {
        "verdict_line": verdict_line,
        "stakes": first_sentences(text_field(payload, "problem"), 2),
        "record_gap": record_gap,
        "do_next": steps,
    };
}


# ---- entry point -------------------------------------------------------------

def generate_briefing(payload: dict) -> dict {
    source = briefing_source(payload);
    source_text = json.dumps(source, ensure_ascii=False);

    # One retry: a transient CLI failure or a single hallucinated token
    # should not consign a slug to the fallback forever. Two strikes do.
    candidate = extract_json(run_claude(briefing_prompt(source_text)));
    errors = validate_briefing(candidate, source_text);
    if len(errors) > 0 {
        candidate = extract_json(run_claude(briefing_prompt(source_text)));
        errors = validate_briefing(candidate, source_text);
    }

    if len(errors) == 0 {
        steps: list[str] = [];
        for step in list_field(candidate, "do_next") {
            steps.append(clean_text(step));
        }
        body = {
            "verdict_line": clean_text(candidate.get("verdict_line")),
            "stakes": clean_text(candidate.get("stakes")),
            "record_gap": clean_text(candidate.get("record_gap")),
            "do_next": steps,
        };
        origin = "llm";
        model = "claude " + REPORT_MODEL + " (CLI, headless)";
    } else {
        body = deterministic_briefing(payload);
        origin = "deterministic_fallback";
        model = "";
    }

    return {
        "found": True,
        "available": True,
        "slug": text_field(payload, "slug"),
        "title": text_field(payload, "title"),
        "origin": origin,
        "model": model,
        "ai_generated": origin == "llm",
        "generated_at": datetime.now().isoformat()[:19],
        "verdict_line": body["verdict_line"],
        "stakes": body["stakes"],
        "record_gap": body["record_gap"],
        "do_next": body["do_next"],
        "summarized_from": {
            "statements": len(list_field(payload, "testimony")),
            "threads": len(list_field(payload, "signals")),
            "actions": len(list_field(payload, "actions")),
            "organizations": (
                len(list_field(payload, "organizers"))
                + len(list_field(payload, "outreach"))
            ),
        },
        "validation_errors": errors,
        "legal_reviewed": False,
    };
}


"""Cache-first: the checked-in artifact serves instantly; `regenerate`
forces a live LLM run and rewrites out/reports/<slug>.json."""
def issue_briefing(payload: dict, regenerate: bool) -> dict {
    slug = text_field(payload, "slug");
    if not regenerate {
        cached = load_cached_report(slug);
        if len(cached) > 0 {
            return cached;
        }
    }
    briefing = generate_briefing(payload);
    save_report(slug, briefing);
    return briefing;
}
