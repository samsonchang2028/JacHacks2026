"""Landing page: the thesis + impact vs decision demo moment."""

cl import from "@jac/runtime" { Link }
cl import from ..components.HeroMap { HeroMap }

cl {
    def:pub page -> JsxElement {
        return
            <div className="hero-grid">
                <div className="hero-copy">
                    <p className="eyebrow">Quorum</p>
                    <h1>Make community objections count.</h1>
                    <p className="lead">Who decides, what action counts, and where your community's effort should go - especially when the impact zone and the decision zone are not the same place.</p>

                    <div className="hero-actions" aria-label="Primary actions">
                        <Link
                            className="case-button active"
                            to="/actions?case=portsmouth-square"
                        >
                            Analyse a civic action
                        </Link>
                        <Link className="case-button" to="/how">
                            See how it works
                        </Link>
                    </div>
                    <div className="hero-secondary" aria-label="Other demo paths">
                        <Link className="text-button" to="/actions?case=prop-k">
                            Or try Proposition K
                        </Link>
                        <Link className="text-button" to="/actions">
                            See every open issue
                        </Link>
                    </div>

                    <div className="value-points" aria-label="What Quorum returns">
                        <article>
                            <span>1</span>
                            <strong>Who decides</strong>
                            <small>The body or electorate that controls the outcome</small>
                        </article>
                        <article>
                            <span>2</span>
                            <strong>What counts</strong>
                            <small>The verified channel and deadline the record accepts</small>
                        </article>
                        <article>
                            <span>3</span>
                            <strong>Where effort goes</strong>
                            <small>Impact zone vs decision zone - reroute when they diverge</small>
                        </article>
                    </div>
                </div>

                <div
                    className="map-visual"
                    aria-label="Illustration: Chinatown impact zone inside a wider decision zone that answers elsewhere"
                >
                    <div className="map-base">
                        <HeroMap/>
                        <div className="decision-ring" aria-hidden="true">
                            <span className="zone-tag decision">Decision zone</span>
                        </div>
                        <div className="impact-ring" aria-hidden="true">
                            <span className="zone-tag impact">Impact zone</span>
                        </div>
                        <div className="map-pin" aria-hidden="true"></div>
                        <aside className="floating-card">
                            <small>Divergence</small>
                            <strong>Impact zone is not the decision zone</strong>
                            <span>Your outreach is aimed at people who already agree</span>
                        </aside>
                    </div>
                </div>
            </div>;
    }
}
