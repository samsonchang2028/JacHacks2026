# ============================================================
# outreach_layer.jac — staged outreach email drafts, per association.
#
# The packet is the wrapper around the playbook's ask (DESIGNDOC): each
# draft asks one listed organization to put its own position on the
# record through the channel that counts. Hard rules, inherited from
# docs/p1ingestion.md §0 and AGENTS.md:
#
#   - NOTHING IS SENT. Drafts are staged to out/drafts/<slug>/ (gitignored
#     by design) for a human to review and send. No SMTP, no send button.
#   - Org-level only. Drafts are generated only for fixture-backed
#     organizations; curated organizer cards that are individuals or
#     campaign entities (no pipeline org record) are skipped.
#   - No presumed position. The draft asks the organization to file its
#     view if it holds one; it never asserts support or opposition.
#   - No generated facts. Same validator stack as the briefing layer —
#     no URLs/emails in prose, no numbers absent from the payload, no
#     legal-conclusion phrases — plus: when no verified deadline exists,
#     the draft may not name a date or a month at all.
#   - Bilingual: a zh-language org gets a Traditional Chinese body too,
#     labeled for native-speaker review. The deterministic fallback is
#     EN-only (we do not machine-translate deterministically).
# ============================================================

import json;
import re;
import from datetime { datetime }
import from pathlib { Path }

import from report_layer {
    text_field, list_field, dict_field, clean_text, strip_refs,
    over_words, extract_json, run_claude, novel_numbers, first_sentences,
    FORBIDDEN_PHRASES,
}


glob MONTH_WORDS: list[str] = [
    "january", "february", "march", "april", "may ", "june", "july",
    "august", "september", "october", "november", "december",
];


# ---- staging I/O (out/drafts/, never an outbox) ------------------------------

def org_slug(name: str) -> str {
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-");
}


def draft_path(slug: str, org_name: str) -> str {
    base = Path(__file__ or "").resolve().parent / "out" / "drafts" / slug;
    return str(base / (org_slug(org_name) + ".json"));
}


def load_cached_draft(slug: str, org_name: str) -> dict {
    path = Path(draft_path(slug, org_name));
    if not path.exists() {
        return {};
    }
    try {
        with open(str(path), "r", encoding="utf-8") as draft_file {
            loaded = json.load(draft_file);
        }
    } except Exception {
        return {};
    }
    if isinstance(loaded, dict) {
        return loaded;
    }
    return {};
}


def save_draft(slug: str, org_name: str, draft: dict) {
    try {
        path = Path(draft_path(slug, org_name));
        path.parent.mkdir(parents=True, exist_ok=True);
        with open(str(path), "w", encoding="utf-8") as draft_file {
            json.dump(draft, draft_file, indent=2, ensure_ascii=False);
        }
    } except Exception {
        return;
    }
}


# ---- LLM-facing source -------------------------------------------------------

"""What the model may draw on. Contacts and URLs are deliberately absent:
the To: line renders verbatim from the graph, never through the model.
`verified_deadline` is "" when no sourced deadline exists — and then the
draft may not name any date."""
def draft_source(payload: dict, org: dict) -> dict {
    verified_deadline = "";
    for r in list_field(payload, "resources") {
        if isinstance(r, dict) {
            # The deadline resource row is the only one whose value is a
            # date; it counts only when it carries a source.
            if "deadline" in text_field(r, "label").lower()
                and text_field(r, "source_url") != ""
                and text_field(r, "value") != ""
                and text_field(r, "value") != "No record retrieved" {
                verified_deadline = text_field(r, "value");
            }
        }
    }
    actions: list = [];
    for a in list_field(payload, "actions") {
        if isinstance(a, dict) {
            actions.append({
                "rank": a.get("rank"),
                "what": text_field(a, "what"),
                "how": text_field(a, "how"),
            });
        }
    }
    channel_format = "";
    body_name = "";
    for r in list_field(payload, "resources") {
        if isinstance(r, dict) {
            if text_field(r, "label") == "Channel that counts" {
                channel_format = text_field(r, "value");
            }
            if text_field(r, "label") == "Who decides" {
                body_name = text_field(r, "value");
            }
        }
    }
    # The initial signal the pipeline already collected for this case.
    # Totals are computed here, deterministically, so a draft citing them
    # copies exact numbers instead of doing arithmetic.
    example_claims: list = [];
    comment_total = 0;
    for t in list_field(payload, "testimony") {
        if isinstance(t, dict) and len(example_claims) < 3 {
            example_claims.append({
                "speaker": text_field(t, "speaker"),
                "claim": text_field(t, "claim"),
            });
        }
    }
    for sig in list_field(payload, "signals") {
        if isinstance(sig, dict) {
            count_value = sig.get("count");
            if isinstance(count_value, int) {
                comment_total += count_value;
            }
        }
    }
    return {
        "issue_title": text_field(payload, "title"),
        "district": text_field(payload, "district"),
        "problem": strip_refs(text_field(payload, "problem")),
        "who_decides": body_name,
        "channel_that_counts": channel_format,
        "verified_deadline": verified_deadline,
        "what_counts_as_input": list_field(payload, "counts"),
        "ask": actions,
        "initial_signal": {
            "testimony_count": len(list_field(payload, "testimony")),
            "forum_thread_count": len(list_field(payload, "signals")),
            "forum_comment_total": comment_total,
            "example_claims": example_claims,
        },
        "recipient_organization": {
            "name": text_field(org, "name"),
            "community": text_field(org, "community"),
            "language": text_field(org, "language"),
        },
    };
}


def draft_prompt(source_text: str, wants_zh: bool) -> str {
    zh_clause = (
        "Because the organization's language is zh, also produce body_zh: the "
        + "same letter in Traditional Chinese (繁體中文). Keep it faithful to "
        + "body_en — no extra facts. Keep organization and body proper names "
        + "exactly as written in the JSON (do not translate or guess Chinese "
        + "names for them).\n"
    ) if wants_zh else "Set body_zh to the empty string.\n";
    return (
        "You draft outreach email copy for Quorum. Write a short email to the "
        + "recipient organization asking it to put ITS OWN position on this "
        + "civic issue into the official record, through the channel that "
        + "counts.\n\n"
        + "Hard rules:\n"
        + "- Use ONLY facts present in the JSON. No number, date, deadline, "
        + "name, organization, URL, or email that does not appear in it.\n"
        + "- If verified_deadline is empty, do NOT mention any date, month, or "
        + "deadline; instead say the comment window should be confirmed with "
        + "the body directly.\n"
        + "- NEVER assert or assume the organization supports or opposes the "
        + "project. The email asks them to file their view, whatever it is.\n"
        + "- In one or two sentences, cite the initial signal that already "
        + "exists for this case (initial_signal: the testimony count, forum "
        + "thread count, and forum comment total) — as evidence that community "
        + "attention is already documented, never as proof of the recipient's "
        + "position.\n"
        + "- The call to action is the ranked ask from the JSON: a distinct, "
        + "correctly-addressed submission in the organization's own words.\n"
        + "- No legal claims, no legal advice, no pressure tactics, no hype.\n"
        + "- End the email with the literal placeholder [Your name].\n"
        + "- body_en at most 160 words. Subject at most 12 words.\n"
        + zh_clause
        + "\nReply with ONLY a JSON object, no other text:\n"
        + "{\"subject\": \"...\", \"body_en\": \"...\", \"body_zh\": \"...\"}\n\n"
        + "WORKUP JSON:\n"
        + source_text
    );
}


# ---- validation ---------------------------------------------------------------

def validate_draft(
    candidate: dict,
    source_text: str,
    wants_zh: bool,
    has_verified_deadline: bool,
) -> list[str] {
    errors: list[str] = [];
    subject = clean_text(candidate.get("subject"));
    body_en = clean_text(candidate.get("body_en"));
    body_zh = clean_text(candidate.get("body_zh"));

    if subject == "" or body_en == "" {
        errors.append("missing subject or body_en");
    }
    if over_words(subject, 14) or over_words(body_en, 190) {
        errors.append("subject or body over length cap");
    }
    if wants_zh and body_zh == "" {
        errors.append("zh-language org requires body_zh");
    }
    if not wants_zh and body_zh != "" {
        errors.append("unexpected body_zh");
    }
    if body_zh != "" and len(body_zh) > 900 {
        errors.append("body_zh over length cap");
    }
    if body_en != "" and "[Your name]" not in body_en {
        errors.append("body_en must end with the [Your name] placeholder");
    }

    combined = subject + "\n" + body_en + "\n" + body_zh;
    if re.search(r"https?://", combined) or re.search(r"\S+@\S+\.\S+", combined) {
        errors.append("draft may not contain URLs or email addresses");
    }
    lowered = combined.lower();
    for phrase in FORBIDDEN_PHRASES {
        if phrase in lowered {
            errors.append("forbidden phrase: " + phrase);
        }
    }
    if not has_verified_deadline {
        for month in MONTH_WORDS {
            if month in lowered {
                errors.append(
                    "no verified deadline on file; draft may not name a date ("
                    + month.strip() + ")"
                );
            }
        }
    }
    for run in novel_numbers(combined, source_text) {
        errors.append("number not present in the retrieved payload: " + run);
    }
    return errors;
}


# ---- deterministic fallback ---------------------------------------------------

"""Template assembly of retrieved text only. EN-only: a deterministic
fallback cannot translate, so it says so instead of pretending."""
def deterministic_draft(source: dict) -> dict {
    org = dict_field(source, "recipient_organization");
    ask_lines = "";
    for a in list_field(source, "ask") {
        if isinstance(a, dict) {
            ask_lines = ask_lines + "- " + text_field(a, "what") + "\n";
        }
    }
    deadline_line = (
        "The applicable comment deadline on file is " +
        text_field(source, "verified_deadline") + "."
    ) if text_field(source, "verified_deadline") != "" else (
        "No verified comment deadline is on file; please confirm the window "
        + "with the body directly before submitting."
    );
    signal = dict_field(source, "initial_signal");
    signal_line = (
        "Initial signal already collected for this case: "
        + str(signal.get("testimony_count")) + " sourced statements and "
        + str(signal.get("forum_thread_count")) + " community forum threads ("
        + str(signal.get("forum_comment_total")) + " comments) — attention "
        + "is documented, but none of it is yet a countable submission."
    );
    body = (
        "Dear " + text_field(org, "name") + ",\n\n"
        + first_sentences(text_field(source, "problem"), 2) + "\n\n"
        + signal_line + "\n\n"
        + "The decision rests with " + text_field(source, "who_decides")
        + ". Input that counts arrives as: "
        + text_field(source, "channel_that_counts") + ". "
        + deadline_line + "\n\n"
        + "If your organization holds a position on this, the steps that "
        + "make it count are:\n" + ask_lines + "\n"
        + "A distinct submission in your organization's own words carries "
        + "more weight than any volume of identical messages.\n\n"
        + "[Your name]"
    );
    return {
        "subject": text_field(source, "issue_title")
            + " — putting your organization's position on the record",
        "body_en": body,
        "body_zh": "",
    };
}


# ---- entry point ---------------------------------------------------------------

def generate_draft(payload: dict, org: dict) -> dict {
    source = draft_source(payload, org);
    source_text = json.dumps(source, ensure_ascii=False);
    wants_zh = text_field(org, "language") == "zh";
    has_deadline = text_field(source, "verified_deadline") != "";

    candidate = extract_json(run_claude(draft_prompt(source_text, wants_zh)));
    errors = validate_draft(candidate, source_text, wants_zh, has_deadline);
    if len(errors) > 0 {
        candidate = extract_json(run_claude(draft_prompt(source_text, wants_zh)));
        errors = validate_draft(candidate, source_text, wants_zh, has_deadline);
    }

    if len(errors) == 0 {
        body = {
            "subject": clean_text(candidate.get("subject")),
            "body_en": clean_text(candidate.get("body_en")),
            "body_zh": clean_text(candidate.get("body_zh")),
        };
        origin = "llm";
        model = "claude haiku (CLI, headless)";
    } else {
        body = deterministic_draft(source);
        origin = "deterministic_fallback";
        model = "";
    }

    contact = text_field(org, "contact");
    return {
        "found": True,
        "available": True,
        "slug": text_field(payload, "slug"),
        "org_name": text_field(org, "name"),
        "org_language": text_field(org, "language"),
        "to": contact,
        "to_note": (
            "Org-level contact from the pipeline record."
            if contact != "" else
            "No org-level contact on file — draft staged only."
        ),
        "subject": body["subject"],
        "body_en": body["body_en"],
        "body_zh": body["body_zh"],
        "zh_note": (
            "AI-generated 中文 draft — have a native speaker review before sending."
            if body["body_zh"] != "" else ""
        ),
        "origin": origin,
        "model": model,
        "ai_generated": origin == "llm",
        "generated_at": datetime.now().isoformat()[:19],
        "delivery": "manual_review_and_send",
        "validation_errors": errors,
        "legal_reviewed": False,
    };
}


"""Cache-first from out/drafts/<slug>/<org>.json. Nothing here sends
anything, ever — the artifact on disk IS the output."""
def outreach_draft(payload: dict, org: dict, regenerate: bool) -> dict {
    slug = text_field(payload, "slug");
    org_name = text_field(org, "name");
    if not regenerate {
        cached = load_cached_draft(slug, org_name);
        if len(cached) > 0 {
            return cached;
        }
    }
    draft = generate_draft(payload, org);
    save_draft(slug, org_name, draft);
    return draft;
}
