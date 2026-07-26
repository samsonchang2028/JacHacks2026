"""Shared panel/page sections.

Every one takes `compact` so the slide-in panel and the full issue page render
the same code at two densities -- written once, not twice.

ponytail: all sections in one file. They are small and always change together.
"""

# A fact with no source renders a visible gap, never a plausible guess.
# (Comment, not a docstring: a bare string followed by `if` parses as a ternary.)
def:pub CitationChip(source_url: str, retrieved_at: str) -> JsxElement {
    if source_url == "" {
        return <span className="chip gap">no record retrieved — not generated</span>;
    }
    return <span className="chip">{source_url} · retrieved {retrieved_at}</span>;
}

# Compact in the panel (headline + zones only); the explanation belongs on the
# workup page, where the reader has already chosen to go deeper.
def:pub DivergenceBanner(divergence: any, compact: bool) -> JsxElement {
    if not divergence {
        return <></>;
    }
    note = "The impact zone and the decision zone are different graphs. Outreach aimed at the impact zone reaches people who already agree." if divergence["kind"] == "electorate" else "The community holds a position, but it is not reaching the channel that counts.";
    return
        <div className="divergence" role="alert">
            <strong>⚠ Your effort is aimed at the wrong people</strong>
            {<></> if compact else <p>{note}</p>}
            <div className="zones">
                <span>Impact: {divergence["impact"]}</span>
                <span>Decides: {divergence["decision"]}</span>
            </div>
        </div>;
}

# ---- panel-only, deliberately lean -------------------------------------

def:pub PanelSummary(short: str) -> JsxElement {
    if short == "" {
        return
            <div className="panel-section">
                <p className="summary muted">No procedural record retrieved for this issue yet.</p>
            </div>;
    }
    return
        <div className="panel-section">
            <p className="summary">{short}</p>
        </div>;
}

# Two rows: who decides, and the next deadline. Everything else waits.
def:pub KeyFacts(resources: list) -> JsxElement {
    if len(resources) == 0 {
        return <></>;
    }
    decides = resources[0];
    due = resources[len(resources) - 1];
    return
        <div className="panel-section">
            <div className="kv">
                <div className="kv-row">
                    <span className="kv-label">Decides</span>
                    <span className="kv-value">{decides["value"]}</span>
                </div>
                <div className="kv-row">
                    <span className="kv-label">{due["label"]}</span>
                    <span className="kv-value">
                        {
                            <span className="chip gap">no record retrieved</span>
                            if due["source_url"] == "" else due["value"]
                        }
                    </span>
                </div>
            </div>
        </div>;
}

def:pub OrgChips(organizers: list) -> JsxElement {
    if len(organizers) == 0 {
        return <></>;
    }
    return
        <div className="panel-section">
            <h3>Already organizing</h3>
            <div className="org-chips">
                {[<span className="org-chip" key={o["name"]}>{o["name"]}</span> for o in organizers]}
            </div>
        </div>;
}

def:pub ProblemBrief(problem: str, srcs: list, compact: bool) -> JsxElement {
    if problem == "" {
        return
            <div className="panel-section">
                <h3>The problem</h3>
                <p className="muted">No procedural record retrieved for this issue yet.</p>
            </div>;
    }
    return
        <div className="panel-section">
            <h3>The problem</h3>
            <p>{problem}</p>
            <div className="sources">
                <h4>Sources</h4>
                <ol>
                    {[<li key={s}>{s} <span className="src-date">· retrieved 2026-07-26</span></li> for s in srcs]}
                </ol>
            </div>
        </div>;
}

def:pub OrganizerList(organizers: list, compact: bool) -> JsxElement {
    if len(organizers) == 0 {
        return <></>;
    }
    shown = organizers[:3] if compact else organizers;
    return
        <div className="panel-section">
            <h3>Organizers already working on this</h3>
            {[
                <div className="org" key={o["name"]}>
                    <div className="org-avatar">{o["initials"]}</div>
                    <div>
                        <div className="org-name">
                            {o["name"]}
                            <span className="lang-tag">{o["language"]}</span>
                        </div>
                        <div className="org-role">{o["role"]}</div>
                    </div>
                </div>
                for o in shown
            ]}
        </div>;
}

def:pub ResourceList(resources: list, compact: bool) -> JsxElement {
    if len(resources) == 0 {
        return <></>;
    }
    return
        <div className="panel-section">
            <h3>Resources — what actually counts</h3>
            {[
                <div className="res" key={r["label"]}>
                    <div className="res-label">{r["label"]}</div>
                    <div className="res-value">{r["value"]}</div>
                    <CitationChip
                        source_url={r["source_url"]}
                        retrieved_at={r["retrieved_at"]}
                    />
                </div>
                for r in resources
            ]}
        </div>;
}

def:pub PrecedentList(precedents: list, compact: bool) -> JsxElement {
    if len(precedents) == 0 {
        return <></>;
    }
    shown = precedents[:2] if compact else precedents;
    return
        <div className="panel-section">
            <h3>Precedent cases</h3>
            {[
                <div className="prec" key={p["title"]}>
                    <div className="prec-title">{p["title"]}</div>
                    <div className="prec-meta">
                        <b>Channel:</b> {p["channel_used"]}. {p["summary"]}
                    </div>
                    <span className={"outcome " + p["outcome"]}>
                        {"moved the outcome" if p["outcome"] == "win" else "did not move it"}
                    </span>
                    <div>
                        <CitationChip
                            source_url={p["source_url"]}
                            retrieved_at={p["retrieved_at"]}
                        />
                    </div>
                </div>
                for p in shown
            ]}
        </div>;
}

def:pub ActionList(actions: list, compact: bool) -> JsxElement {
    if len(actions) == 0 {
        return <></>;
    }
    return
        <div className="panel-section">
            <h3>{"How to help" if compact else "Suggested actions"}</h3>
            {[
                <div className="act" key={a["rank"]}>
                    <div className="act-rank">{a["rank"]}</div>
                    <div>
                        <div className="act-what">{a["what"]}</div>
                        {<></> if compact else <div className="act-how">{a["how"]}</div>}
                    </div>
                </div>
                for a in actions
            ]}
        </div>;
}

# The nodes the walker actually visited, hop by hop. Not a diagram of the
# schema -- the real path `issue_detail` took, reported back from the spawn.
def:pub TraversalPanel(path: list) -> JsxElement {
    if len(path) == 0 {
        return <></>;
    }
    return
        <div className="panel-section">
            <h3>Graph traversal — how this answer was reached</h3>
            <p className="muted">
                Each hop is a node the walker visited. The divergence answer
                lives in no single node: it is the comparison of two terminal
                zones reached by two different edges.
            </p>
            <ol className="trace">
                {[
                    <li key={str(idx) + p["kind"]}>
                        <span className="trace-edge">{p["via"]}</span>
                        <span className="trace-kind">{p["kind"]}</span>
                        <span className="trace-label">{p["label"]}</span>
                    </li>
                    for (idx, p) in enumerate(path)
                ]}
            </ol>
        </div>;
}
