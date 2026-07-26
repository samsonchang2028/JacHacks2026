"""Full workup for one issue.

Same sections as the slide-in panel, same order, at full density -- plus the
graph traversal panel, which the panel does not have room for.
"""

cl import from "@jac/runtime" { Link, useParams }
cl import from ...components.Sections {
    DivergenceBanner, ProblemBrief, OrganizerList,
    ResourceList, PrecedentList, ActionList, TraversalPanel
}

cl {
    def:pub page -> JsxElement {
        has detail: any = None;

        params = useParams();
        slug = params.id;

        async can with entry {
            root spawn seed_graph();
            picked = root spawn issue_detail(slug=slug);
            detail = picked.reports[0];
        }

        if not detail {
            return <div className="actions-shell"><p className="lead">Loading…</p></div>;
        }

        if not detail["found"] {
            return
                <div className="actions-shell">
                    <h2 className="section-title">No such issue</h2>
                    <p className="lead">Nothing in the graph matches “{slug}”.</p>
                    <Link className="text-button" to="/actions">← Back to the map</Link>
                </div>;
        }

        return
            <div className="workup">
                <Link className="back-link" to="/actions">← Back to the map</Link>

                <div className="workup-head">
                    <p className="panel-district">{detail["district"]}</p>
                    <h2 className="section-title">{detail["title"]}</h2>
                </div>

                <DivergenceBanner divergence={detail["divergence"]} compact={False}/>

                <div className="workup-body">
                    <ProblemBrief
                        problem={detail["problem"]}
                        srcs={detail["srcs"]}
                        compact={False}
                    />
                    <OrganizerList organizers={detail["organizers"]} compact={False}/>
                    <ResourceList resources={detail["resources"]} compact={False}/>
                    <PrecedentList precedents={detail["precedents"]} compact={False}/>
                    <ActionList actions={detail["actions"]} compact={False}/>
                    <TraversalPanel path={detail["path"]}/>
                </div>
            </div>;
    }
}
