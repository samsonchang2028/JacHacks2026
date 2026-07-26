"""Landing: hero, the problem, the solution, what is pressing now.

The pressing-now feed spawns `find_issues` against the real graph rather than
rendering fixture counts. Record/source-type totals are deliberately absent --
the only Concern nodes in the graph are unverified community notes, and
counting those as issue signal would break the retrieved-not-generated rule the
page itself advertises.
"""

cl import from "@jac/runtime" { Link }
cl import from ..components.HeroMap { HeroMap }
cl import from ..components.ProblemCharts { ProblemCharts }

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

                <section className="hero" id="top">
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
                            <a className="btn btn-ghost" href="#solution">See how it works</a>
                        </div>
                    </div>
                </section>

                <section className="problem" id="problem">
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

                    <ProblemCharts/>
                </section>

                <section className="solution" id="solution">
                    <h2>Quorum puts the whole picture in one place.</h2>
                    <p className="section-lead">Scattered signal in. One countable action out.</p>

                    <div className="steps">
                        <article className="step">
                            <div className="step-n">1</div>
                            <h3>Aggregate</h3>
                            <p>311, agendas, press and community records — deduplicated into one issue.</p>
                        </article>
                        <article className="step">
                            <div className="step-n">2</div>
                            <h3>Find who decides</h3>
                            <p>The body that approves it, and who that body answers to.</p>
                        </article>
                        <article className="step">
                            <div className="step-n">3</div>
                            <h3>Retrieve what counts</h3>
                            <p>Channel, format and deadline — each with a source and a date.</p>
                        </article>
                        <article className="step">
                            <div className="step-n">4</div>
                            <h3>Aim it</h3>
                            <p>Impact zone vs decision zone. When they differ, re-aim.</p>
                        </article>
                    </div>

                    <div className="rule-strip">
                        <span><b>Retrieved, never generated.</b> No source, no claim — Quorum shows a gap instead of a guess.</span>
                    </div>
                </section>

                <section className="pressing" id="pressing">
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
                                    {"Full record" if i["tier"] == "full" else "Monitoring"}
                                </span>
                            </Link>
                            for i in issues
                        ]}
                    </div>

                    <div className="feed-foot">
                        <p className="feed-note">Record counts land when the concern pipeline does.</p>
                        <Link className="btn btn-primary" to="/actions">Analyse a civic action</Link>
                    </div>
                </section>

            </div>;
    }
}
