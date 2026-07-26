# ============================================================
# walkers_evidence.jac — EvidenceMatcher.
#
# Proposes POTENTIALLY_RELEVANT_TO relationships between narrative
# evidence and the institutional/procedural/legal record.
#
# Hard boundaries enforced here:
#   * the only relationship archetype this module can write is
#     `potentially_relevant_to`;
#   * no `satisfies` and no `proves` archetype exists in this workspace,
#     and `forbidden_relation_names()` proves it at runtime;
#   * every proposal is model-proposed and therefore `unreviewed`;
#   * fixture source IDs are copied onto the relationship, never re-minted.
#
# Nothing in this file performs network access.
# ============================================================

include walkers;
include fixture_adapter;


# Relationship names this workspace refuses to materialize. A claim that a
# legal standard is satisfied or proven is a human legal conclusion.
glob FORBIDDEN_RELATION_NAMES: list[str] = ["satisfies", "proves"];

glob EVIDENCE_STOPWORDS: list[str] = [
    "the", "and", "for", "that", "this", "with", "from", "have", "has",
    "was", "were", "are", "not", "but", "you", "our", "its", "their",
    "his", "her", "they", "them", "there", "than", "then", "into", "onto",
    "about", "would", "could", "should", "will", "shall", "may", "might",
    "been", "being", "who", "whom", "what", "when", "where", "which",
    "while", "also", "more", "most", "such", "some", "any", "all", "each",
    "other", "over", "under", "out", "off", "per", "via", "san",
    "francisco", "city", "citywide", "public", "please", "email", "mail",
    "form", "note", "notes", "comment", "comments", "submit", "submitted",
    "address", "addressed", "directed", "concerning", "regarding",
    "should", "must", "item", "number", "reference", "department",
];

# Language codes carried by fixture Testimony mapped to the tokens that a
# CommentChannel actually publishes. Curated alias table, not a translation.
glob EVIDENCE_LANGUAGE_ALIASES: dict[str, list[str]] = {
    "en": ["english"],
    "zh": ["chinese", "cantonese", "mandarin", "繁體中文", "简体中文", "中文"],
    "es": ["spanish", "espanol", "español"],
    "tl": ["filipino", "tagalog"],
    "vi": ["vietnamese", "tiếng", "việt"],
};

# Default process language. A language match is only informative when the
# speaker is outside it: every channel here lists English, so an English
# match would link everything to everything and say nothing.
glob EVIDENCE_DEFAULT_LANGUAGE: str = "en";

# A shared term counts as distinctive when it appears in at most this many
# target profiles. Distinctiveness, not raw overlap, gates a proposal.
glob EVIDENCE_DISTINCTIVE_DF: int = 2;
glob EVIDENCE_MIN_TOKEN_LEN: int = 3;
glob EVIDENCE_MAX_CONFIDENCE: float = 0.75;


# ------------------------------------------------------------
# Claim — additive companion type.
#
# The frozen schema carries a claim as `Testimony.claim` text and the
# current fixture contract emits no standalone claim record. This archetype
# exists so an extracted claim can be traversed by the same matcher without
# editing the frozen schema. EvidenceMatcher never creates one; it only
# reads whatever is already in the graph.
# ------------------------------------------------------------
node Claim {
    has claim_id: str;
    has text: str;
    has source_id: str = "";
    has source_url: str = "";
    has extracted_from: str = "";
}


# Node types this matcher reads on each side of a proposal.
obj EvidenceTargetProfile {
    has target: LegalStandard | DecisionBody | CommentChannel;
    has target_id: str;
    has kind: str;
    has tokens: list[str] = [];
    has language_tokens: list[str] = [];
    has source_url: str = "";
}


# ------------------------------------------------------------
# The one relationship this module may write.
#
# "Potentially relevant" means: a human should look at this pair. It is not
# support, not sufficiency, not satisfaction of any standard.
# ------------------------------------------------------------
edge potentially_relevant_to {
    has relation_id: str;
    has source_id: str;
    has target_id: str;
    has source_type: str;
    has target_type: str;
    has basis: str = "term_overlap";
    has shared_terms: list[str] = [];
    has rationale: str = "";
    has confidence: float = 0.0;
    has model_proposed: bool = True;
    has review_status: str = "unreviewed";
    has reviewed_by: str = "";
    has source_url: str = "";
    has target_source_url: str = "";
}


# ------------------------------------------------------------
# Identity helpers — source IDs are preserved, never regenerated.
# ------------------------------------------------------------
def evidence_source_id(item: any) -> str {
    for record in [
        candidate for candidate in [root -->]
        if isinstance(candidate, FixtureRecord)
    ] {
        if record.node_jid == str(jid(item)) {
            return record.fixture_id;
        }
    }
    if isinstance(item, Claim) {
        return item.claim_id;
    }
    return "jid:" + str(jid(item));
}


def evidence_source_exists(source_id: str) -> bool {
    if find_fixture_record(source_id) is not None {
        return True;
    }
    for claim in [item for item in [root -->] if isinstance(item, Claim)] {
        if claim.claim_id == source_id {
            return True;
        }
    }
    if source_id.startswith("jid:") {
        return jobj(source_id[4:]) is not None;
    }
    return False;
}


def evidence_source_url(item: any) -> str {
    if isinstance(item, Testimony) { return item.source_url; }
    if isinstance(item, Claim) { return item.source_url; }
    if isinstance(item, CommentChannel) { return item.source_url; }
    if isinstance(item, LegalStandard) { return item.source_url; }
    return "";
}


# ------------------------------------------------------------
# Deterministic lexical profile.
# ------------------------------------------------------------
def evidence_tokens(text: str) -> list[str] {
    tokens: list[str] = [];
    buffer = "";
    for character in text.lower() {
        if character.isalnum() {
            buffer += character;
        } else {
            if len(buffer) >= EVIDENCE_MIN_TOKEN_LEN and buffer not in tokens {
                if buffer not in EVIDENCE_STOPWORDS {
                    tokens.append(buffer);
                }
            }
            buffer = "";
        }
    }
    if len(buffer) >= EVIDENCE_MIN_TOKEN_LEN and buffer not in tokens {
        if buffer not in EVIDENCE_STOPWORDS {
            tokens.append(buffer);
        }
    }
    return tokens;
}


def evidence_profile_text(item: any) -> str {
    if isinstance(item, Testimony) {
        return item.claim;
    }
    if isinstance(item, Claim) {
        return item.text;
    }
    if isinstance(item, LegalStandard) {
        return item.name + " " + item.authority + " " + item.test;
    }
    if isinstance(item, DecisionBody) {
        return item.name + " " + item.kind + " " + item.jurisdiction;
    }
    if isinstance(item, CommentChannel) {
        return item.recipient + " " + item.format_note;
    }
    return "";
}


def evidence_language_tokens(language: str) -> list[str] {
    key = language.strip().lower();
    if key in EVIDENCE_LANGUAGE_ALIASES {
        return EVIDENCE_LANGUAGE_ALIASES[key];
    }
    return [key];
}


def evidence_relation_id(source_id: str, target_id: str) -> str {
    return "potentially-relevant:" + source_id + "->" + target_id;
}


def evidence_relation_exists(origin: any, relation_id: str) -> bool {
    for link in [edge origin ->: potentially_relevant_to :->] {
        if link.relation_id == relation_id {
            return True;
        }
    }
    return False;
}


# ------------------------------------------------------------
# Runtime guard: prove that no forbidden relationship archetype was ever
# materialized anywhere reachable from root.
# ------------------------------------------------------------
def relation_names_in_graph() -> list[str] {
    names: list[str] = [];
    visited: list[str] = [];
    frontier: list[any] = [root];
    while len(frontier) > 0 {
        current = frontier.pop();
        current_jid = str(jid(current));
        if current_jid in visited {
            continue;
        }
        visited.append(current_jid);
        for link in [edge current -->] {
            link_name = type(link).__name__;
            if link_name not in names {
                names.append(link_name);
            }
        }
        for neighbor in [current -->] {
            frontier.append(neighbor);
        }
    }
    return sorted(names);
}


def forbidden_relation_names() -> list[str] {
    found: list[str] = [];
    for link_name in relation_names_in_graph() {
        if link_name.lower() in FORBIDDEN_RELATION_NAMES {
            found.append(link_name);
        }
    }
    return found;
}


# ------------------------------------------------------------
# Frontend projection of the proposed relationships.
# ------------------------------------------------------------
def evidence_link_views() -> list[dict[str, any]] {
    views: list[dict[str, any]] = [];
    visited: list[str] = [];
    frontier: list[any] = [root];
    while len(frontier) > 0 {
        current = frontier.pop();
        current_jid = str(jid(current));
        if current_jid in visited {
            continue;
        }
        visited.append(current_jid);
        for link in [edge current ->: potentially_relevant_to :->] {
            views.append({
                "id": link.relation_id,
                "type": "potentially_relevant_to",
                "source": link.source_id,
                "target": link.target_id,
                "source_type": link.source_type,
                "target_type": link.target_type,
                "basis": link.basis,
                "shared_terms": link.shared_terms,
                "rationale": link.rationale,
                "confidence": link.confidence,
                "model_proposed": link.model_proposed,
                "review_status": link.review_status,
                "reviewed_by": link.reviewed_by,
                "source_url": link.source_url,
                "target_source_url": link.target_source_url,
            });
        }
        for neighbor in [current -->] {
            frontier.append(neighbor);
        }
    }
    return sorted(views, key=lambda view: any : str(view["id"]));
}


# ------------------------------------------------------------
# EvidenceMatcher
#
# Phase 1 (entry abilities): traverse the fixture-ingested graph and
#   collect Testimony, Claim, LegalStandard, DecisionBody, CommentChannel.
# Phase 2 (Root exit): score pairs and write `potentially_relevant_to`.
# ------------------------------------------------------------
walker EvidenceMatcher {
    has evidence_nodes: list[Testimony | Claim] = [];
    has target_nodes: list[
        LegalStandard | DecisionBody | CommentChannel
    ] = [];
    has seen_jids: list[str] = [];
    has scanned: dict[str, int] = {
        "Testimony": 0,
        "Claim": 0,
        "LegalStandard": 0,
        "DecisionBody": 0,
        "CommentChannel": 0,
    };
    has proposed: int = 0;
    has reused: int = 0;
    has skipped: int = 0;
    has links: list[dict[str, any]] = [];
    has notes: list[str] = [];

    def remember(
        item: Testimony | Claim | LegalStandard | DecisionBody | CommentChannel,
        bucket: str,
    ) -> bool {
        item_jid = str(jid(item));
        if item_jid in self.seen_jids {
            return False;
        }
        self.seen_jids.append(item_jid);
        self.scanned[bucket] += 1;
        return True;
    }

    can start with Root entry {
        visit [here -->];
    }

    can descend_record with FixtureRecord entry {
        visit [here ->: materializes :->];
    }

    can descend_layer with LayerAnchor entry {
        visit [here ->: in_semantic_layer :->];
    }

    can gather_testimony with Testimony entry {
        if self.remember(here, "Testimony") {
            self.evidence_nodes.append(here);
        }
    }

    can gather_claim with Claim entry {
        if self.remember(here, "Claim") {
            self.evidence_nodes.append(here);
        }
    }

    can gather_standard with LegalStandard entry {
        if self.remember(here, "LegalStandard") {
            self.target_nodes.append(here);
        }
    }

    can gather_body with DecisionBody entry {
        if self.remember(here, "DecisionBody") {
            self.target_nodes.append(here);
        }
    }

    can gather_channel with CommentChannel entry {
        if self.remember(here, "CommentChannel") {
            self.target_nodes.append(here);
        }
    }

    can propose_links with Root exit {
        target_profiles: list[EvidenceTargetProfile] = [];
        for target in self.target_nodes {
            target_id = evidence_source_id(target);
            if not evidence_source_exists(target_id) {
                self.skipped += 1;
                self.notes.append(
                    "Skipped target with unresolvable source ID: " + target_id
                );
                continue;
            }
            languages = "";
            if isinstance(target, CommentChannel) {
                languages = target.languages;
            }
            target_profiles.append(EvidenceTargetProfile(
                target=target,
                target_id=target_id,
                kind=type(target).__name__,
                tokens=evidence_tokens(evidence_profile_text(target)),
                language_tokens=evidence_tokens(languages),
                source_url=evidence_source_url(target),
            ));
        }

        document_frequency: dict[str, int] = {};
        for profile in target_profiles {
            for token in profile.tokens {
                document_frequency[token] = (
                    document_frequency.get(token, 0) + 1
                );
            }
        }

        for evidence in self.evidence_nodes {
            evidence_id = evidence_source_id(evidence);
            if not evidence_source_exists(evidence_id) {
                self.skipped += 1;
                self.notes.append(
                    "Skipped evidence with unresolvable source ID: "
                    + evidence_id
                );
                continue;
            }
            evidence_tokens_list = evidence_tokens(
                evidence_profile_text(evidence)
            );
            language = "en";
            if isinstance(evidence, Testimony) {
                language = evidence.language;
            }
            language_tokens = evidence_language_tokens(language);

            for profile in target_profiles {
                shared: list[str] = [];
                distinctive: list[str] = [];
                for token in evidence_tokens_list {
                    if token in profile.tokens {
                        shared.append(token);
                        if (
                            document_frequency.get(token, 0)
                            <= EVIDENCE_DISTINCTIVE_DF
                        ) {
                            distinctive.append(token);
                        }
                    }
                }

                language_match: list[str] = [];
                if (
                    profile.kind == "CommentChannel"
                    and language.strip().lower() != EVIDENCE_DEFAULT_LANGUAGE
                ) {
                    for alias in language_tokens {
                        if alias in profile.language_tokens {
                            language_match.append(alias);
                        }
                    }
                }

                if len(distinctive) == 0 and len(language_match) == 0 {
                    continue;
                }

                bases: list[str] = [];
                reasons: list[str] = [];
                if len(distinctive) > 0 {
                    bases.append("term_overlap");
                    reasons.append(
                        "Shares distinctive terms with the "
                        + profile.kind + " record: "
                        + ", ".join(sorted(distinctive))
                    );
                }
                if len(language_match) > 0 {
                    bases.append("language_access");
                    reasons.append(
                        "Speaker's language (" + language
                        + ") is listed by this comment channel"
                    );
                }

                raw_confidence: float = (
                    0.2 * len(distinctive)
                    + 0.05 * len(shared)
                    + 0.15 * len(language_match)
                );
                confidence: float = raw_confidence;
                if confidence > EVIDENCE_MAX_CONFIDENCE {
                    confidence = EVIDENCE_MAX_CONFIDENCE;
                }

                relation_id = evidence_relation_id(
                    evidence_id, profile.target_id
                );
                if evidence_relation_exists(evidence, relation_id) {
                    self.reused += 1;
                    continue;
                }

                evidence +>: potentially_relevant_to(
                    relation_id=relation_id,
                    source_id=evidence_id,
                    target_id=profile.target_id,
                    source_type=type(evidence).__name__,
                    target_type=profile.kind,
                    basis="+".join(bases),
                    shared_terms=sorted(shared),
                    rationale=(
                        "; ".join(reasons)
                        + ". Model-proposed and unreviewed: relevance only, "
                        + "no legal standard is asserted to be met."
                    ),
                    confidence=confidence,
                    model_proposed=True,
                    review_status="unreviewed",
                    source_url=evidence_source_url(evidence),
                    target_source_url=profile.source_url,
                ) :+> profile.target;
                self.proposed += 1;
                self.links.append({
                    "id": relation_id,
                    "source": evidence_id,
                    "target": profile.target_id,
                    "basis": "+".join(bases),
                    "confidence": confidence,
                    "review_status": "unreviewed",
                });
            }
        }

        self.links = sorted(
            self.links, key=lambda link: any : str(link["id"])
        );
    }
}
