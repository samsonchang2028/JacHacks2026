"""Decision-routing page for one issue.

Order from the actions-detail mockup: verdict → route → validity → next steps
→ collapsed background / sources. Graph traversal is demoted under Sources.
"""

cl import from "@jac/runtime" { Link, useParams }
cl import from ...components.Sections {
    VerdictBlock, RoutePath, ValidityGrid, NextSteps,
    BackgroundContext, SourcesTable, TraversalPanel,
    RecordWall, SignalList, OutreachList, PipelineRecord
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

        if detail["tier"] != "full" {
            return
                <div className="actions-shell">
                    <Link className="back-link" to="/actions">← Back to the map</Link>
                    <p className="eyebrow plain">Tracked, not yet routed</p>
                    <h1 className="actions-h1">{detail["title"]}</h1>
                    <p className="lead">
                        This issue is tracked from 311 / Legistar, but Quorum has no verified
                        procedural record yet. Quorum will not route an issue it cannot source.
                    </p>
                </div>;
        }

        correction_h = "";
        if detail["divergence"] {
            correction_h = detail["divergence"]["correction_h"];
        }

        return
            <div className="workup">
                <Link className="back-link" to="/actions">← Back to the map</Link>

                <div className="workup-head">
                    <p className="eyebrow plain">Decision routing</p>
                    <p className="panel-district">{detail["district"]}</p>
                    <h1 className="actions-h1">{detail["title"]}</h1>
                </div>

                <VerdictBlock detail={detail}/>

                <section className="band">
                    <p className="eyebrow plain">The route</p>
                    <h2>Where your input has to arrive</h2>
                    <p className="band-lead">
                        One hop at a time, as retrieved from the record, not a network diagram.
                        Each step names the next thing that must be true for your objection to be counted.
                    </p>
                    <RoutePath route={detail["route"]}/>
                </section>

                <section className="band">
                    <p className="eyebrow plain">Validity</p>
                    <h2>What counts as input here</h2>
                    <p className="band-lead">
                        The channel has rules. Effort that does not meet them is not counted,
                        however much of it there is.
                    </p>
                    <ValidityGrid counts={detail["counts"]} not_counts={detail["not_counts"]}/>
                </section>

                {
                    <section className="band">
                        <p className="eyebrow plain">The record</p>
                        <h2>What the pipeline retrieved</h2>
                        <p className="band-lead">
                            Statements and community signal collected for this case by the
                            ingestion pipeline — press, in-language news, public forums —
                            each with its source. None of it is a countable submission yet;
                            the route above is how it becomes one.
                        </p>
                        <RecordWall testimony={detail["testimony"]}/>
                        <SignalList signals={detail["signals"]}/>
                    </section>
                    if len(detail["testimony"]) + len(detail["signals"]) > 0 else <></>
                }

                <NextSteps actions={detail["actions"]} correction_h={correction_h}/>

                <section className="band tight">
                    <p className="eyebrow plain">Background</p>
                    <div className="context-stack">
                        <BackgroundContext
                            problem={detail["problem"]}
                            organizers={detail["organizers"]}
                            precedents={detail["precedents"]}
                        />
                        <OutreachList outreach={detail["outreach"]}/>
                        <SourcesTable sources={detail["sources"]}/>
                        <PipelineRecord pipeline={detail["pipeline"]}/>
                        <TraversalPanel path={detail["path"]}/>
                    </div>
                </section>
            </div>;
    }
}
