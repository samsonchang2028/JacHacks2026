# ============================================================
# seed_layers.jac — idempotent seven-layer anchor seeding.
#
# Fixture ingestion materializes domain nodes behind FixtureRecord identities.
# This module attaches those nodes, plus explicit ProcedureGap findings, to
# one of seven stable semantic layer anchors.
# ============================================================

include layer_patch;


obj LayerSeedReport {
    has anchors_created: int = 0;
    has anchors_reused: int = 0;
    has memberships_created: int = 0;
    has memberships_reused: int = 0;
    has invalid: int = 0;
    has errors: list[str] = [];
}


def layer_label(layer_key: str) -> str {
    if layer_key == "issue_signal" {
        return "Issue & Signal";
    } elif layer_key == "narrative_evidence" {
        return "Narrative & Evidence";
    } elif layer_key == "community_stakeholder" {
        return "Community & Stakeholder";
    } elif layer_key == "institution_decision" {
        return "Institution & Decision";
    } elif layer_key == "law_procedure" {
        return "Law & Procedure";
    } elif layer_key == "precedent_action" {
        return "Precedent & Action";
    }
    return "Campaign & Activation";
}


def layer_order(layer_key: str) -> int {
    if layer_key == "issue_signal" { return 1; }
    elif layer_key == "narrative_evidence" { return 2; }
    elif layer_key == "community_stakeholder" { return 3; }
    elif layer_key == "institution_decision" { return 4; }
    elif layer_key == "law_procedure" { return 5; }
    elif layer_key == "precedent_action" { return 6; }
    elif layer_key == "campaign_activation" { return 7; }
    return 0;
}


def find_layer_anchor(layer_key: str) -> LayerAnchor | None {
    for candidate in [
        item for item in [root -->] if isinstance(item, LayerAnchor)
    ] {
        if candidate.key == layer_key {
            return candidate;
        }
    }
    return None;
}


def ensure_layer_anchor(
    layer_key: str,
    result: LayerSeedReport,
) -> LayerAnchor {
    existing = find_layer_anchor(layer_key);
    if existing is not None {
        result.anchors_reused += 1;
        return existing;
    }
    anchor = LayerAnchor(
        key=layer_key,
        label=layer_label(layer_key),
        order=layer_order(layer_key),
    );
    root ++> anchor;
    result.anchors_created += 1;
    return anchor;
}


def membership_exists(
    anchor: LayerAnchor,
    membership_id: str,
) -> bool {
    for membership_edge in [
        edge anchor ->: in_semantic_layer :->
    ] {
        if membership_edge.membership_id == membership_id {
            return True;
        }
    }
    return False;
}


def attach_fixture_record(
    record: FixtureRecord,
    result: LayerSeedReport,
) {
    anchor = find_layer_anchor(record.layer_key);
    if anchor is None {
        result.invalid += 1;
        result.errors.append(
            "Unknown semantic layer '" + record.layer_key
            + "' for " + record.fixture_id
        );
        return;
    }

    membership_id = (
        "layer-membership:" + record.layer_key + ":" + record.fixture_id
    );
    if membership_exists(anchor, membership_id) {
        result.memberships_reused += 1;
        return;
    }

    domain_node = jobj(record.node_jid);
    attached = False;
    if isinstance(domain_node, Project) {
        anchor +>: in_semantic_layer(
            membership_id=membership_id, layer_key=record.layer_key
        ) :+> domain_node;
        attached = True;
    } elif isinstance(domain_node, GeoZone) {
        anchor +>: in_semantic_layer(
            membership_id=membership_id, layer_key=record.layer_key
        ) :+> domain_node;
        attached = True;
    } elif isinstance(domain_node, DecisionBody) {
        anchor +>: in_semantic_layer(
            membership_id=membership_id, layer_key=record.layer_key
        ) :+> domain_node;
        attached = True;
    } elif isinstance(domain_node, CommentChannel) {
        anchor +>: in_semantic_layer(
            membership_id=membership_id, layer_key=record.layer_key
        ) :+> domain_node;
        attached = True;
    } elif isinstance(domain_node, Deadline) {
        anchor +>: in_semantic_layer(
            membership_id=membership_id, layer_key=record.layer_key
        ) :+> domain_node;
        attached = True;
    } elif isinstance(domain_node, Organization) {
        anchor +>: in_semantic_layer(
            membership_id=membership_id, layer_key=record.layer_key
        ) :+> domain_node;
        attached = True;
    } elif isinstance(domain_node, Testimony) {
        anchor +>: in_semantic_layer(
            membership_id=membership_id, layer_key=record.layer_key
        ) :+> domain_node;
        attached = True;
    } elif isinstance(domain_node, Incident) {
        anchor +>: in_semantic_layer(
            membership_id=membership_id, layer_key=record.layer_key
        ) :+> domain_node;
        attached = True;
    }

    if attached {
        result.memberships_created += 1;
    } else {
        result.invalid += 1;
        result.errors.append(
            "Fixture record has no materialized supported node: "
            + record.fixture_id
        );
    }
}


def attach_procedure_gap(
    gap: ProcedureGap,
    result: LayerSeedReport,
) {
    anchor = find_layer_anchor("law_procedure");
    if anchor is None {
        result.invalid += 1;
        result.errors.append("Missing law_procedure anchor");
        return;
    }
    membership_id = "layer-membership:law_procedure:" + gap.gap_id;
    if membership_exists(anchor, membership_id) {
        result.memberships_reused += 1;
        return;
    }
    anchor +>: in_semantic_layer(
        membership_id=membership_id,
        layer_key="law_procedure",
    ) :+> gap;
    result.memberships_created += 1;
}


def seed_layers() -> LayerSeedReport {
    result = LayerSeedReport();
    for layer_key in SEMANTIC_LAYERS {
        _ = ensure_layer_anchor(layer_key, result);
    }
    for record in [
        item for item in [root -->] if isinstance(item, FixtureRecord)
    ] {
        attach_fixture_record(record, result);
    }
    for gap in [
        item for item in [root -->] if isinstance(item, ProcedureGap)
    ] {
        attach_procedure_gap(gap, result);
    }
    return result;
}


def count_layer_anchors() -> int {
    return len([
        item for item in [root -->] if isinstance(item, LayerAnchor)
    ]);
}


def count_layer_memberships() -> int {
    count = 0;
    for anchor in [
        item for item in [root -->] if isinstance(item, LayerAnchor)
    ] {
        count += len([edge anchor ->: in_semantic_layer :->]);
    }
    return count;
}
