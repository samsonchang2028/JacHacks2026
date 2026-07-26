# ============================================================
# fixture_adapter.jac — offline, deterministic fixture ingestion.
#
# Reads out/fixture.json only. It performs no network access and never
# generates deadlines, legal text, contacts, or authorities.
# ============================================================

include layer_patch;

import json;
import from pathlib { Path }


glob COMMENT_METHODS: list[str] = [
    "email", "web_form", "in_person", "mail"
];
glob DEADLINE_KINDS: list[str] = [
    "comment", "appeal", "signature", "hearing"
];
glob GEOZONE_KINDS: list[str] = [
    "district", "neighborhood", "citywide"
];
glob INCIDENT_KINDS: list[str] = [
    "311", "complaint_log", "forum"
];
glob TESTIMONY_KINDS: list[str] = [
    "testimony", "argument", "evidence", "counterargument"
];
glob FIXTURE_COLLECTIONS: list[str] = [
    "projects",
    "geo_zones",
    "decision_bodies",
    "comment_channels",
    "organizations",
    "testimony",
    "incidents",
];


obj FixtureIngestReport {
    has created: int = 0;
    has reused: int = 0;
    has skipped: int = 0;
    has invalid: int = 0;
    has created_relations: int = 0;
    has reused_relations: int = 0;
    has gaps: list[str] = [];
    has errors: list[str] = [];
}


def default_fixture_path() -> str {
    return str(
        Path(__file__ or "").resolve().parent.parent / "out" / "fixture.json"
    );
}


def load_fixture(path: str = "") -> dict[str, any] {
    fixture_path = path if path else default_fixture_path();
    with open(fixture_path, "r", encoding="utf-8") as fixture_file {
        loaded = json.load(fixture_file);
    }
    if isinstance(loaded, dict) {
        return loaded as dict[str, any];
    }
    return {};
}


def stable_fixture_id(record_type: str, natural_key: str) -> str {
    return "fixture:" + record_type + ":" + natural_key.strip().lower();
}


def stable_relation_id(
    relation_type: str,
    source_id: str,
    target_id: str,
) -> str {
    return (
        "fixture-relation:" + relation_type + ":"
        + source_id + "->" + target_id
    );
}


def required_string(
    record: dict[str, any],
    field_name: str,
) -> str | None {
    value = record.get(field_name);
    if isinstance(value, str) and len(value.strip()) > 0 {
        return value;
    }
    return None;
}


def optional_string(
    record: dict[str, any],
    field_name: str,
    fallback: str = "",
) -> str {
    value = record.get(field_name);
    return value if isinstance(value, str) else fallback;
}


def optional_integer(
    record: dict[str, any],
    field_name: str,
    fallback: int,
) -> int {
    value = record.get(field_name);
    return value if isinstance(value, int) else fallback;
}


def optional_string_list(
    record: dict[str, any],
    field_name: str,
    result: FixtureIngestReport,
    context: str,
) -> list[str] {
    value = record.get(field_name);
    if value is None {
        return [];
    }
    if not isinstance(value, list) {
        result.skipped += 1;
        result.errors.append(
            context + "." + field_name + " must be a list; relation skipped"
        );
        return [];
    }
    strings: list[str] = [];
    for item in value {
        if isinstance(item, str) and len(item.strip()) > 0 {
            strings.append(item);
        } else {
            result.skipped += 1;
            result.errors.append(
                context + "." + field_name
                + " contains a non-string or blank reference"
            );
        }
    }
    return strings;
}


def records_for(
    fixture: dict[str, any],
    collection: str,
    result: FixtureIngestReport,
) -> list[dict[str, any]] {
    raw_collection = fixture.get(collection);
    if not isinstance(raw_collection, list) {
        result.invalid += 1;
        result.errors.append(
            "Top-level field '" + collection + "' is required and must be a list"
        );
        return [];
    }
    records: list[dict[str, any]] = [];
    for raw_record in raw_collection {
        if isinstance(raw_record, dict) {
            records.append(raw_record as dict[str, any]);
        } else {
            result.invalid += 1;
            result.errors.append(
                "Non-object record in top-level field '" + collection + "'"
            );
        }
    }
    return records;
}


def find_fixture_record(fixture_id: str) -> FixtureRecord | None {
    for candidate in [
        item for item in [root -->] if isinstance(item, FixtureRecord)
    ] {
        if candidate.fixture_id == fixture_id {
            return candidate;
        }
    }
    return None;
}


def find_procedure_gap(gap_id: str) -> ProcedureGap | None {
    for candidate in [
        item for item in [root -->] if isinstance(item, ProcedureGap)
    ] {
        if candidate.gap_id == gap_id {
            return candidate;
        }
    }
    return None;
}


def register_materialized(
    fixture_id: str,
    record_type: str,
    layer_key: str,
    label: str,
    source_url: str,
    retrieved_at: str,
    retrieval_info: str,
    domain_node: (
        Project
        | GeoZone
        | DecisionBody
        | CommentChannel
        | Deadline
        | Organization
        | Testimony
        | Incident
    ),
    result: FixtureIngestReport,
) -> FixtureRecord {
    fixture_record = FixtureRecord(
        fixture_id=fixture_id,
        record_type=record_type,
        layer_key=layer_key,
        label=label,
        node_jid=str(jid(domain_node)),
        source_url=source_url,
        retrieved_at=retrieved_at,
        retrieval_info=retrieval_info,
    );
    root ++> fixture_record;
    fixture_record +>: materializes :+> domain_node;
    result.created += 1;
    return fixture_record;
}


def materialized_node(record: FixtureRecord) -> any {
    return jobj(record.node_jid);
}


def fixture_relation_exists(
    source_record: FixtureRecord,
    fixture_id: str,
) -> bool {
    for relation_edge in [
        edge source_record ->: fixture_relation :->
    ] {
        if relation_edge.fixture_id == fixture_id {
            return True;
        }
    }
    return False;
}


def ensure_fixture_relation(
    relation_type: str,
    source_id: str,
    target_id: str,
    layer_key: str,
    result: FixtureIngestReport,
) -> bool {
    source_record = find_fixture_record(source_id);
    target_record = find_fixture_record(target_id);
    if source_record is None or target_record is None {
        result.skipped += 1;
        result.errors.append(
            "Cannot bind " + relation_type + ": unresolved fixture endpoint "
            + source_id + " -> " + target_id
        );
        return False;
    }

    relation_id = stable_relation_id(
        relation_type, source_id, target_id
    );
    if fixture_relation_exists(source_record, relation_id) {
        result.reused_relations += 1;
        return True;
    }

    source_node = materialized_node(source_record);
    target_node = materialized_node(target_record);
    relation_created = False;

    if (
        relation_type == "located_in"
        and isinstance(source_node, Project)
        and isinstance(target_node, GeoZone)
    ) {
        source_node +>: located_in :+> target_node;
        relation_created = True;
    } elif (
        relation_type == "decided_by"
        and isinstance(source_node, Project)
        and isinstance(target_node, DecisionBody)
    ) {
        source_node +>: decided_by :+> target_node;
        relation_created = True;
    } elif (
        relation_type == "accountable_to"
        and isinstance(source_node, DecisionBody)
        and isinstance(target_node, GeoZone)
    ) {
        source_node +>: accountable_to :+> target_node;
        relation_created = True;
    } elif (
        relation_type == "serves"
        and isinstance(source_node, Organization)
        and isinstance(target_node, GeoZone)
    ) {
        source_node +>: serves :+> target_node;
        relation_created = True;
    } elif (
        relation_type == "governed_by"
        and isinstance(source_node, CommentChannel)
        and isinstance(target_node, Deadline)
    ) {
        source_node +>: governed_by :+> target_node;
        relation_created = True;
    }

    if not relation_created {
        result.skipped += 1;
        result.errors.append(
            "Cannot materialize relation '" + relation_type
            + "' for endpoint types in " + relation_id
        );
        return False;
    }

    source_record +>: fixture_relation(
        fixture_id=relation_id,
        relation_type=relation_type,
        source_id=source_id,
        target_id=target_id,
        layer_key=layer_key,
    ) :+> target_record;
    result.created_relations += 1;
    return True;
}


def ensure_procedure_gap(
    gap_id: str,
    subject_id: str,
    message: str,
    source_url: str,
    retrieved_at: str,
    subject_node: Project | CommentChannel,
    related_body: DecisionBody | None,
    result: FixtureIngestReport,
) {
    result.gaps.append(message);
    if find_procedure_gap(gap_id) is not None {
        return;
    }
    gap = ProcedureGap(
        gap_id=gap_id,
        subject_id=subject_id,
        message=message,
        source_url=source_url,
        retrieved_at=retrieved_at,
    );
    root ++> gap;
    subject_node +>: has_procedure_gap :+> gap;
    if related_body is not None {
        gap +>: gap_relates_to :+> related_body;
    }
}


def ingest_geo_zones(
    records: list[dict[str, any]],
    result: FixtureIngestReport,
) {
    for record in records {
        name = required_string(record, "name");
        kind = required_string(record, "kind");
        if (
            name is None
            or kind is None
            or kind not in GEOZONE_KINDS
        ) {
            result.invalid += 1;
            result.errors.append(
                "Invalid geo_zones record: name and supported kind are required"
            );
            continue;
        }
        fixture_id = stable_fixture_id("geo_zone", name);
        if find_fixture_record(fixture_id) is not None {
            result.reused += 1;
            continue;
        }
        notes = optional_string(record, "notes");
        population = optional_integer(record, "population_est", 0);
        if population < 0 {
            result.invalid += 1;
            result.errors.append(
                "Invalid geo_zones population_est for " + name
            );
            continue;
        }
        domain_node = GeoZone(
            name=name,
            kind=kind,
            population_est=population,
            notes=notes,
        );
        _ = register_materialized(
            fixture_id,
            "GeoZone",
            "community_stakeholder",
            name,
            "",
            "",
            notes,
            domain_node,
            result,
        );
    }
}


def ingest_decision_bodies(
    records: list[dict[str, any]],
    result: FixtureIngestReport,
) {
    for record in records {
        name = required_string(record, "name");
        kind = required_string(record, "kind");
        jurisdiction = required_string(record, "jurisdiction");
        if name is None or kind is None or jurisdiction is None {
            result.invalid += 1;
            result.errors.append(
                "Invalid decision_bodies record: name, kind, and jurisdiction "
                + "are required"
            );
            continue;
        }
        fixture_id = stable_fixture_id("decision_body", name);
        if find_fixture_record(fixture_id) is not None {
            result.reused += 1;
            continue;
        }
        domain_node = DecisionBody(
            name=name,
            kind=kind,
            jurisdiction=jurisdiction,
        );
        _ = register_materialized(
            fixture_id,
            "DecisionBody",
            "institution_decision",
            name,
            "",
            "",
            "",
            domain_node,
            result,
        );
    }
}


def ingest_organizations(
    records: list[dict[str, any]],
    result: FixtureIngestReport,
) {
    for record in records {
        name = required_string(record, "name");
        inside_process = record.get("inside_process");
        if name is None or not isinstance(inside_process, bool) {
            result.invalid += 1;
            result.errors.append(
                "Invalid organizations record: name and boolean "
                + "inside_process are required"
            );
            continue;
        }
        fixture_id = stable_fixture_id("organization", name);
        if find_fixture_record(fixture_id) is not None {
            result.reused += 1;
            continue;
        }
        notes = optional_string(record, "notes");
        domain_node = Organization(
            name=name,
            community=optional_string(record, "community"),
            language=optional_string(record, "language", "en"),
            contact=optional_string(record, "contact"),
            inside_process=inside_process,
        );
        _ = register_materialized(
            fixture_id,
            "Organization",
            "community_stakeholder",
            name,
            "",
            "",
            notes,
            domain_node,
            result,
        );
    }
}


def ingest_projects(
    records: list[dict[str, any]],
    result: FixtureIngestReport,
) {
    for record in records {
        name = required_string(record, "name");
        category = required_string(record, "category");
        location = required_string(record, "location");
        if (
            name is None
            or category is None
            or location is None
            or category not in CATEGORIES
        ) {
            result.invalid += 1;
            result.errors.append(
                "Invalid projects record: name, supported category, and "
                + "location are required"
            );
            continue;
        }
        fixture_id = stable_fixture_id("project", name);
        if find_fixture_record(fixture_id) is not None {
            result.reused += 1;
            continue;
        }
        source_url = optional_string(record, "source_url");
        fetched_at = optional_string(record, "fetched_at");
        domain_node = Project(
            name=name,
            category=category,
            location=location,
            description=optional_string(record, "description"),
            timeline=optional_string(record, "timeline"),
            source_url=source_url,
            fetched_at=fetched_at,
        );
        _ = register_materialized(
            fixture_id,
            "Project",
            "issue_signal",
            name,
            source_url,
            fetched_at,
            "",
            domain_node,
            result,
        );
    }
}


def ingest_comment_channels(
    records: list[dict[str, any]],
    result: FixtureIngestReport,
) {
    for record in records {
        recipient = required_string(record, "recipient");
        method = required_string(record, "method");
        source_url = required_string(record, "source_url");
        if (
            recipient is None
            or method is None
            or source_url is None
            or method not in COMMENT_METHODS
        ) {
            result.invalid += 1;
            result.errors.append(
                "Invalid comment_channels record: recipient, supported method, "
                + "and source_url are required"
            );
            continue;
        }
        fixture_id = stable_fixture_id(
            "comment_channel",
            recipient + "|" + method + "|" + source_url,
        );
        if find_fixture_record(fixture_id) is not None {
            result.reused += 1;
        } else {
            domain_node = CommentChannel(
                recipient=recipient,
                method=method,
                source_url=source_url,
                format_note=optional_string(record, "format_note"),
                languages=optional_string(record, "languages", "en"),
            );
            _ = register_materialized(
                fixture_id,
                "CommentChannel",
                "law_procedure",
                recipient,
                source_url,
                "",
                optional_string(record, "format_note"),
                domain_node,
                result,
            );
        }

        deadlines_value = record.get("deadlines");
        if deadlines_value is None {
            deadlines: list[dict[str, any]] = [];
        } elif isinstance(deadlines_value, list) {
            deadlines = [
                item as dict[str, any]
                for item in deadlines_value
                if isinstance(item, dict)
            ];
            malformed_deadlines = len(deadlines_value) - len(deadlines);
            result.invalid += malformed_deadlines;
        } else {
            result.invalid += 1;
            result.errors.append(
                "comment_channels.deadlines must be a list for " + recipient
            );
            deadlines = [];
        }

        channel_record = find_fixture_record(fixture_id);
        if channel_record is not None {
            channel_node = materialized_node(channel_record);
            if isinstance(channel_node, CommentChannel) and len(deadlines) == 0 {
                gap_message = (
                    "No fixture-backed deadline is recorded for comment channel "
                    + recipient
                );
                ensure_procedure_gap(
                    "procedure-gap:channel-deadline:" + fixture_id,
                    fixture_id,
                    gap_message,
                    source_url,
                    "",
                    channel_node,
                    None,
                    result,
                );
            }
        }

        for deadline in deadlines {
            kind = required_string(deadline, "kind");
            date = required_string(deadline, "date");
            deadline_source = required_string(deadline, "source_url");
            if (
                kind is None
                or date is None
                or deadline_source is None
                or kind not in DEADLINE_KINDS
            ) {
                result.invalid += 1;
                result.errors.append(
                    "Invalid deadline under " + recipient
                    + ": supported kind, nonblank date, and source_url required"
                );
                continue;
            }
            deadline_id = stable_fixture_id(
                "deadline",
                fixture_id + "|" + kind + "|" + date + "|" + deadline_source,
            );
            if find_fixture_record(deadline_id) is not None {
                result.reused += 1;
            } else {
                deadline_node = Deadline(
                    kind=kind,
                    date=date,
                    source_url=deadline_source,
                    threshold=optional_string(deadline, "threshold"),
                );
                _ = register_materialized(
                    deadline_id,
                    "Deadline",
                    "law_procedure",
                    kind + " deadline (" + date + ")",
                    deadline_source,
                    "",
                    "",
                    deadline_node,
                    result,
                );
            }
            _ = ensure_fixture_relation(
                "governed_by",
                fixture_id,
                deadline_id,
                "law_procedure",
                result,
            );
        }

        channel_record = find_fixture_record(fixture_id);
        if channel_record is not None {
            channel_node = materialized_node(channel_record);
            if isinstance(channel_node, CommentChannel) {
                gap_message = (
                    "Fixture comment channel '" + recipient
                    + "' has no explicit DecisionBody reference; no authority "
                    + "link was inferred"
                );
                ensure_procedure_gap(
                    "procedure-gap:channel-body:" + fixture_id,
                    fixture_id,
                    gap_message,
                    source_url,
                    "",
                    channel_node,
                    None,
                    result,
                );
            }
        }
    }
}


def ingest_testimony(
    records: list[dict[str, any]],
    result: FixtureIngestReport,
) {
    for record in records {
        speaker = required_string(record, "speaker");
        claim = required_string(record, "claim");
        kind = required_string(record, "kind");
        source_value = record.get("source_url");
        if (
            speaker is None
            or claim is None
            or kind is None
            or not isinstance(source_value, str)
            or kind not in TESTIMONY_KINDS
        ) {
            result.invalid += 1;
            result.errors.append(
                "Invalid testimony record: speaker, claim, supported kind, "
                + "and string source_url are required"
            );
            continue;
        }
        source_url = source_value;
        fixture_id = stable_fixture_id(
            "testimony",
            speaker + "|" + claim + "|" + source_url,
        );
        if find_fixture_record(fixture_id) is not None {
            result.reused += 1;
            continue;
        }
        domain_node = Testimony(
            speaker=speaker,
            claim=claim,
            affiliation=optional_string(record, "affiliation"),
            language=optional_string(record, "language", "en"),
            kind=kind,
            source_url=source_url,
        );
        _ = register_materialized(
            fixture_id,
            "Testimony",
            "narrative_evidence",
            speaker,
            source_url,
            "",
            "",
            domain_node,
            result,
        );
    }
}


def ingest_incidents(
    records: list[dict[str, any]],
    result: FixtureIngestReport,
) {
    for record in records {
        kind = required_string(record, "kind");
        summary = required_string(record, "summary");
        if (
            kind is None
            or summary is None
            or kind not in INCIDENT_KINDS
        ) {
            result.invalid += 1;
            result.errors.append(
                "Invalid incidents record: supported kind and summary required"
            );
            continue;
        }
        fixture_id = stable_fixture_id(
            "incident",
            kind + "|" + summary + "|" + optional_string(record, "source_url"),
        );
        if find_fixture_record(fixture_id) is not None {
            result.reused += 1;
            continue;
        }
        count = optional_integer(record, "count", 1);
        if count < 0 {
            result.invalid += 1;
            result.errors.append("Invalid incident count for " + summary);
            continue;
        }
        source_url = optional_string(record, "source_url");
        domain_node = Incident(
            kind=kind,
            summary=summary,
            count=count,
            source_url=source_url,
        );
        _ = register_materialized(
            fixture_id,
            "Incident",
            "issue_signal",
            summary,
            source_url,
            "",
            "",
            domain_node,
            result,
        );
        result.gaps.append(
            "Incident '" + summary
            + "' has no project reference in the fixture contract"
        );
    }
}


def bind_geo_relations(
    records: list[dict[str, any]],
    result: FixtureIngestReport,
) {
    for record in records {
        body_name = required_string(record, "name");
        if body_name is None {
            continue;
        }
        body_id = stable_fixture_id("decision_body", body_name);
        for zone_name in optional_string_list(
            record, "accountable_to", result, body_id
        ) {
            _ = ensure_fixture_relation(
                "accountable_to",
                body_id,
                stable_fixture_id("geo_zone", zone_name),
                "institution_decision",
                result,
            );
        }
    }
}


def bind_organization_relations(
    records: list[dict[str, any]],
    result: FixtureIngestReport,
) {
    for record in records {
        org_name = required_string(record, "name");
        if org_name is None {
            continue;
        }
        org_id = stable_fixture_id("organization", org_name);
        for zone_name in optional_string_list(
            record, "serves", result, org_id
        ) {
            _ = ensure_fixture_relation(
                "serves",
                org_id,
                stable_fixture_id("geo_zone", zone_name),
                "community_stakeholder",
                result,
            );
        }
    }
}


def bind_project_relations(
    records: list[dict[str, any]],
    result: FixtureIngestReport,
) {
    for record in records {
        project_name = required_string(record, "name");
        if project_name is None {
            continue;
        }
        project_id = stable_fixture_id("project", project_name);
        project_record = find_fixture_record(project_id);
        if project_record is None {
            continue;
        }
        for zone_name in optional_string_list(
            record, "geo_zones", result, project_id
        ) {
            _ = ensure_fixture_relation(
                "located_in",
                project_id,
                stable_fixture_id("geo_zone", zone_name),
                "issue_signal",
                result,
            );
        }
        for body_name in optional_string_list(
            record, "decision_bodies", result, project_id
        ) {
            body_id = stable_fixture_id("decision_body", body_name);
            if ensure_fixture_relation(
                "decided_by",
                project_id,
                body_id,
                "institution_decision",
                result,
            ) {
                project_node = materialized_node(project_record);
                body_record = find_fixture_record(body_id);
                if body_record is not None {
                    body_node = materialized_node(body_record);
                    if (
                        isinstance(project_node, Project)
                        and isinstance(body_node, DecisionBody)
                    ) {
                        gap_message = (
                            "No fixture-backed comment channel is explicitly "
                            + "linked to " + body_name + " for " + project_name
                        );
                        ensure_procedure_gap(
                            "procedure-gap:project-body:"
                            + project_id + "|" + body_id,
                            project_id,
                            gap_message,
                            optional_string(record, "source_url"),
                            optional_string(record, "fetched_at"),
                            project_node,
                            body_node,
                            result,
                        );
                    }
                }
            }
        }
    }
}


def ingest_fixture(fixture: dict[str, any]) -> FixtureIngestReport {
    result = FixtureIngestReport();

    collections: dict[str, list[dict[str, any]]] = {};
    for collection in FIXTURE_COLLECTIONS {
        collections[collection] = records_for(fixture, collection, result);
    }

    geo_records = collections["geo_zones"];
    body_records = collections["decision_bodies"];
    org_records = collections["organizations"];
    project_records = collections["projects"];
    channel_records = collections["comment_channels"];
    testimony_records = collections["testimony"];
    incident_records = collections["incidents"];

    ingest_geo_zones(geo_records, result);
    ingest_decision_bodies(body_records, result);
    ingest_organizations(org_records, result);
    ingest_projects(project_records, result);
    ingest_comment_channels(channel_records, result);
    ingest_testimony(testimony_records, result);
    ingest_incidents(incident_records, result);

    bind_geo_relations(body_records, result);
    bind_organization_relations(org_records, result);
    bind_project_relations(project_records, result);
    return result;
}


def count_fixture_records() -> int {
    return len([
        item for item in [root -->] if isinstance(item, FixtureRecord)
    ]);
}


def count_materialized_fixture_nodes() -> int {
    count = 0;
    for record in [
        item for item in [root -->] if isinstance(item, FixtureRecord)
    ] {
        if materialized_node(record) is not None {
            count += 1;
        }
    }
    return count;
}


def count_procedure_gaps() -> int {
    return len([
        item for item in [root -->] if isinstance(item, ProcedureGap)
    ]);
}
