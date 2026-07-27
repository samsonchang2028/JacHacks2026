"""Decision-routing page for one issue.

Order: briefing → verdict → the record → next steps → collapsed background /
sources. The route and validity bands were cut for length -- their content
still reaches the reader through the briefing card (which summarizes route,
counts, and not-counts), the actions panel's decides/channel/deadline rows,
and the sources table. Graph traversal is demoted under Sources.
"""

cl import from "@jac/runtime" { Link, useParams }
cl import from ...components.Sections {
    VerdictBlock, NextSteps,
    BackgroundContext, SourcesTable, TraversalPanel,
    RecordWall, SignalList, OutreachList, PipelineRecord,
    BriefingCard, BriefingPending, PacketBand
}

cl {
    def:pub page -> JsxElement {
        has detail: any = None,
            brief: any = None,
            drafts: list = [],
            drafting: str = "";

        params = useParams();
        slug = params.id;

        async can with entry {
            root spawn seed_graph();
            picked = root spawn issue_detail(slug=slug);
            # Set the workup first so the page renders; the briefing follows
            # (instant when out/reports/<slug>.json is cached, a live LLM
            # run when it is not).
            detail = picked.reports[0];
            briefed = root spawn issue_report(slug=slug);
            brief = briefed.reports[0];
        }

        # One outreach draft at a time: instant when staged on disk, a live
        # LLM run (tens of seconds) when not. Nothing is ever sent.
        async def make_draft(org_name: str) -> None {
            if drafting != "" {
                return;
            }
            drafting = org_name;
            got = root spawn outreach_email(slug=slug, org_name=org_name);
            drafts = drafts + [got.reports[0]];
            drafting = "";
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

                {<BriefingCard brief={brief}/> if brief else <BriefingPending/>}

                <VerdictBlock detail={detail}/>

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

                <PacketBand
                    packet_orgs={detail["packet_orgs"]}
                    drafts={drafts}
                    drafting={drafting}
                    on_draft={make_draft}
                />

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
