# ============================================================
# smoke_layers.jac — fixture + seven-layer integration smoke.
#
# Run from any directory:
#   jac run /absolute/path/to/schemas/smoke_layers.jac
# ============================================================

include layer_patch;

import json;
import from fixture_adapter {
    count_fixture_records,
    count_materialized_fixture_nodes,
    count_procedure_gaps,
    ingest_fixture,
    load_fixture,
}
import from seed_layers {
    count_layer_anchors,
    count_layer_memberships,
    find_layer_anchor,
    seed_layers,
}
import from graph_snapshot {
    build_graph_snapshot,
    graph_snapshot_dict,
}


with entry {
    failures = 0;
    fixture = load_fixture();

    first = ingest_fixture(fixture);
    first_fixture_count = count_fixture_records();
    first_materialized_count = count_materialized_fixture_nodes();
    first_gap_count = count_procedure_gaps();

    second = ingest_fixture(fixture);
    second_fixture_count = count_fixture_records();
    second_materialized_count = count_materialized_fixture_nodes();
    second_gap_count = count_procedure_gaps();

    if first.created == 0 {
        print("FAIL: first ingestion created no fixture records");
        failures += 1;
    }
    if first.invalid != 0 {
        print(f"FAIL: first ingestion has {first.invalid} invalid records");
        failures += 1;
    }
    if second.created != 0 {
        print(
            f"FAIL: second ingestion created {second.created} duplicate records"
        );
        failures += 1;
    }
    if second.reused != first.created {
        print(
            "FAIL: second ingestion did not reuse every first-run record "
            + f"({second.reused} reused vs {first.created} created)"
        );
        failures += 1;
    }
    if first_fixture_count != second_fixture_count {
        print("FAIL: FixtureRecord count changed on second ingestion");
        failures += 1;
    }
    if first_materialized_count != second_materialized_count {
        print("FAIL: materialized node count changed on second ingestion");
        failures += 1;
    }
    if first_gap_count != second_gap_count {
        print("FAIL: ProcedureGap count changed on second ingestion");
        failures += 1;
    }
    if second.created_relations != 0 {
        print("FAIL: second ingestion created duplicate graph relations");
        failures += 1;
    }

    first_layers = seed_layers();
    second_layers = seed_layers();
    if count_layer_anchors() != 7 {
        print(
            "FAIL: expected 7 LayerAnchor nodes, found "
            + str(count_layer_anchors())
        );
        failures += 1;
    }
    for layer_key in SEMANTIC_LAYERS {
        if find_layer_anchor(layer_key) is None {
            print("FAIL: missing layer anchor " + layer_key);
            failures += 1;
        }
    }
    if second_layers.anchors_created != 0 {
        print("FAIL: repeated layer seeding created duplicate anchors");
        failures += 1;
    }
    if second_layers.memberships_created != 0 {
        print("FAIL: repeated layer seeding created duplicate memberships");
        failures += 1;
    }

    snapshot = build_graph_snapshot();
    if len(snapshot.layers) != 7 {
        print("FAIL: graph snapshot does not contain all seven layers");
        failures += 1;
    }
    if snapshot.node_count != count_layer_memberships() {
        print(
            "FAIL: snapshot node count does not match layer memberships "
            + f"({snapshot.node_count} vs {count_layer_memberships()})"
        );
        failures += 1;
    }

    print(
        "fixture ingest #1: "
        + f"created={first.created}, reused={first.reused}, "
        + f"skipped={first.skipped}, invalid={first.invalid}, "
        + f"relations={first.created_relations}, gaps={len(first.gaps)}"
    );
    print(
        "fixture ingest #2: "
        + f"created={second.created}, reused={second.reused}, "
        + f"skipped={second.skipped}, invalid={second.invalid}, "
        + f"reused_relations={second.reused_relations}"
    );
    print(
        "layers: "
        + f"anchors={count_layer_anchors()}, "
        + f"memberships={count_layer_memberships()}, "
        + f"created_first={first_layers.memberships_created}"
    );
    print(json.dumps(
        graph_snapshot_dict(snapshot),
        indent=2,
        ensure_ascii=False,
    ));
    print("--- layer failures: " + str(failures) + " ---");
    assert failures == 0, "smoke_layers failed";
}
