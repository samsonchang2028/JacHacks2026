"""Find Actions: map of open civic issues + slide-in issue panel.

Every pin click spawns `issue_detail` against the persistent graph. There is no
mock data layer -- what the panel shows is what the walker reported.
"""

cl import from "@jac/runtime" { Link, useLocation }
cl import from ..components.IssueMap { IssueMap }
cl import from ..components.Sections {
    DivergenceBanner, PanelSummary, KeyFacts, ActionList
}

cl {
    def:pub page -> JsxElement {
        has issues: list = [],
            detail: any = None,
            selected: str = "",
            loading: bool = False;

        location = useLocation();

        async can with entry {
            root spawn seed_graph();
            found = root spawn find_issues();
            issues = found.reports[0];

            # The hero links here as /actions?case=<slug>; honour it if present.
            wanted = "";
            if location.search.startswith("?case=") {
                wanted = location.search[6:];
            }
            if wanted != "" {
                selected = wanted;
                loading = True;
                picked = root spawn issue_detail(slug=wanted);
                detail = picked.reports[0];
                loading = False;
            }
        }

        async def choose(slug: str) -> None {
            selected = slug;
            loading = True;
            picked = root spawn issue_detail(slug=slug);
            detail = picked.reports[0];
            loading = False;
        }

        return
            <div className="actions-shell">
                <div className="actions-head">
                    <h2 className="section-title">Open issues across San Francisco</h2>
                    <p className="lead">Click a pin. Coral pins have a full procedural record.</p>
                </div>

                <div className="actions-layout">
                    <div className="map-frame">
                        <IssueMap issues={issues} selected={selected} on_select={choose}/>
                        <div className="map-legend">
                            <span><i className="legend-dot full"></i> Full workup</span>
                            <span><i className="legend-dot thin"></i> Seeded from 311 / Legistar</span>
                        </div>
                    </div>

                    <aside className="issue-panel">
                        {
                            <div className="panel-loading" role="status" aria-live="polite">
                                <p>Reading the graph for this issue...</p>
                            </div>
                            if loading else <></>
                        }
                        {
                            <div className="panel-empty">
                                <p>Select an issue on the map to see who decides, what counts, and where your effort should go.</p>
                            </div>
                            if not detail else
                            <>
                                <div className="panel-head">
                                    <div className="panel-district">{detail["district"]}</div>
                                    <h3 className="panel-title">{detail["title"]}</h3>
                                </div>

                                <div className="panel-body">
                                    <DivergenceBanner
                                        divergence={detail["divergence"]}
                                        compact={True}
                                    />
                                    <PanelSummary short={detail["short"]}/>
                                    <KeyFacts resources={detail["resources"]}/>
                                    <ActionList actions={detail["actions"]} compact={True}/>
                                </div>

                                <div className="panel-foot">
                                    <Link className="full-workup" to={"/issue/" + detail["slug"]}>
                                        Open full workup →
                                    </Link>
                                </div>
                            </>
                        }
                    </aside>
                </div>
            </div>;
    }
}
