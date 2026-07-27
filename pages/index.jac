"""Landing: hero, why, cases, how it works, what is pressing now, footer.

The pressing-now feed spawns `find_issues` against the real graph rather than
rendering fixture counts. Record/source-type totals are deliberately absent --
the only Concern nodes in the graph are unverified community notes, and
counting those as issue signal would break the retrieved-not-generated rule the
page itself advertises.
"""

cl import from "@jac/runtime" { Link }
cl import from ..components.HeroMap { HeroMap }
cl import from ..components.CaseStudies { CaseStudies }

cl {
    def:pub page -> JsxElement {
        has issues: list = [];

        async can with entry {
            root spawn seed_graph();
            found = root spawn find_issues();
            issues = found.reports[0];
        }

        return
            <div className="landing">

                <section className="hero" id="hero">
                    <HeroMap/>
                    <div className="hero-inner">
                        <h1>Make community objections count.</h1>
                        <p className="hero-sub">
                            Who decides, what action counts, and where your community's
                            effort should go — especially when the impact zone and the
                            decision zone are not the same place.
                        </p>
                        <div className="cta-row">
                            <Link className="btn btn-primary" to="/actions">Analyse a civic action</Link>
                            <a className="btn btn-ghost" href="#how">See how it works</a>
                        </div>
                    </div>
                </section>

                <section className="page-sec" id="why">
                    <h2>Caring is not the missing ingredient.</h2>
                    <p className="section-lead">Civic engagement fails in three ways, and they need opposite fixes.</p>

                    <div className="fail-grid">
                        <article className="fail">
                            <span className="fail-tag quiet">Heard too little</span>
                            <h3>It never becomes countable</h3>
                            <p>People hold a position and tell each other. It never reaches the channel that counts, before the deadline.</p>
                        </article>
                        <article className="fail">
                            <span className="fail-tag loud">Heard too much</span>
                            <h3>Volume arrives, standing does not</h3>
                            <p>Hundreds of near-identical letters get recognised as bulk and weighed as one. The countable unit is a distinct submitter.</p>
                        </article>
                        <article className="fail">
                            <span className="fail-tag astray">Heard by the wrong people</span>
                            <h3>Aimed at the wrong electorate</h3>
                            <p>Well-funded organising, pointed at the people already affected — who already agree — not at whoever decides.</p>
                        </article>
                    </div>
                </section>

                <section className="page-sec" id="cases">
                    <h2>Where it has already happened.</h2>
                    <p className="section-lead">Two San Francisco cases, and the evidence for each.</p>
                    <CaseStudies/>
                </section>

                <section className="page-sec" id="how">
                    <h2>Quorum puts the whole picture in one place.</h2>
                    <p className="section-lead">Scattered signal in. One countable action out.</p>

                    <div className="how-grid">
                        <aside className="inbox">
                            <span className="mini-label">Signal in</span>
                            <ul className="src-list">
                                <li>311 service records</li>
                                <li>Legistar agendas &amp; minutes</li>
                                <li>Local and in-language press</li>
                                <li>Community organisations</li>
                            </ul>
                            <p className="inbox-note">Scattered across four systems that never speak to each other.</p>
                        </aside>

                        <ol className="flow">
                            <li>
                                <span className="flow-n">1</span>
                                <h3>Aggregate</h3>
                                <p>Deduplicated into a single issue, so ten reports of one problem count as one problem.</p>
                            </li>
                            <li>
                                <span className="flow-n">2</span>
                                <h3>Find who decides</h3>
                                <p>The body that approves it — and, crucially, the constituency that body answers to.</p>
                            </li>
                            <li>
                                <span className="flow-n">3</span>
                                <h3>Retrieve what counts</h3>
                                <p>Channel, format and deadline, each carrying a source link and a retrieval date.</p>
                            </li>
                            <li>
                                <span className="flow-n">4</span>
                                <h3>Aim it</h3>
                                <p>Compare impact zone against decision zone. When they differ, say so and re-aim.</p>
                            </li>
                        </ol>

                        <aside className="outbox">
                            <span className="mini-label">Action out</span>
                            <p className="outbox-line"><b>One countable submission.</b></p>
                            <p className="outbox-note">A named body, a named channel, a dated deadline — and the people already organising alongside you.</p>
                        </aside>
                    </div>
                </section>

                <section className="page-sec" id="now">
                    <h2>What is building across San Francisco.</h2>
                    <p className="section-lead">Live from the graph. Coral rows have a full procedural record.</p>

                    <div className="feed">
                        {[
                            <Link
                                className={"feed-item hot" if i["tier"] == "full" else "feed-item"}
                                key={i["slug"]}
                                to={"/issue/" + i["slug"]}
                            >
                                <div>
                                    <div className="feed-title">{i["title"]}</div>
                                    <div className="feed-meta">{i["district"]}</div>
                                </div>
                                <span className={"status review" if i["tier"] == "full" else "status watch"}>
                                    {"Review needed" if i["tier"] == "full" else "Monitoring"}
                                </span>
                            </Link>
                            for i in issues
                        ]}
                    </div>

                    <div className="feed-foot">
                        <p className="feed-note">Record counts land when the concern pipeline does. Quorum will not invent them.</p>
                        <Link className="btn btn-primary" to="/actions">Analyse a civic action</Link>
                    </div>
                </section>

                <footer className="foot">
                    <div className="foot-wrap">
                        <div className="foot-brand">
                            <span className="brand-mark" aria-hidden="true"></span>
                            <div>
                                <strong>Quorum</strong>
                                <p>Routing community objections to the body, channel and deadline that actually count.</p>
                            </div>
                        </div>

                        <div className="foot-col">
                            <span className="mini-label">Sources</span>
                            <ul>
                                <li>SF 311 / DataSF</li>
                                <li>SF Legistar</li>
                                <li>SF Department of Elections</li>
                                <li>SF Recreation and Park</li>
                                <li>OpenStreetMap contributors, CARTO</li>
                            </ul>
                        </div>

                        <div className="foot-col">
                            <span className="mini-label">Honest limits</span>
                            <ul>
                                <li>Procedural facts are retrieved and cited, never generated.</li>
                                <li>Where no source exists, Quorum shows a gap.</li>
                                <li>Neutral on outcome. Partisan only about process.</li>
                            </ul>
                        </div>
                    </div>

                    <div className="foot-rule">
                        <span>JacHacks SF 2026</span>
                        <span>Neutral on outcome. Partisan only about process.</span>
                    </div>
                </footer>

            </div>;
    }
}
