"""How it works: three beats to the aha - impact zone vs decision zone."""

cl import from "@jac/runtime" { Link }

cl {
    def:pub page -> JsxElement {
        return
            <div className="actions-shell how-shell">
                <p className="eyebrow">How it works</p>
                <h2 className="section-title">From held opinion to countable input</h2>
                <p className="lead">Three moves. About a minute. Then open a real case.</p>

                <ol className="how-steps">
                    <li className="how-step">
                        <span className="how-num">1</span>
                        <div>
                            <h3>Ingest the civic action</h3>
                            <p>Issue records, institutions, and narratives attach to a Jac graph. Fixtures are inputs - not precomputed answers.</p>
                        </div>
                    </li>
                    <li className="how-step">
                        <span className="how-num">2</span>
                        <div>
                            <h3>Walk who decides and who is affected</h3>
                            <p>DecisionWalker finds the body, channel, and deadline. ImpactWalker finds the affected zone and organizers who can mobilize them.</p>
                        </div>
                    </li>
                    <li className="how-step">
                        <span className="how-num">3</span>
                        <div>
                            <h3>Catch divergence before the post-mortem</h3>
                            <p>If the impact zone and the decision zone differ, Quorum warns and reroutes outreach to whoever actually controls the outcome.</p>
                        </div>
                    </li>
                </ol>

                <div className="how-actions" aria-label="Try a case">
                    <Link
                        className="case-button active"
                        to="/actions?case=portsmouth-square"
                    >
                        Analyse Portsmouth Square
                    </Link>
                    <Link className="case-button" to="/actions?case=prop-k">
                        Analyse Proposition K
                    </Link>
                    <Link className="text-button" to="/actions">
                        Skip to every open issue
                    </Link>
                </div>
            </div>;
    }
}
