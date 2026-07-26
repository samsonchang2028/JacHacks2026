# ============================================================
# smoke_civic.jac — end-to-end civic reasoning check.
#
#   jac run smoke_civic.jac
#
# Ingests out/fixture.json through fixture_adapter, runs the existing
# walkers, then EvidenceMatcher and RecommendRecourse, and asserts the two
# boundaries that matter:
#
#   * every project ends with exactly three source-backed ActionPaths;
#   * no `satisfies` and no `proves` relationship exists in the graph.
#
# The run is idempotent: it repeats RecommendRecourse and checks that the
# project still holds exactly three paths.
# ============================================================

include walkers_recourse;

import json;


def civic_require(failures: list[str], condition: bool, message: str) {
    if not condition {
        failures.append(message);
    }
}


def civic_node_jids() -> list[str] {
    visited: list[str] = [];
    frontier: list[any] = [root];
    while len(frontier) > 0 {
        current = frontier.pop();
        current_jid = str(jid(current));
        if current_jid in visited {
            continue;
        }
        visited.append(current_jid);
        for neighbor in [current -->] {
            frontier.append(neighbor);
        }
    }
    return visited;
}


def civic_projects() -> list[Project] {
    # Name-ordered so the printed report is stable between runs.
    by_name: dict[str, Project] = {};
    for record in [
        item for item in [root -->] if isinstance(item, FixtureRecord)
    ] {
        candidate = materialized_node(record);
        if isinstance(candidate, Project) {
            by_name[candidate.name] = candidate;
        }
    }
    projects: list[Project] = [];
    for name in sorted(by_name.keys()) {
        projects.append(by_name[name]);
    }
    return projects;
}


def civic_evidence_links() -> list[dict[str, any]] {
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
                "source": link.source_id,
                "target": link.target_id,
                "basis": link.basis,
                "confidence": link.confidence,
                "model_proposed": link.model_proposed,
                "review_status": link.review_status,
            });
        }
        for neighbor in [current -->] {
            frontier.append(neighbor);
        }
    }
    return views;
}


def check_action_paths(
    failures: list[str],
    project_label: str,
    paths: list[ActionPath],
) {
    civic_require(
        failures,
        len(paths) == RECOURSE_PATH_COUNT,
        project_label + ": expected exactly " + str(RECOURSE_PATH_COUNT)
        + " action paths, got " + str(len(paths)),
    );

    slot_keys: list[str] = [];
    for path in paths {
        label = project_label + " / " + path.slot_key;
        if path.slot_key not in slot_keys {
            slot_keys.append(path.slot_key);
        }
        civic_require(
            failures,
            len(path.first_steps) == RECOURSE_FIRST_STEP_COUNT,
            label + ": expected exactly " + str(RECOURSE_FIRST_STEP_COUNT)
            + " first steps, got " + str(len(path.first_steps)),
        );
        civic_require(
            failures,
            len(path.uncertainties) >= 1,
            label + ": at least one uncertainty is required",
        );
        civic_require(
            failures,
            path.complexity in RECOURSE_COMPLEXITY_VALUES,
            label + ": unsupported complexity '" + path.complexity + "'",
        );
        civic_require(
            failures,
            path.binding_effect in RECOURSE_BINDING_EFFECTS,
            label + ": unsupported binding effect '" + path.binding_effect + "'",
        );
        civic_require(
            failures,
            len(path.binding_note.strip()) > 0,
            label + ": binding effect must carry an explanatory note",
        );
        civic_require(
            failures,
            path.legal_reviewed == False,
            label + ": legal_reviewed must default to false",
        );
        civic_require(
            failures,
            len(path.source_ids) > 0,
            label + ": action path cites no source node",
        );
        for source_id in path.source_ids {
            civic_require(
                failures,
                recourse_source_exists(source_id),
                label + ": cited source node does not exist: " + source_id,
            );
        }
    }
    civic_require(
        failures,
        len(slot_keys) == RECOURSE_PATH_COUNT,
        project_label + ": action paths must be three distinct kinds, got "
        + ", ".join(slot_keys),
    );
}


with entry {
    failures: list[str] = [];

    # --- 1. fixture ingestion through the existing adapter -----------
    fixture = load_fixture();
    ingest_summary = ingest_fixture(fixture);
    print("--- fixture ingest ---");
    print(json.dumps({
        "created": ingest_summary.created,
        "reused": ingest_summary.reused,
        "skipped": ingest_summary.skipped,
        "invalid": ingest_summary.invalid,
        "created_relations": ingest_summary.created_relations,
        "reused_relations": ingest_summary.reused_relations,
        "procedure_gaps": count_procedure_gaps(),
        "errors": ingest_summary.errors,
    }, indent=2, ensure_ascii=False));

    projects = civic_projects();
    civic_require(
        failures, len(projects) > 0, "fixture ingestion produced no Project"
    );

    # --- 2. the existing walkers ------------------------------------
    print("--- existing walkers ---");
    for project in projects {
        divergence = DivergenceCheck();
        project spawn divergence;
        decision = DecisionWalker();
        project spawn decision;
        impact = ImpactWalker();
        project spawn impact;
        precedent = PrecedentMatcher();
        project spawn precedent;
        print(json.dumps({
            "project": project.name,
            "diverged": divergence.diverged,
            "impact_zones": divergence.impact_zones,
            "decision_zones": divergence.decision_zones,
            "message": divergence.message,
            "playbook_entries": len(decision.playbook),
            "procedure_gaps": decision.gaps,
            "organizations": impact.orgs,
            "outside_official_process": impact.excluded,
            "precedent_matches": len(precedent.matches),
        }, indent=2, ensure_ascii=False));
    }

    # --- 3. EvidenceMatcher -----------------------------------------
    nodes_before = len(civic_node_jids());
    relations_before = relation_names_in_graph();

    matcher = EvidenceMatcher();
    root spawn matcher;

    nodes_after = len(civic_node_jids());
    relations_after = relation_names_in_graph();
    new_relations = [
        name for name in relations_after if name not in relations_before
    ];

    print("--- evidence matcher ---");
    print(json.dumps({
        "scanned": matcher.scanned,
        "proposed": matcher.proposed,
        "reused": matcher.reused,
        "skipped": matcher.skipped,
        "notes": matcher.notes,
        "links": matcher.links,
    }, indent=2, ensure_ascii=False));

    civic_require(
        failures,
        nodes_after == nodes_before,
        "EvidenceMatcher created nodes: " + str(nodes_before) + " -> "
        + str(nodes_after),
    );
    for name in new_relations {
        civic_require(
            failures,
            name == "potentially_relevant_to",
            "EvidenceMatcher created a non-permitted relationship: " + name,
        );
    }
    civic_require(
        failures,
        matcher.scanned["Testimony"] > 0,
        "EvidenceMatcher traversed no fixture-ingested Testimony",
    );
    civic_require(
        failures,
        matcher.scanned["DecisionBody"] > 0,
        "EvidenceMatcher traversed no fixture-ingested DecisionBody",
    );
    civic_require(
        failures,
        matcher.scanned["CommentChannel"] > 0,
        "EvidenceMatcher traversed no fixture-ingested CommentChannel",
    );

    for link in civic_evidence_links() {
        civic_require(
            failures,
            link["review_status"] == "unreviewed",
            "Proposed relationship is not marked unreviewed: "
            + str(link["id"]),
        );
        civic_require(
            failures,
            link["model_proposed"] == True,
            "Proposed relationship is not marked model-proposed: "
            + str(link["id"]),
        );
        civic_require(
            failures,
            evidence_source_exists(str(link["source"])),
            "Proposed relationship lost its source ID: " + str(link["source"]),
        );
        civic_require(
            failures,
            evidence_source_exists(str(link["target"])),
            "Proposed relationship lost its target ID: " + str(link["target"]),
        );
    }

    # --- 4. RecommendRecourse ---------------------------------------
    print("--- recourse ---");
    for project in projects {
        recourse = RecommendRecourse();
        project spawn recourse;
        print(json.dumps(
            recourse_response(recourse), indent=2, ensure_ascii=False
        ));
        check_action_paths(failures, project.name, recourse.paths);
        civic_require(
            failures,
            recourse.origin == "deterministic_fallback",
            project.name + ": expected the deterministic fallback when no "
            + "model proposal is supplied, got " + recourse.origin,
        );

        # Re-run: the three paths are updated in place, never duplicated.
        repeat_run = RecommendRecourse();
        project spawn repeat_run;
        persisted = [
            path for path in [project ->: has_action_path :->]
            if isinstance(path, ActionPath)
        ];
        civic_require(
            failures,
            len(persisted) == RECOURSE_PATH_COUNT,
            project.name + ": re-running RecommendRecourse left "
            + str(len(persisted)) + " action paths on the project",
        );
        check_action_paths(failures, project.name + " (repeat)", persisted);
    }

    # --- 5. forbidden relationships ---------------------------------
    forbidden = forbidden_relation_names();
    print("--- relationship archetypes in graph ---");
    print(json.dumps({
        "relations": relation_names_in_graph(),
        "forbidden_found": forbidden,
    }, indent=2, ensure_ascii=False));
    civic_require(
        failures,
        len(forbidden) == 0,
        "Forbidden relationship present in graph: " + ", ".join(forbidden),
    );

    print("--- civic failures: " + str(len(failures)) + " ---");
    for failure in failures {
        print("  FAIL " + failure);
    }
    assert len(failures) == 0, "smoke_civic checks failed";
}
