# ============================================================
# targeting_rules.jac — targeting vocabulary, guardrails, and copy templates.
#
# This module holds the *rules* of the targeting layer. It creates no nodes,
# performs no traversal, and makes no network call. `walkers_campaign.jac`
# owns the graph types and the walker; this file owns the closed vocabularies
# those pieces are allowed to draw from.
#
# Three boundaries are enforced here rather than documented and hoped for:
#
#   * a campaign plan is always dry-run; nothing here can authorize spend;
#   * targeting terms are screened against a sensitive-trait deny list, and
#     political ideology is on it — no ideology is ever inferred or targeted;
#   * organizations are direct-outreach recipients. There is no vocabulary in
#     this file for uploading them, or anyone else, as an ad audience.
#
# Copy templates are deterministic string builders over fields that already
# exist in the graph. They state no fact the caller cannot cite.
# ============================================================

include walkers_recourse;


# ------------------------------------------------------------
# Activation posture. There is no "live" value anywhere in this module.
# ------------------------------------------------------------
glob CAMPAIGN_DRY_RUN_ONLY: bool = True;
glob CAMPAIGN_STATUS_DRY_RUN: str = "dry_run";
glob CAMPAIGN_ORIGIN: str = "deterministic_targeting_rules";

# Social is drafted here but not planned as bought media in this module.
glob SOCIAL_ACTIVATION_STATUS: str = "manual_or_future_platform_activation";
glob CREATIVE_DRAFT_STATUS: str = "dry_run_draft";


# ------------------------------------------------------------
# The four zones. They are distinct on purpose: the product exists because
# they are routinely conflated.
#
#   impact_zone            — who lives with the outcome        (located_in)
#   mobilization_zone      — where an organization on file can
#                            actually reach people             (serves)
#   decision_zone          — the constituency the deciding body
#                            answers to                        (accountable_to)
#   paid_media_target_zone — the part of the decision zone that
#                            no organization on file already covers
# ------------------------------------------------------------
glob CAMPAIGN_ZONE_ROLES: list[str] = [
    "impact_zone",
    "mobilization_zone",
    "decision_zone",
    "paid_media_target_zone",
];


# ------------------------------------------------------------
# Channels. CTV is one featured channel of three, never the whole plan.
# ------------------------------------------------------------
glob CAMPAIGN_CHANNEL_KEYS: list[str] = [
    "programmatic_display",
    "online_video",
    "connected_tv",
];

glob CAMPAIGN_PLATFORM_LABEL: str = "DV360";

glob CHANNEL_PLATFORM: dict[str, str] = {
    "programmatic_display": "DV360",
    "online_video": "DV360",
    "connected_tv": "DV360",
};

# Provider-neutral names. The DV360 enum mapping lives below and is applied
# only when the DV360-shaped dry-run payload is built.
glob CHANNEL_INSERTION_ORDER_TYPE: dict[str, str] = {
    "programmatic_display": "standard",
    "online_video": "standard",
    "connected_tv": "connected_tv",
};

glob CHANNEL_LINE_ITEM_TYPE: dict[str, str] = {
    "programmatic_display": "display",
    "online_video": "video",
    "connected_tv": "connected_tv",
};

glob CHANNEL_FORMATS: dict[str, list[str]] = {
    "programmatic_display": [
        "300x250 medium rectangle (web, mobile web)",
        "728x90 leaderboard (web)",
        "300x600 half page (web)",
        "160x600 wide skyscraper (web)",
        "970x250 billboard (web)",
        "320x50 mobile banner (mobile web, in-app)",
    ],
    "online_video": [
        "in-stream 16:9 1920x1080 mp4 (desktop, tablet)",
        "in-stream 9:16 1080x1920 mp4 (mobile)",
        "out-stream in-feed 16:9 mp4 (mobile, tablet)",
    ],
    "connected_tv": [
        "CTV 16:9 1920x1080 mp4, 15s, non-skippable, 128kbps+ stereo audio",
    ],
};

glob CHANNEL_DEVICES: dict[str, list[str]] = {
    "programmatic_display": ["desktop", "mobile"],
    "online_video": ["desktop", "mobile", "tablet"],
    "connected_tv": ["connected_tv"],
};

# Creative duration by channel. 0 = not a timed asset.
glob CHANNEL_DURATION_SECONDS: dict[str, int] = {
    "programmatic_display": 0,
    "online_video": 30,
    "connected_tv": 15,
};

# Planning split. Not a recommendation to spend; an allocation for a plan
# that is never submitted.
glob CHANNEL_BUDGET_SHARE: dict[str, float] = {
    "programmatic_display": 0.30,
    "online_video": 0.30,
    "connected_tv": 0.40,
};

# Illustrative planning CPMs. These are planning constants, not quotes, not
# a forecast, and not retrieved from any exchange.
glob CHANNEL_ILLUSTRATIVE_CPM_USD: dict[str, float] = {
    "programmatic_display": 6.0,
    "online_video": 18.0,
    "connected_tv": 32.0,
};

# Frequency caps. Civic message, small budget: suppress hard.
glob CHANNEL_FREQUENCY_CAP_IMPRESSIONS: dict[str, int] = {
    "programmatic_display": 3,
    "online_video": 2,
    "connected_tv": 2,
};
glob CHANNEL_FREQUENCY_CAP_TIME_UNIT: dict[str, str] = {
    "programmatic_display": "day",
    "online_video": "day",
    "connected_tv": "week",
};
glob CHANNEL_FREQUENCY_CAP_TIME_COUNT: dict[str, int] = {
    "programmatic_display": 1,
    "online_video": 1,
    "connected_tv": 1,
};

glob CAMPAIGN_PACING: str = "even_daily";


# ------------------------------------------------------------
# DV360 API enum mapping. Applied at payload-build time only.
# ------------------------------------------------------------
glob DV360_API_PRODUCT: str = "Display & Video 360 API";
glob DV360_API_VERSION: str = "v3";

glob DV360_INSERTION_ORDER_TYPE: dict[str, str] = {
    "standard": "RTB",
    "connected_tv": "OVER_THE_TOP",
};

glob DV360_LINE_ITEM_TYPE: dict[str, str] = {
    "display": "LINE_ITEM_TYPE_DISPLAY_DEFAULT",
    "video": "LINE_ITEM_TYPE_VIDEO_DEFAULT",
    "connected_tv": "LINE_ITEM_TYPE_VIDEO_OVER_THE_TOP",
};

glob DV360_DEVICE_TYPE: dict[str, str] = {
    "desktop": "DEVICE_TYPE_COMPUTER",
    "mobile": "DEVICE_TYPE_SMARTPHONE",
    "tablet": "DEVICE_TYPE_TABLET",
    "connected_tv": "DEVICE_TYPE_CONNECTED_TV",
};

glob DV360_TIME_UNIT: dict[str, str] = {
    "day": "TIME_UNIT_DAYS",
    "week": "TIME_UNIT_WEEKS",
    "month": "TIME_UNIT_MONTHS",
};

glob DV360_DRAFT_ENTITY_STATUS: str = "ENTITY_STATUS_DRAFT";

# No advertiser is named, because none is authenticated.
glob DV360_UNRESOLVED_ADVERTISER: str = "";


# ------------------------------------------------------------
# Sensitive-trait deny list.
#
# Substring match against every proposed targeting term. Political ideology
# and party are on the list: this system does not infer what anyone believes
# from where they live, and will not buy against a guess.
# ------------------------------------------------------------
glob SENSITIVE_TARGETING_TERMS: list[str] = [
    "race", "racial", "ethnic", "national origin", "ancestry",
    "religio", "faith-based", "congregation",
    "health", "medical", "disab", "pregnan", "addiction", "substance abuse",
    "sexual orientation", "gender identity", "lgbt", "transgender",
    "immigra", "undocumented", "citizenship status", "asylum",
    "criminal", "arrest record",
    "union member", "trade union",
    "political affiliation", "political ideology", "political party",
    "partisan", "party registration", "voter file", "voter registration",
    "democrat", "republican", "left-leaning", "right-leaning",
    "household income", "credit score", "net worth", "financial hardship",
    "biometric", "genetic", "precise geolocation", "device graph",
];

# Neighborhood-level geo can act as a proxy for a protected trait even when
# no trait is named. That is a finding to surface, not a silent block.
glob GEO_PROXY_REVIEW_KINDS: list[str] = ["neighborhood"];


# ------------------------------------------------------------
# Copy limits. Over-length copy is reported, never silently truncated —
# a machine-clipped civic message is worse than an editor's note.
# ------------------------------------------------------------
glob COPY_LIMIT_DISPLAY_HEADLINE: int = 90;
glob COPY_LIMIT_DISPLAY_BODY: int = 220;
glob COPY_LIMIT_SOCIAL_POST: int = 280;
glob CTV_SCRIPT_MAX_WORDS: int = 45;


# ------------------------------------------------------------
# Operator-supplied values this module refuses to invent.
# ------------------------------------------------------------
glob DESTINATION_PLACEHOLDER: str =
    "[LANDING PAGE: operator-supplied destination required]";
glob PAID_FOR_BY_PLACEHOLDER: str =
    "[PAID FOR BY: operator disclosure required before any activation]";
glob DATE_PLACEHOLDER: str = "[DATE: operator-supplied flight date required]";

glob CAMPAIGN_STANDING_DISCLOSURE: str = (
    "Dry-run plan only. No media was bought, no platform was authenticated, "
    "and no legal standard is asserted to be satisfied."
);


# ------------------------------------------------------------
# Screening helpers.
# ------------------------------------------------------------
def sensitive_targeting_hits(terms: list[str]) -> list[str] {
    hits: list[str] = [];
    for term in terms {
        lowered = term.strip().lower();
        for banned in SENSITIVE_TARGETING_TERMS {
            if banned in lowered {
                finding = term + " ~ '" + banned + "'";
                if finding not in hits {
                    hits.append(finding);
                }
            }
        }
    }
    return hits;
}


def geo_proxy_review_names(names: list[str], kinds: list[str]) -> list[str] {
    flagged: list[str] = [];
    index = 0;
    for name in names {
        kind = kinds[index] if index < len(kinds) else "";
        if kind in GEO_PROXY_REVIEW_KINDS and name not in flagged {
            flagged.append(name);
        }
        index += 1;
    }
    return flagged;
}


def copy_length_finding(label: str, text: str, limit: int) -> str {
    if len(text) <= limit {
        return "";
    }
    return (
        label + " runs " + str(len(text)) + " characters against a "
        + str(limit) + "-character limit; an editor must cut it rather than "
        + "the system truncating a civic message mid-sentence."
    );
}


def word_count(text: str) -> int {
    words = 0;
    for chunk in text.split() {
        if len(chunk.strip()) > 0 {
            words += 1;
        }
    }
    return words;
}


def join_names(names: list[str], fallback: str) -> str {
    if len(names) == 0 {
        return fallback;
    }
    return ", ".join(names);
}


# ------------------------------------------------------------
# Copy context. Every field is read off the graph by the walker; nothing in
# here is inferred, and nothing here is a legal or outcome claim.
# ------------------------------------------------------------
obj CampaignCopyContext {
    has project_name: str;
    has location: str;
    has category: str;
    has body_name: str;
    has impact_label: str;
    has mobilization_label: str;
    has decision_label: str;
    has paid_label: str;
    has diverged: bool = False;
    has has_verified_channel: bool = False;
    has channel_recipient: str = "";
    has channel_method: str = "";
    has deadline_kind: str = "";
    has deadline_date: str = "";
    has destination: str = "";
    has action_title: str = "";
}


def context_deadline_sentence(context: CampaignCopyContext) -> str {
    if not context.has_verified_channel {
        return (
            "No comment deadline for this decision is on file in this record; "
            + "confirm it at the deciding body's own published notice."
        );
    }
    if len(context.deadline_date) == 0 or context.deadline_date == "unknown" {
        return (
            "A " + context.deadline_kind + " channel is on file, but its "
            + "deadline is recorded as unknown; confirm the date at the cited "
            + "source."
        );
    }
    return (
        "The " + context.deadline_kind + " deadline on file is "
        + context.deadline_date + "."
    );
}


def context_route_sentence(context: CampaignCopyContext) -> str {
    if context.has_verified_channel {
        return (
            "Comments go to " + context.channel_recipient + " by "
            + context.channel_method + "."
        );
    }
    return (
        "No official comment channel for " + context.body_name
        + " is on file here — get the route from that body's own notice "
        + "before you send anything."
    );
}


def context_zone_sentence(context: CampaignCopyContext) -> str {
    if context.diverged {
        return (
            "Impact zone: " + context.impact_label + ". Decision zone: "
            + context.decision_label
            + ". They do not overlap, so volume from the impact zone alone "
            + "never reaches the people who decide."
        );
    }
    return (
        "Impact zone: " + context.impact_label + ". Decision zone: "
        + context.decision_label
        + ". The zones overlap; the gap is the channel, not the audience."
    );
}


# ------------------------------------------------------------
# Display copy.
# ------------------------------------------------------------
def display_headlines(context: CampaignCopyContext) -> list[str] {
    if context.has_verified_channel {
        return [
            "Comment on " + context.project_name + " before it is decided",
            context.impact_label + " lives with it. "
            + context.decision_label + " decides it.",
            "Send " + context.body_name + " a comment that gets counted",
        ];
    }
    return [
        context.project_name + ": find the official comment channel",
        context.impact_label + " lives with it. "
        + context.decision_label + " decides it.",
        "Put your objection on the record before " + context.body_name
        + " decides",
    ];
}


def display_body_copy(context: CampaignCopyContext) -> list[str] {
    return [
        context.project_name + " (" + context.location + ") is decided by "
        + context.body_name + ". " + context_route_sentence(context) + " "
        + context_deadline_sentence(context),
        context_zone_sentence(context)
        + " A recorded, dated comment is the countable one.",
    ];
}


# ------------------------------------------------------------
# Online video (desktop, mobile, tablet) — 30s, scene-marked.
# ------------------------------------------------------------
def online_video_script(context: CampaignCopyContext) -> str {
    lines: list[str] = [
        "FORMAT: 30s online video (in-stream and out-stream; desktop, "
        + "mobile, tablet). Captions burned in. No music bed required.",
        "",
        "[0:00-0:05] SUPER: " + context.project_name,
        "VO: \"" + context.project_name + ", at " + context.location + ".\"",
        "",
        "[0:05-0:13] SUPER: Impact zone — " + context.impact_label,
        "VO: \"" + context.impact_label + " lives with this decision.\"",
        "",
        "[0:13-0:21] SUPER: Decision zone — " + context.decision_label,
        "VO: \"" + context.body_name + " decides it, answering to "
        + context.decision_label + ".\"",
        "",
        "[0:21-0:30] SUPER: " + context.destination,
        "VO: \"" + context_route_sentence(context) + " "
        + context_deadline_sentence(context) + "\"",
        "",
        "END CARD: " + PAID_FOR_BY_PLACEHOLDER,
    ];
    return "\n".join(lines);
}


# ------------------------------------------------------------
# Connected TV — 15s, non-skippable, no click. The end card and the QR are
# the only response mechanism, so the destination has to survive being read
# off a television across a room.
# ------------------------------------------------------------
def ctv_script_15s(context: CampaignCopyContext) -> str {
    lines: list[str] = [
        "FORMAT: 15s CTV, 1920x1080 16:9 mp4, non-skippable, no clickthrough. "
        + "Legible at 10 feet; open captions; audio-off comprehension "
        + "required.",
        "",
        "[0:00-0:04] SUPER: " + context.project_name,
        "VO: \"" + context.project_name + " is being decided now.\"",
        "",
        "[0:04-0:09] SUPER: " + context.impact_label + "  /  "
        + context.decision_label,
        "VO: \"" + context.impact_label + " lives with it. "
        + context.decision_label + " decides it.\"",
        "",
        "[0:09-0:15] SUPER + QR: " + context.destination,
        "VO: \"Put your objection on the record.\"",
        "",
        "END CARD (held 3s, QR persistent): " + PAID_FOR_BY_PLACEHOLDER,
    ];
    return "\n".join(lines);
}


def ctv_spoken_words(context: CampaignCopyContext) -> int {
    spoken = (
        context.project_name + " is being decided now. "
        + context.impact_label + " lives with it. "
        + context.decision_label + " decides it. "
        + "Put your objection on the record."
    );
    return word_count(spoken);
}


# ------------------------------------------------------------
# Social — drafted, never activated from this module.
# ------------------------------------------------------------
def social_copy(context: CampaignCopyContext) -> list[str] {
    return [
        context.project_name + " is decided by " + context.body_name + ". "
        + context_zone_sentence(context) + " " + context.destination,
        context_route_sentence(context) + " "
        + context_deadline_sentence(context) + " " + context.destination,
    ];
}


# ------------------------------------------------------------
# Organization outreach. Named, direct, one-to-one — the opposite of an
# uploaded audience segment. The copy never asserts the organization agrees.
# ------------------------------------------------------------
def organization_outreach_copy(
    context: CampaignCopyContext,
    organization_name: str,
    community: str,
    zones_label: str,
    inside_process: bool,
) -> str {
    standing: str = (
        "Your organization is recorded as inside the official process for "
        + "this decision."
        if inside_process
        else "Your organization is not recorded as inside the official "
        + "process for this decision; that is a gap in the record, not a "
        + "statement about your position."
    );
    community_line: str = (
        "You are on file as serving " + community + " in " + zones_label + "."
        if len(community) > 0
        else "You are on file as serving " + zones_label + "."
    );
    return "\n".join([
        "To: " + organization_name,
        "Re: " + context.project_name,
        "",
        community_line + " " + standing,
        "",
        context.project_name + " (" + context.location + ") is decided by "
        + context.body_name + ". " + context_zone_sentence(context),
        "",
        context_route_sentence(context) + " "
        + context_deadline_sentence(context),
        "",
        "Ask: file your own recorded submission rather than signing a shared "
        + "letter — separate submissions are counted separately.",
        "",
        "We are not asking you to endorse a position, and we have not "
        + "represented you as holding one. " + CAMPAIGN_STANDING_DISCLOSURE,
    ]);
}
