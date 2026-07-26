# ============================================================
# graph_snapshot.jac — frontend-ready semantic graph projection.
# ============================================================

include layer_patch;


obj SnapshotNode {
    has id: str;
    has label: str;
    has node_type: str;
    has layer_key: str;
    has source_url: str;
    has retrieved_at: str;
    has retrieval_info: str;
}


obj SnapshotEdge {
    has id: str;
    has source: str;
    has target: str;
    has edge_type: str;
    has layer_key: str;
}


obj SemanticLayerSnapshot {
    has key: str;
    has label: str;
    has order: int;
    has nodes: list[SnapshotNode] = [];
    has edges: list[SnapshotEdge] = [];
}


obj GraphSnapshot {
    has layers: list[SemanticLayerSnapshot] = [];
    has node_count: int = 0;
    has edge_count: int = 0;
}


def snapshot_layer_label(layer_key: str) -> str {
    for anchor in [
        item for item in [root -->] if isinstance(item, LayerAnchor)
    ] {
        if anchor.key == layer_key {
            return anchor.label;
        }
    }
    return layer_key;
}


def snapshot_layer_order(layer_key: str) -> int {
    for anchor in [
        item for item in [root -->] if isinstance(item, LayerAnchor)
    ] {
        if anchor.key == layer_key {
            return anchor.order;
        }
    }
    return 0;
}


def build_layer_snapshot(layer_key: str) -> SemanticLayerSnapshot {
    layer = SemanticLayerSnapshot(
        key=layer_key,
        label=snapshot_layer_label(layer_key),
        order=snapshot_layer_order(layer_key),
    );

    for record in [
        item for item in [root -->] if isinstance(item, FixtureRecord)
    ] {
        if record.layer_key == layer_key {
            layer.nodes.append(SnapshotNode(
                id=record.fixture_id,
                label=record.label,
                node_type=record.record_type,
                layer_key=record.layer_key,
                source_url=record.source_url,
                retrieved_at=record.retrieved_at,
                retrieval_info=record.retrieval_info,
            ));
        }
        for relation_edge in [
            edge record ->: fixture_relation :->
        ] {
            if relation_edge.layer_key == layer_key {
                layer.edges.append(SnapshotEdge(
                    id=relation_edge.fixture_id,
                    source=relation_edge.source_id,
                    target=relation_edge.target_id,
                    edge_type=relation_edge.relation_type,
                    layer_key=relation_edge.layer_key,
                ));
            }
        }
    }

    if layer_key == "law_procedure" {
        for gap in [
            item for item in [root -->] if isinstance(item, ProcedureGap)
        ] {
            layer.nodes.append(SnapshotNode(
                id=gap.gap_id,
                label=gap.message,
                node_type="ProcedureGap",
                layer_key="law_procedure",
                source_url=gap.source_url,
                retrieved_at=gap.retrieved_at,
                retrieval_info="Explicit gap; no procedural fact inferred",
            ));
            layer.edges.append(SnapshotEdge(
                id="snapshot-gap-edge:" + gap.gap_id,
                source=gap.subject_id,
                target=gap.gap_id,
                edge_type="has_procedure_gap",
                layer_key="law_procedure",
            ));
        }
    }
    return layer;
}


def build_graph_snapshot() -> GraphSnapshot {
    snapshot = GraphSnapshot();
    for layer_key in SEMANTIC_LAYERS {
        layer = build_layer_snapshot(layer_key);
        snapshot.node_count += len(layer.nodes);
        snapshot.edge_count += len(layer.edges);
        snapshot.layers.append(layer);
    }
    return snapshot;
}


def graph_snapshot_dict(snapshot: GraphSnapshot) -> dict[str, object] {
    layer_views: list[dict[str, object]] = [];
    for layer in snapshot.layers {
        node_views: list[dict[str, str]] = [];
        edge_views: list[dict[str, str]] = [];
        for node_view in layer.nodes {
            node_views.append({
                "id": node_view.id,
                "label": node_view.label,
                "type": node_view.node_type,
                "layer": node_view.layer_key,
                "source_url": node_view.source_url,
                "retrieved_at": node_view.retrieved_at,
                "retrieval_info": node_view.retrieval_info,
            });
        }
        for edge_view in layer.edges {
            edge_views.append({
                "id": edge_view.id,
                "source": edge_view.source,
                "target": edge_view.target,
                "type": edge_view.edge_type,
                "layer": edge_view.layer_key,
            });
        }
        layer_views.append({
            "key": layer.key,
            "label": layer.label,
            "order": layer.order,
            "nodes": node_views,
            "edges": edge_views,
        });
    }
    return {
        "layers": layer_views,
        "node_count": snapshot.node_count,
        "edge_count": snapshot.edge_count,
    };
}
