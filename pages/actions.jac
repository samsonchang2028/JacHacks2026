"""Route an issue: map of open civic issues + verdict-first slide-in panel.

Every pin click spawns `issue_detail` against the persistent graph. There is no
mock data layer -- what the panel shows is what the walker reported.
"""

cl import from "@jac/runtime" { Link, useLocation }
cl import from ..components.IssueMap { IssueMap }
cl import from ..components.Sections { RoutePanel }

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
            # Otherwise preselect Portsmouth so the demo is never an empty panel.
            wanted = "portsmouth-square";
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

        thin_n = 0;
        for i in issues {
            if i["tier"] != "full" {
                thin_n = thin_n + 1;
            }
        }

        return
            <div className="actions-shell">
                <div className="actions-head">
                    <p className="eyebrow plain">Decision routing</p>
                    <h1 className="actions-h1">An objection only counts if it reaches the body that decides.</h1>
                    <p className="lead">
                        Through the channel that counts, before the deadline. Quorum traces
                        that route for an open issue and tells you where yours currently goes wrong.
                    </p>
                </div>

                <div className="actions-layout">
                    <div className="map-frame">
                        <IssueMap issues={issues} selected={selected} on_select={choose}/>
                        <div className="map-legend">
                            <span><i className="legend-dot full"></i> Routed: full procedural record</span>
                            <span><i className="legend-dot thin"></i> Tracked from 311 / Legistar</span>
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
                                    <RoutePanel detail={detail}/>
                                </div>

                                <div className="panel-foot">
                                    {
                                        <Link className="btn btn-primary full-workup" to={"/issue/" + detail["slug"]}>
                                            See the full route ↓
                                        </Link>
                                        if detail["found"] and detail["tier"] == "full" else
                                        <p className="panel-thin">
                                            No verified procedural record yet. Quorum will not route an issue it cannot source.
                                        </p>
                                    }
                                </div>
                            </>
                        }
                    </aside>
                </div>

                {
                    <p className="thin-note">
                        {str(thin_n) + " more issues tracked from 311 and Legistar, with "}
                        <b>no verified procedural record yet</b>
                        . Quorum will not route an issue it cannot source.
                    </p>
                    if thin_n > 0 else <></>
                }
            </div>;
    }
}
