# ============================================================
# walkers_recourse.jac — RecommendRecourse.
#
# Reuses the existing walkers rather than re-deriving their answers:
#   DecisionWalker   -> procedural playbook and procedural gaps
#   ImpactWalker     -> affected orgs, and which were left outside
#   DivergenceCheck  -> impact zone vs decision zone
#   PrecedentMatcher -> comparable cases, with claimability preserved
#
# It returns exactly three ActionPath nodes. Every path is anchored to
# source node IDs that already exist in the graph, carries exactly three
# first steps, a complexity, a binding effect, at least one uncertainty,
# and `legal_reviewed = False`.
#
# A model may propose the three paths. If the proposal fails validation for
# any reason, the deterministic fallback below produces them instead. No
# network access happens in this module in either case.
# ============================================================

include walkers_evidence;


glob RECOURSE_PATH_COUNT: int = 3;
glob RECOURSE_FIRST_STEP_COUNT: int = 3;
glob RECOURSE_COMPLEXITY_VALUES: list[str] = ["low", "moderate", "high"];

# Closed vocabulary. "binding_if_qualified" never asserts that the
# qualification is met — that is a legal conclusion this system will not draw.
glob RECOURSE_BINDING_EFFECTS: list[str] = [
    "advisory",
    "procedural",
    "binding_if_qualified",
];

glob RECOURSE_SLOT_KEYS: list[str] = [
    "recorded_comment",
    "decision_zone_contact",
    "escalation",
];

# Attached to every path, fallback or model-proposed.
glob RECOURSE_STANDING_UNCERTAINTY: str = (
    "Not legal advice and not reviewed by counsel (legal_reviewed=false); "
    "no legal standard is asserted to be satisfied."
);


# ------------------------------------------------------------
# ActionPath — additive campaign-activation type.
# ------------------------------------------------------------
node ActionPath {
    has path_id: str;
    has slot_key: str;
    has project_id: str;
    has title: str;
    has summary: str;
    has target: str;
    has complexity: str;
    has binding_effect: str;
    has binding_note: str;
    has first_steps: list[str] = [];
    has uncertainties: list[str] = [];
    has source_ids: list[str] = [];
    has source_urls: list[str] = [];
    has legal_reviewed: bool = False;
    has origin: str = "deterministic_fallback";
    has layer_key: str = "campaign_activation";
}


edge has_action_path {
    has path_id: str;
    has slot_key: str;
}


# Validated, source-checked description of one path, before it is
# materialized. Model proposals and the fallback both converge on this.
obj RecoursePathSpec {
    has slot_key: str;
    has title: str;
    has summary: str;
    has target: str;
    has complexity: str;
    has binding_effect: str;
    has binding_note: str;
    has first_steps: list[str] = [];
    has uncertainties: list[str] = [];
    has source_ids: list[str] = [];
}


# ------------------------------------------------------------
# Source-ID plumbing. A path may only cite nodes that already exist.
# ------------------------------------------------------------
def recourse_source_ref(item: any) -> str {
    if isinstance(item, ProcedureGap) {
        return item.gap_id;
    }
    return evidence_source_id(item);
}


def recourse_source_exists(source_id: str) -> bool {
    if find_procedure_gap(source_id) is not None {
        return True;
    }
    return evidence_source_exists(source_id);
}


def recourse_known_source_ids(source_ids: list[str]) -> list[str] {
    known: list[str] = [];
    for source_id in source_ids {
        if source_id not in known and recourse_source_exists(source_id) {
            known.append(source_id);
        }
    }
    return known;
}


def recourse_source_urls(source_ids: list[str]) -> list[str] {
    urls: list[str] = [];
    for source_id in source_ids {
        record = find_fixture_record(source_id);
        if record is not None and len(record.source_url) > 0 {
            if record.source_url not in urls {
                urls.append(record.source_url);
            }
            continue;
        }
        gap = find_procedure_gap(source_id);
        if gap is not None and len(gap.source_url) > 0 {
            if gap.source_url not in urls {
                urls.append(gap.source_url);
            }
        }
    }
    return urls;
}


# ------------------------------------------------------------
# The existing walkers report untyped lists of untyped dicts, and model
# output is untrusted JSON. These helpers read both without pretending
# either was typed.
# ------------------------------------------------------------
def recourse_any_text(value: any) -> str {
    if isinstance(value, str) {
        return value;
    }
    if isinstance(value, int) {
        return str(value);
    }
    if isinstance(value, float) {
        return str(value);
    }
    return "";
}


def recourse_entry_text(record: any, field_name: str) -> str {
    if isinstance(record, dict) {
        return recourse_any_text(record.get(field_name));
    }
    return "";
}


def recourse_string_list(value: any) -> list[str] {
    items: list[str] = [];
    if not isinstance(value, list) {
        return items;
    }
    for item in value {
        if isinstance(item, str) and len(item.strip()) > 0 {
            items.append(item.strip());
        }
    }
    return items;
}


# ------------------------------------------------------------
# Validation of a model-proposed path. Any error sends the whole set to
# the deterministic fallback: three good paths beat two good and one bad.
# ------------------------------------------------------------
def validate_recourse_proposal(
    proposal: any,
    slot: int,
) -> list[str] {
    errors: list[str] = [];
    label = "proposal[" + str(slot) + "]";
    if not isinstance(proposal, dict) {
        errors.append(label + " is not an object");
        return errors;
    }

    for field_name in ["title", "summary", "target", "binding_note"] {
        value = proposal.get(field_name);
        if not isinstance(value, str) or len(value.strip()) == 0 {
            errors.append(label + "." + field_name + " must be a nonblank string");
        }
    }

    complexity = proposal.get("complexity");
    if complexity not in RECOURSE_COMPLEXITY_VALUES {
        errors.append(
            label + ".complexity must be one of "
            + ", ".join(RECOURSE_COMPLEXITY_VALUES)
        );
    }

    binding_effect = proposal.get("binding_effect");
    if binding_effect not in RECOURSE_BINDING_EFFECTS {
        errors.append(
            label + ".binding_effect must be one of "
            + ", ".join(RECOURSE_BINDING_EFFECTS)
        );
    }

    first_steps = recourse_string_list(proposal.get("first_steps"));
    if len(first_steps) != RECOURSE_FIRST_STEP_COUNT {
        errors.append(
            label + ".first_steps must hold exactly "
            + str(RECOURSE_FIRST_STEP_COUNT) + " nonblank steps"
        );
    }

    if len(recourse_string_list(proposal.get("uncertainties"))) == 0 {
        errors.append(label + ".uncertainties must hold at least one entry");
    }

    source_ids = recourse_string_list(proposal.get("source_ids"));
    if len(source_ids) == 0 {
        errors.append(label + ".source_ids must cite at least one source node");
    }
    for source_id in source_ids {
        if not recourse_source_exists(source_id) {
            errors.append(
                label + ".source_ids cites an ID that is not in the graph: "
                + source_id
            );
        }
    }

    if proposal.get("legal_reviewed") is True {
        errors.append(
            label + ".legal_reviewed cannot be asserted by a model"
        );
    }
    return errors;
}


def validate_recourse_proposals(proposals: list[dict[str, any]]) -> list[str] {
    errors: list[str] = [];
    if len(proposals) != RECOURSE_PATH_COUNT {
        errors.append(
            "expected exactly " + str(RECOURSE_PATH_COUNT)
            + " proposals, received " + str(len(proposals))
        );
        return errors;
    }
    slot = 0;
    for proposal in proposals {
        for message in validate_recourse_proposal(proposal, slot) {
            errors.append(message);
        }
        slot += 1;
    }
    return errors;
}


def recourse_text(proposal: dict[str, any], field_name: str) -> str {
    value = proposal.get(field_name);
    if isinstance(value, str) {
        return value.strip();
    }
    return "";
}


def normalize_recourse_proposal(
    proposal: dict[str, any],
    slot: int,
) -> RecoursePathSpec {
    uncertainties = recourse_string_list(proposal.get("uncertainties"));
    if RECOURSE_STANDING_UNCERTAINTY not in uncertainties {
        uncertainties.append(RECOURSE_STANDING_UNCERTAINTY);
    }
    return RecoursePathSpec(
        slot_key=RECOURSE_SLOT_KEYS[slot],
        title=recourse_text(proposal, "title"),
        summary=recourse_text(proposal, "summary"),
        target=recourse_text(proposal, "target"),
        complexity=recourse_text(proposal, "complexity"),
        binding_effect=recourse_text(proposal, "binding_effect"),
        binding_note=recourse_text(proposal, "binding_note"),
        first_steps=recourse_string_list(proposal.get("first_steps")),
        uncertainties=uncertainties,
        source_ids=recourse_known_source_ids(
            recourse_string_list(proposal.get("source_ids"))
        ),
    );
}


# ------------------------------------------------------------
# Deterministic fallback — built only from what the graph already holds.
# ------------------------------------------------------------
def recorded_comment_spec(
    project: Project,
    project_id: str,
    decision: DecisionWalker,
    gap_ids: list[str],
) -> RecoursePathSpec {
    bodies: list[DecisionBody] = [
        body for body in [project ->: decided_by :->]
        if isinstance(body, DecisionBody)
    ];
    body_name: str = (
        bodies[0].name if len(bodies) > 0 else "the deciding body"
    );
    source_ids: list[str] = [project_id];
    for body in bodies {
        source_ids.append(recourse_source_ref(body));
    }

    uncertainties: list[str] = [];
    steps: list[str] = [];
    complexity: str = "moderate";
    if len(decision.playbook) > 0 {
        first_entry = decision.playbook[0];
        recipient: str = recourse_entry_text(first_entry, "recipient");
        method: str = recourse_entry_text(first_entry, "method");
        deadline_kind: str = recourse_entry_text(first_entry, "deadline_kind");
        deadline_date: str = recourse_entry_text(first_entry, "date");
        complexity = "low";
        steps = [
            "Address the comment to " + recipient + " by " + method
            + ", citing the project record.",
            "State the objection in one paragraph, name the affected zone, "
            + "and attach the cited source for each factual claim.",
            "Send before the " + deadline_kind + " deadline ("
            + deadline_date + ") and keep the confirmation as the record.",
        ];
        if deadline_date == "unknown" {
            uncertainties.append(
                "The deadline on file for " + recipient
                + " is recorded as 'unknown'; confirm it at the cited source "
                + "before relying on this timing."
            );
        }
    } else {
        complexity = "moderate";
        channel_names: list[str] = [];
        for record in [
            item for item in [root -->] if isinstance(item, FixtureRecord)
        ] {
            channel = materialized_node(record);
            if isinstance(channel, CommentChannel) {
                channel_names.append(channel.recipient);
                source_ids.append(recourse_source_ref(channel));
            }
        }
        channel_hint: str = (
            channel_names[0] if len(channel_names) > 0
            else "the recipient named in the cited notice"
        );
        steps = [
            "Confirm the comment route for " + body_name
            + ": no fixture-backed channel is bound to it in this graph.",
            "Until it is confirmed, address the comment to " + channel_hint
            + " using the cited source, not a phone number found elsewhere.",
            "File one comment per affected organization and keep the "
            + "timestamped confirmation as the record.",
        ];
        uncertainties.append(
            "No comment channel is linked to " + body_name
            + " in the record, so the recipient above is unverified for this "
            + "decision."
        );
        for gap_message in decision.gaps {
            uncertainties.append(recourse_any_text(gap_message));
        }
    }

    for gap_id in gap_ids {
        source_ids.append(gap_id);
    }
    uncertainties.append(RECOURSE_STANDING_UNCERTAINTY);

    return RecoursePathSpec(
        slot_key="recorded_comment",
        title="Put the objection on the record with " + body_name,
        summary=(
            "A countable, dated submission to the body that decides. This is "
            + "the cheapest path that produces a record."
        ),
        target=body_name,
        complexity=complexity,
        binding_effect="advisory",
        binding_note=(
            "Creates an official record and a duty to receive it; it does not "
            + "bind the outcome."
        ),
        first_steps=steps,
        uncertainties=uncertainties,
        source_ids=recourse_known_source_ids(source_ids),
    );
}


def decision_zone_spec(
    project: Project,
    project_id: str,
    divergence: DivergenceCheck,
    impact: ImpactWalker,
) -> RecoursePathSpec {
    bodies: list[DecisionBody] = [
        body for body in [project ->: decided_by :->]
        if isinstance(body, DecisionBody)
    ];
    body_name: str = (
        bodies[0].name if len(bodies) > 0 else "the deciding body"
    );
    source_ids: list[str] = [project_id];
    for body in bodies {
        source_ids.append(recourse_source_ref(body));
        for zone in [body ->: accountable_to :->] {
            source_ids.append(recourse_source_ref(zone));
        }
    }
    for zone in [project ->: located_in :->] {
        source_ids.append(recourse_source_ref(zone));
    }
    for organization in [
        item for item in [root -->] if isinstance(item, FixtureRecord)
    ] {
        candidate = materialized_node(organization);
        if isinstance(candidate, Organization) and candidate.name in impact.orgs {
            source_ids.append(organization.fixture_id);
        }
    }

    decision_zone_label: str = (
        ", ".join(divergence.decision_zones)
        if len(divergence.decision_zones) > 0
        else "the constituency of " + body_name
    );
    uncertainties: list[str] = [];
    complexity: str = "moderate";
    summary: str = divergence.message;
    if divergence.diverged {
        complexity = "high";
        uncertainties.append(
            "Impact zone and decision zone do not overlap, so volume from the "
            + "impact zone alone does not reach the deciding constituency."
        );
    } else {
        uncertainties.append(
            "Zones overlap in the record, but overlap is not agreement; no "
            + "stakeholder here is inferred to support the position."
        );
    }
    if len(impact.excluded) > 0 {
        uncertainties.append(
            "Organizations serving the impact zone that are not recorded as "
            + "inside the official process: " + ", ".join(impact.excluded)
            + ". Their exclusion is a record gap, not proof of their position."
        );
    }
    uncertainties.append(RECOURSE_STANDING_UNCERTAINTY);

    return RecoursePathSpec(
        slot_key="decision_zone_contact",
        title="Reach the decision zone: " + decision_zone_label,
        summary=summary,
        target=decision_zone_label,
        complexity=complexity,
        binding_effect="advisory",
        binding_note=(
            "Persuasion of the deciding constituency; it changes votes only "
            + "through that constituency's own process."
        ),
        first_steps=[
            "List the organizations already serving " + decision_zone_label
            + " from the stakeholder layer before writing anything new.",
            "Brief them with the impact-zone evidence and its citations, "
            + "keeping claims to what the sources actually say.",
            "Ask each to file its own recorded submission to " + body_name
            + " rather than signing a single shared letter.",
        ],
        uncertainties=uncertainties,
        source_ids=recourse_known_source_ids(source_ids),
    );
}


def escalation_spec(
    project: Project,
    project_id: str,
    precedent: PrecedentMatcher,
    gap_ids: list[str],
) -> RecoursePathSpec {
    source_ids: list[str] = [project_id];
    for gap_id in gap_ids {
        source_ids.append(gap_id);
    }
    uncertainties: list[str] = [];
    steps: list[str] = [];
    title: str = "";
    summary: str = "";

    if len(precedent.matches) > 0 {
        top = precedent.matches[0];
        case_name: str = recourse_entry_text(top, "case");
        tactic_name: str = recourse_entry_text(top, "tactic");
        for anchor in [
            item for item in [root -->] if isinstance(item, ActionAnchor)
        ] {
            for precedent_case in [
                item for item in [anchor -->] if isinstance(item, PrecedentCase)
            ] {
                if precedent_case.name == case_name {
                    source_ids.append(recourse_source_ref(precedent_case));
                }
            }
        }
        title = (
            "Escalate along the " + tactic_name + " path used in " + case_name
        );
        summary = (
            case_name + " (" + recourse_entry_text(top, "year") + ") used "
            + tactic_name + " in the same category. Result on file: "
            + recourse_entry_text(top, "result") + "."
        );
        if top.get("claimable") is not True {
            uncertainties.append(
                "The recorded outcome of " + case_name
                + " is unverified in this graph and must not be presented as a "
                + "result you can repeat."
            );
        }
        steps = [
            "Read the " + case_name + " record and list what that campaign had "
            + "on file that this one does not.",
            "Identify who carried the " + tactic_name
            + " there, and the equivalent actor here.",
            "Get the procedural requirements for " + tactic_name
            + " in writing from the cited authority before committing to it.",
        ];
    } else {
        title = "Escalate beyond comment — requires sourcing first";
        summary = (
            "No precedent case is on file for this category in this graph, so "
            + "the escalation path is named but not yet evidenced."
        );
        uncertainties.append(
            "No PrecedentCase is loaded for category '" + project.category
            + "', so no comparable tactic or outcome is claimed here."
        );
        steps = [
            "Load a sourced precedent for category '" + project.category
            + "' before choosing an escalation tactic.",
            "Retrieve the written procedure (appeal, petition, or ballot) from "
            + "the deciding body's own published source.",
            "Confirm every threshold and deadline against that source; do not "
            + "act on a threshold this system did not retrieve.",
        ];
    }

    uncertainties.append(
        "Whether this escalation qualifies under any procedure is an open "
        + "question here; qualification is not asserted."
    );
    uncertainties.append(RECOURSE_STANDING_UNCERTAINTY);

    return RecoursePathSpec(
        slot_key="escalation",
        title=title,
        summary=summary,
        target="the procedure that can compel a change, once identified",
        complexity="high",
        binding_effect="binding_if_qualified",
        binding_note=(
            "Binding only if the escalation qualifies under a procedure whose "
            + "requirements are retrieved and met; this system does not decide "
            + "that it qualifies."
        ),
        first_steps=steps,
        uncertainties=uncertainties,
        source_ids=recourse_known_source_ids(source_ids),
    );
}


# ------------------------------------------------------------
# Materialization — idempotent per (project, slot).
# ------------------------------------------------------------
def find_action_path(project: Project, path_id: str) -> ActionPath | None {
    for path in [project ->: has_action_path :->] {
        if isinstance(path, ActionPath) and path.path_id == path_id {
            return path;
        }
    }
    return None;
}


def attach_campaign_layer(path: ActionPath) {
    for anchor in [
        item for item in [root -->] if isinstance(item, LayerAnchor)
    ] {
        if anchor.key != "campaign_activation" {
            continue;
        }
        for member in [anchor ->: in_semantic_layer :->] {
            if isinstance(member, ActionPath) and member.path_id == path.path_id {
                return;
            }
        }
        anchor +>: in_semantic_layer(
            membership_id="layer-member:campaign_activation:" + path.path_id,
            layer_key="campaign_activation",
        ) :+> path;
        return;
    }
}


def upsert_action_path(
    project: Project,
    project_id: str,
    spec: RecoursePathSpec,
    origin: str,
) -> ActionPath {
    path_id = "action-path:" + project_id + ":" + spec.slot_key;

    # A path may only cite source nodes that already exist. The project's
    # own ID is the last resort, never an invented reference.
    source_ids = recourse_known_source_ids(spec.source_ids);
    if len(source_ids) == 0 {
        source_ids = [project_id];
    }
    uncertainties = spec.uncertainties;
    if len(uncertainties) == 0 {
        uncertainties = [RECOURSE_STANDING_UNCERTAINTY];
    }

    path = find_action_path(project, path_id);
    if path is None {
        path = ActionPath(
            path_id=path_id,
            slot_key=spec.slot_key,
            project_id=project_id,
            title=spec.title,
            summary=spec.summary,
            target=spec.target,
            complexity=spec.complexity,
            binding_effect=spec.binding_effect,
            binding_note=spec.binding_note,
            first_steps=spec.first_steps,
            uncertainties=uncertainties,
            source_ids=source_ids,
            source_urls=recourse_source_urls(source_ids),
            legal_reviewed=False,
            origin=origin,
        );
        project +>: has_action_path(
            path_id=path_id, slot_key=spec.slot_key
        ) :+> path;
    } else {
        path.title = spec.title;
        path.summary = spec.summary;
        path.target = spec.target;
        path.complexity = spec.complexity;
        path.binding_effect = spec.binding_effect;
        path.binding_note = spec.binding_note;
        path.first_steps = spec.first_steps;
        path.uncertainties = uncertainties;
        path.source_ids = source_ids;
        path.source_urls = recourse_source_urls(source_ids);
        # Review status is never inherited from a regenerated path.
        path.legal_reviewed = False;
        path.origin = origin;
    }
    attach_campaign_layer(path);
    return path;
}


# ------------------------------------------------------------
# Frontend projections.
# ------------------------------------------------------------
def action_path_view(path: ActionPath) -> dict[str, any] {
    return {
        "id": path.path_id,
        "slot": path.slot_key,
        "project_id": path.project_id,
        "title": path.title,
        "summary": path.summary,
        "target": path.target,
        "complexity": path.complexity,
        "binding_effect": path.binding_effect,
        "binding_note": path.binding_note,
        "first_steps": path.first_steps,
        "uncertainties": path.uncertainties,
        "source_ids": path.source_ids,
        "source_urls": path.source_urls,
        "legal_reviewed": path.legal_reviewed,
        "origin": path.origin,
        "layer": path.layer_key,
    };
}


def recourse_error(
    code: str,
    message: str,
    detail: list[str],
) -> dict[str, any] {
    return {
        "ok": False,
        "error": {"code": code, "message": message, "detail": detail},
    };
}


# ------------------------------------------------------------
# RecommendRecourse
# ------------------------------------------------------------
walker RecommendRecourse {
    # Optional model output. Empty or invalid => deterministic fallback.
    has proposals: list[dict[str, any]] = [];

    has project_id: str = "";
    has project_name: str = "";
    has origin: str = "deterministic_fallback";
    has validation_errors: list[str] = [];

    has diverged: bool = False;
    has divergence_message: str = "";
    has impact_zones: list[str] = [];
    has decision_zones: list[str] = [];
    has playbook: list[dict[str, any]] = [];
    has procedure_gaps: list[str] = [];
    has orgs: list[str] = [];
    has excluded_orgs: list[str] = [];
    has precedent_matches: list[dict[str, any]] = [];

    has paths: list[ActionPath] = [];

    can run with Project entry {
        self.project_id = recourse_source_ref(here);
        self.project_name = here.name;

        divergence = DivergenceCheck();
        here spawn divergence;
        decision = DecisionWalker();
        here spawn decision;
        impact = ImpactWalker();
        here spawn impact;
        precedent = PrecedentMatcher();
        here spawn precedent;

        self.diverged = divergence.diverged;
        self.divergence_message = divergence.message;
        self.impact_zones = divergence.impact_zones;
        self.decision_zones = divergence.decision_zones;
        self.playbook = decision.playbook;
        self.procedure_gaps = decision.gaps;
        self.orgs = impact.orgs;
        self.excluded_orgs = impact.excluded;
        self.precedent_matches = precedent.matches;

        gap_ids: list[str] = [];
        for gap in [here ->: has_procedure_gap :->] {
            if isinstance(gap, ProcedureGap) {
                gap_ids.append(gap.gap_id);
            }
        }

        specs: list[RecoursePathSpec] = [];
        if len(self.proposals) > 0 {
            # Silence is not an error: no proposal simply means fallback.
            self.validation_errors = validate_recourse_proposals(self.proposals);
        }
        if len(self.proposals) > 0 and len(self.validation_errors) == 0 {
            self.origin = "llm_validated";
            slot = 0;
            for proposal in self.proposals {
                specs.append(normalize_recourse_proposal(proposal, slot));
                slot += 1;
            }
        } else {
            self.origin = "deterministic_fallback";
            specs = [
                recorded_comment_spec(
                    here, self.project_id, decision, gap_ids
                ),
                decision_zone_spec(
                    here, self.project_id, divergence, impact
                ),
                escalation_spec(
                    here, self.project_id, precedent, gap_ids
                ),
            ];
        }

        for spec in specs {
            self.paths.append(
                upsert_action_path(here, self.project_id, spec, self.origin)
            );
        }
    }
}


def recourse_response(run: RecommendRecourse) -> dict[str, any] {
    path_views: list[dict[str, any]] = [];
    for path in run.paths {
        path_views.append(action_path_view(path));
    }
    return {
        "ok": len(path_views) == RECOURSE_PATH_COUNT,
        "project": {"id": run.project_id, "name": run.project_name},
        "origin": run.origin,
        "validation_errors": run.validation_errors,
        "divergence": {
            "diverged": run.diverged,
            "impact_zones": run.impact_zones,
            "decision_zones": run.decision_zones,
            "message": run.divergence_message,
        },
        "playbook": run.playbook,
        "procedure_gaps": run.procedure_gaps,
        "excluded_organizations": run.excluded_orgs,
        "precedent_matches": run.precedent_matches,
        "action_paths": path_views,
        "legal_reviewed": False,
    };
}
