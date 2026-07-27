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
    if retrieved_at == "" {
        return <span className="chip">{source_url}</span>;
    }
    return <span className="chip">{source_url} · retrieved {retrieved_at}</span>;
}

def:pub StatusPill(kind: str, label: str) -> JsxElement {
    return <span className={"pill " + kind}>{label}</span>;
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

# Verdict-first panel body: pill, headline, decides / channel / deadline, first step.
def:pub RoutePanel(detail: any) -> JsxElement {
    div = detail["divergence"];
    resources = detail["resources"];
    actions = detail["actions"];

    decides = "";
    channel = "";
    for r in resources {
        if r["label"] == "Who decides" {
            decides = r["value"];
        }
        if r["label"] == "Channel that counts" {
            channel = r["value"];
        }
    }

    # Seed always appends the deadline last.
    deadline_verified = False;
    deadline_value = "";
    if len(resources) > 0 {
        last = resources[len(resources) - 1];
        deadline_verified = last["source_url"] != "";
        deadline_value = last["value"];
    }

    pill = <></>;
    headline = "";
    if div {
        if div["kind"] == "electorate" {
            pill = <StatusPill kind="bad" label="Zone mismatch"/>;
        } else {
            pill = <StatusPill kind="warn" label="Record failure"/>;
        }
        headline = div["headline"];
    }

    first_action = "";
    if len(actions) > 0 {
        first_action = actions[0]["what"];
    }

    return
        <>
            {pill}
            {
                <p className="panel-verdict"><b>{headline}</b></p>
                if headline != "" else <></>
            }
            <p className={"panel-verdict muted" if headline != "" else "panel-verdict"}>
                {detail["short"] if detail["short"] != "" else "No procedural record retrieved for this issue yet."}
            </p>

            {
                <div className="panel-sec">
                    <div className="kv-row">
                        <span className="kv-label">Decides</span>
                        <span className="kv-value">{decides if decides != "" else "—"}</span>
                    </div>
                    <div className="kv-row">
                        <span className="kv-label">Channel</span>
                        <span className="kv-value">{channel if channel != "" else "—"}</span>
                    </div>
                    <div className="kv-row">
                        <span className="kv-label">Deadline</span>
                        <span className="kv-value">
                            {
                                <StatusPill kind="warn" label="Not verified"/>
                                if not deadline_verified else deadline_value
                            }
                        </span>
                    </div>
                    {
                        <div className="kv-row">
                            <span className="kv-label">On record</span>
                            <span className="kv-value">
                                {str(len(detail["testimony"])) + " statements · " + str(len(detail["signals"])) + " community threads"}
                            </span>
                        </div>
                        if len(detail["testimony"]) + len(detail["signals"]) > 0 else <></>
                    }
                </div>
                if detail["tier"] == "full" else <></>
            }

            {
                <div className="panel-sec">
                    <span className="eyebrow plain">Do this first</span>
                    <p className="panel-verdict">{first_action}</p>
                </div>
                if first_action != "" else <></>
            }
        </>;
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

# ---- decision-routing page ---------------------------------------------

def:pub VerdictBlock(detail: any) -> JsxElement {
    div = detail["divergence"];
    if not div {
        return <></>;
    }

    zones_ok = detail["zones_match"];
    state = "match" if zones_ok else "mismatch";
    eyebrow = "⚠ Divergence: electorate" if div["kind"] == "electorate" else "⚠ Divergence: channel";
    match_label = "Zones match" if zones_ok else "Do not match";
    glyph = "＝" if zones_ok else "≠";

    impact = detail["impact_zone"];
    decision = detail["decision_zone"];

    return
        <section className={"verdict " + state} role="alert" id="verdict">
            <div className="verdict-head">
                <p className="eyebrow plain">{eyebrow}</p>
                <h2>{div["headline"]}</h2>
                <p className="why">{div["why"]}</p>
            </div>

            <div className="zones">
                <div className="zone impact">
                    <p className="eyebrow plain">Impact lands on</p>
                    <div className="zv">{impact}</div>
                    <div className="zm">GeoZone · reached via impacts</div>
                </div>
                <div className={"zone-verdict " + ("yes" if zones_ok else "no")}>
                    <span className="glyph">{glyph}</span>
                    <span className="lbl">{match_label}</span>
                </div>
                <div className="zone decision">
                    <p className="eyebrow plain">Decided by</p>
                    <div className="zv">{decision}</div>
                    <div className="zm">via accountable_to</div>
                </div>
            </div>

            {
                <div className="correction">
                    <span className="ico" aria-hidden="true">→</span>
                    <div>
                        <h3>Recommended correction</h3>
                        <p>{div["correction_p"]}</p>
                        <p className="correction-h"><b>{div["correction_h"]}</b></p>
                    </div>
                </div>
                if div["correction_h"] != "" else <></>
            }
        </section>;
}

def:pub RoutePath(route: list) -> JsxElement {
    if len(route) == 0 {
        return <></>;
    }
    return
        <div className="route-path">
            {[
                <div className="hop-block" key={"hop-" + str(idx)}>
                    {<div className="hop-link" aria-hidden="true"></div> if idx > 0 else <></>}
                    <div className={"hop is-deadline" if hop["deadline"] else "hop"}>
                        <div className="hop-n">{idx + 1}</div>
                        <div>
                            <div className="hop-role">{hop["role"]}</div>
                            <div className="hop-name">{hop["name"]}</div>
                            <div className="hop-note">
                                {
                                    <span>
                                        <StatusPill kind="warn" label="Not verified"/>
                                        {" " + hop["note"]}
                                    </span>
                                    if hop["unverified"] else hop["note"]
                                }
                            </div>
                        </div>
                        <span className="hop-edge">{hop["edge"]}</span>
                    </div>
                </div>
                for (idx, hop) in enumerate(route)
            ]}
        </div>;
}

def:pub ValidityGrid(counts: list, not_counts: list) -> JsxElement {
    if len(counts) == 0 and len(not_counts) == 0 {
        return <></>;
    }
    return
        <div className="counts-grid">
            <div className="card">
                <h3>Counts as input</h3>
                <ul className="tick yes">
                    {[<li key={"c-" + str(i)}>{c}</li> for (i, c) in enumerate(counts)]}
                </ul>
            </div>
            <div className="card">
                <h3>Does not count</h3>
                <ul className="tick no">
                    {[<li key={"n-" + str(i)}>{c}</li> for (i, c) in enumerate(not_counts)]}
                </ul>
            </div>
        </div>;
}

def:pub NextSteps(actions: list, correction_h: str) -> JsxElement {
    if len(actions) == 0 {
        return <></>;
    }
    return
        <section className="band" id="steps">
            <p className="eyebrow plain">Do this next</p>
            <h2>{correction_h if correction_h != "" else "The correction"}</h2>
            <div className="next-steps">
                {[
                    <div className="next-step" key={a["rank"]}>
                        <div className="step-n">{a["rank"]}</div>
                        <div>
                            <div className="step-what">{a["what"]}</div>
                            <div className="step-how">{a["how"]}</div>
                        </div>
                    </div>
                    for a in actions
                ]}
            </div>
        </section>;
}

def:pub BackgroundContext(
    problem: str,
    organizers: list,
    precedents: list
) -> JsxElement {
    return
        <>
            {
                <details className="ctx" key="problem">
                    <summary>The problem</summary>
                    <div className="ctx-body"><p>{problem}</p></div>
                </details>
                if problem != "" else <></>
            }
            {
                <details className="ctx" key="orgs">
                    <summary>Organizers already working on this</summary>
                    <div className="ctx-body">
                        {[
                            <div className="org" key={o["name"]}>
                                <div className="org-avatar">{o["initials"]}</div>
                                <div>
                                    <div className="org-name">
                                        {o["name"]}
                                        <span className="lang-tag">{o["language"]}</span>
                                        <ProcessPill inside_process={o["inside_process"]}/>
                                    </div>
                                    <div className="org-role">{o["role"]}</div>
                                    {
                                        <span className="chip">{o["contact"]}</span>
                                        if o["contact"] != "" else <></>
                                    }
                                </div>
                            </div>
                            for o in organizers
                        ]}
                    </div>
                </details>
                if len(organizers) > 0 else <></>
            }
            {
                <details className="ctx" key="prec">
                    <summary>Precedent: what moved and what did not</summary>
                    <div className="ctx-body">
                        {[
                            <div className="prec" key={p["title"]}>
                                <div className="prec-title">{p["title"]}</div>
                                <div className="prec-meta">
                                    <b>Channel:</b> {p["channel_used"]}. {p["summary"]}
                                </div>
                                <div className="prec-outcome">
                                    <StatusPill
                                        kind={"ok" if p["outcome"] == "win" else "bad"}
                                        label={"Moved the outcome" if p["outcome"] == "win" else "Did not move it"}
                                    />
                                </div>
                            </div>
                            for p in precedents
                        ]}
                    </div>
                </details>
                if len(precedents) > 0 else <></>
            }
        </>;
}

def:pub SourcesTable(sources: list) -> JsxElement {
    if len(sources) == 0 {
        return <></>;
    }
    ok = 0;
    for s in sources {
        if s["verified"] {
            ok = ok + 1;
        }
    }
    n = len(sources);
    gap = n - ok;

    return
        <details className="ctx" id="sources">
            <summary>
                Sources and verification{" "}
                <StatusPill
                    kind={"ok" if ok == n else "warn"}
                    label={str(ok) + " of " + str(n) + " verified"}
                />
            </summary>
            <div className="ctx-body">
                <div className="src-scroll">
                    <table className="src">
                        <thead>
                            <tr>
                                <th>Fact</th>
                                <th>Source</th>
                                <th>Retrieved</th>
                                <th>Status</th>
                            </tr>
                        </thead>
                        <tbody>
                            {[
                                <tr key={str(i)}>
                                    <td className="fact">{s["fact"]}</td>
                                    <td>{s["source"]}</td>
                                    <td>{s["retrieved"]}</td>
                                    <td>
                                        <StatusPill
                                            kind={"ok" if s["verified"] else "warn"}
                                            label={"Verified" if s["verified"] else "Not verified"}
                                        />
                                    </td>
                                </tr>
                                for (i, s) in enumerate(sources)
                            ]}
                        </tbody>
                    </table>
                </div>
                <p className="no-guess">
                    {
                        <b>Every fact on this route is sourced and dated.</b>
                        if gap == 0 else
                        <b>
                            {"No verified source found for " + str(gap) + (" facts" if gap > 1 else " fact") + ". Quorum will not guess."}
                        </b>
                    }
                </p>
            </div>
        </details>;
}

# ---- pipeline record (out/fixture.json via the fixture bridge) ---------
# Everything below renders retrieved records with their sources. Copy is
# deliberately about *record*, never support: a statement in the press or a
# forum thread is signal that exists, not a countable submission and not an
# endorsement.

# The hand-set inside_process judgment from the pipeline ("" = no record).
def:pub ProcessPill(inside_process: str) -> JsxElement {
    if inside_process == "true" {
        return <StatusPill kind="info" label="Inside the process"/>;
    }
    if inside_process == "false" {
        return <StatusPill kind="warn" label="Outside the process"/>;
    }
    return <></>;
}

# A testimony kind is a category, not a verdict. The one colour judgment:
# counterargument gets the warn tint because it is the record speaking back.
def:pub KindPill(kind: str) -> JsxElement {
    if kind == "counterargument" {
        return <StatusPill kind="warn" label="counterargument"/>;
    }
    if kind == "evidence" {
        return <StatusPill kind="ok" label="evidence"/>;
    }
    return <StatusPill kind="info" label={kind}/>;
}

def:pub RecordWall(testimony: list) -> JsxElement {
    if len(testimony) == 0 {
        return <></>;
    }
    return
        <div className="record-wall">
            {[
                <article className="quote" key={"q-" + str(i)}>
                    <div className="quote-head">
                        <KindPill kind={t["kind"]}/>
                        <span className="quote-speaker">{t["speaker"]}</span>
                        {
                            <span className="lang-tag">中文</span>
                            if t["language"] == "zh" else <></>
                        }
                    </div>
                    <p className="quote-claim">{t["claim"]}</p>
                    <div className="quote-meta">
                        {
                            <span className="quote-affil">{t["affiliation"]}</span>
                            if t["affiliation"] != "" and t["affiliation"] != t["speaker"] else <></>
                        }
                        <CitationChip source_url={t["source_url"]} retrieved_at=""/>
                    </div>
                </article>
                for (i, t) in enumerate(testimony)
            ]}
        </div>;
}

def:pub SignalList(signals: list) -> JsxElement {
    if len(signals) == 0 {
        return <></>;
    }
    return
        <div className="signal-list">
            <p className="signal-caption">
                Community forum signal, one row per thread. Volume here is
                context — none of it reaches an official record.
            </p>
            {[
                <div className="sig-row" key={"sig-" + str(i)}>
                    <span className="sig-count">
                        {str(s["count"])}<i>comments</i>
                    </span>
                    <div>
                        <p className="sig-summary">{s["summary"]}</p>
                        <CitationChip source_url={s["source_url"]} retrieved_at=""/>
                    </div>
                </div>
                for (i, s) in enumerate(signals)
            ]}
        </div>;
}

# Orgs from the pipeline's contact research, mapped by the case manifest's
# own candidate list. A listing means reachable, never "supports this".
def:pub OutreachList(outreach: list) -> JsxElement {
    if len(outreach) == 0 {
        return <></>;
    }
    return
        <details className="ctx" key="outreach">
            <summary>Reachable organizations — pipeline contact research</summary>
            <div className="ctx-body">
                <p className="muted">
                    Named as research candidates in this case's manifest, then
                    resolved to an org-level contact — or an explicit blank with
                    where the pipeline looked. A listing implies reachability,
                    not a position on this issue.
                </p>
                {[
                    <div className="org" key={o["name"]}>
                        <div className="org-avatar">{o["initials"]}</div>
                        <div>
                            <div className="org-name">
                                {o["name"]}
                                {
                                    <span className="lang-tag">中文</span>
                                    if o["language"] == "zh" else <></>
                                }
                                <ProcessPill inside_process={o["inside_process"]}/>
                            </div>
                            <div className="org-role">{o["community"]}</div>
                            {
                                <span className="chip">{o["contact"]}</span>
                                if o["contact"] != "" else
                                <span className="chip gap">no org-level contact found</span>
                            }
                            {
                                <div className="org-notes">{o["notes"]}</div>
                                if o["notes"] != "" and o["contact"] == "" else <></>
                            }
                        </div>
                    </div>
                    for o in outreach
                ]}
            </div>
        </details>;
}

# Artifact-wide provenance: what out/fixture.json holds, including the
# verified channels that are deliberately bound to no decision body -- the
# fixture contract carries no such binding, so the UI shows the gap rather
# than a guessed edge.
def:pub PipelineRecord(pipeline: any) -> JsxElement {
    if not pipeline["loaded"] {
        return
            <details className="ctx" id="pipeline">
                <summary>
                    Pipeline record{" "}
                    <StatusPill kind="warn" label="Not loaded"/>
                </summary>
                <div className="ctx-body">
                    <p className="muted">
                        The ingestion artifact (out/fixture.json) was not found, so
                        this page shows the curated seed only. Run the pipeline and
                        reload with a fresh graph to attach it.
                    </p>
                </div>
            </details>;
    }
    return
        <details className="ctx" id="pipeline">
            <summary>
                Pipeline record — out/fixture.json{" "}
                <StatusPill kind="ok" label="Loaded"/>
            </summary>
            <div className="ctx-body">
                <p className="muted">
                    {"Attached from the ingestion artifact: "
                        + str(pipeline["testimony_n"]) + " testimony records, "
                        + str(pipeline["signal_n"]) + " forum threads, "
                        + str(pipeline["org_n"]) + " organizations, and "
                        + str(pipeline["channel_n"]) + " verified comment channels across both cases."}
                </p>
                {[
                    <div className="pipe-chan" key={"ch-" + str(i)}>
                        <div className="pipe-chan-name">{c["recipient"]}</div>
                        <div className="pipe-chan-meta">
                            <b>{c["method"]}</b>{" — " + c["format_note"]}
                        </div>
                        <div className="pipe-chan-meta">Languages: {c["languages"]}</div>
                        <div className="pipe-chan-meta">
                            {"Deadline (" + c["deadline_kind"] + "): "}
                            {
                                <span className="chip gap">recorded as unknown at source — not guessed</span>
                                if c["deadline_date"] == "unknown" else c["deadline_date"]
                            }
                        </div>
                        <CitationChip source_url={c["source_url"]} retrieved_at=""/>
                    </div>
                    for (i, c) in enumerate(pipeline["channels"])
                ]}
                <p className="no-guess">
                    <b>
                        No channel above is bound to this issue's decision body.
                        The fixture contract carries no channel-to-body link, so
                        Quorum reports that binding as a gap instead of guessing it.
                    </b>
                </p>
            </div>
        </details>;
}

# ---- legacy helpers still used in a few places -------------------------

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

# Demoted: kept for optional expand under Sources, not the primary flow.
def:pub TraversalPanel(path: list) -> JsxElement {
    if len(path) == 0 {
        return <></>;
    }
    return
        <details className="ctx">
            <summary>Graph traversal — how this answer was reached</summary>
            <div className="ctx-body">
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
            </div>
        </details>;
}
