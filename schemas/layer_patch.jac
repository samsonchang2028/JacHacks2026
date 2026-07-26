# ============================================================
# layer_patch.jac — additive seven-layer + fixture identity types.
#
# The frozen schema remains untouched. Existing domain nodes and edges are
# reused; these types add only layer membership, fixture provenance,
# idempotent relation tracking, and explicit procedural gaps.
# ============================================================

include schema;


glob SEMANTIC_LAYERS: list[str] = [
    "issue_signal",
    "narrative_evidence",
    "community_stakeholder",
    "institution_decision",
    "law_procedure",
    "precedent_action",
    "campaign_activation",
];


node LayerAnchor {
    has key: str;
    has label: str;
    has order: int;
}


# Stable identity/provenance companion for an existing schema node.
# The domain node remains the materialized graph entity.
node FixtureRecord {
    has fixture_id: str;
    has record_type: str;
    has layer_key: str;
    has label: str;
    has node_jid: str = "";
    has source_url: str = "";
    has retrieved_at: str = "";
    has retrieval_info: str = "";
}


# Represents missing fixture-backed procedure. It is a finding, not a
# generated deadline, law, contact, or authority.
node ProcedureGap {
    has gap_id: str;
    has subject_id: str;
    has message: str;
    has source_url: str = "";
    has retrieved_at: str = "";
}


# FixtureRecord -> materialized existing-schema node.
edge materializes {}

# FixtureRecord -> FixtureRecord mirror of a materialized domain edge.
# The stable ID makes repeated ingestion idempotent and gives the frontend
# a deterministic edge ID without changing the frozen edge archetypes.
edge fixture_relation: FixtureRecord --> FixtureRecord {
    has fixture_id: str;
    has relation_type: str;
    has source_id: str;
    has target_id: str;
    has layer_key: str;
}

# LayerAnchor -> materialized domain node or ProcedureGap.
edge in_semantic_layer {
    has membership_id: str;
    has layer_key: str;
}

# Existing domain node -> ProcedureGap, with optional contextual endpoint.
edge has_procedure_gap {}
edge gap_relates_to {}
