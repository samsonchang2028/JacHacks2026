"""The two SF cases, each paired to the evidence that proves it.

Form follows the data's job:
- Prop K is polarity, so a split bar centred on the 50% line. Every westside bar
  sits left of it; the one that decided the outcome sits right.
- Portsmouth Square is a value against zero, which is a stat tile, not a chart.
  A one-bar chart of zero draws nothing.

Mark colours #de5b49 / #0b8f80 were run through the dataviz palette validator
against this surface and pass all five checks. Re-run it if the card colour changes.
"""

def VoteRow(label: str, yes: float, no: float) -> JsxElement {
    return
        <div className="bar-row">
            <span className="bar-label">{label}</span>
            <div className="track">
                <div
                    className="seg yes"
                    style={{"width": str(yes) + "%"}}
                    title={"Yes " + str(yes) + "%"}
                >
                    <span>{str(yes) + "%"}</span>
                </div>
                <div
                    className="seg no"
                    style={{"width": str(no) + "%"}}
                    title={"No " + str(no) + "%"}
                >
                    <span>{str(no) + "%"}</span>
                </div>
                <div className="fifty" aria-hidden="true"></div>
            </div>
        </div>;
}

def:pub CaseStudies -> JsxElement {
    return
        <div className="case-grid">
            <figure className="case card">
                <span className="case-where">Sunset / Richmond · Nov 2024</span>
                <p className="case-what">
                    Opponents spent $269,000, filed a CEQA challenge and won a recall.
                    They never campaigned east of West Portal — where the vote was decided.
                </p>
                <h3>Proposition K — won the westside, lost the city</h3>
                <p className="case-sub">Vote share. The line is 50%.</p>

                <div className="legend">
                    <span><i className="sw" style={{"background": "#0b8f80"}}></i> Yes</span>
                    <span><i className="sw" style={{"background": "#de5b49"}}></i> No</span>
                </div>

                <div
                    className="bars"
                    role="img"
                    aria-label="Prop K vote share: citywide 54.7% yes; Sunset 40%; Richmond 30%; Districts 1, 4, 7 and 11 combined 39%."
                >
                    <VoteRow label="Citywide" yes={54.7} no={45.3}/>
                    <VoteRow label="Sunset" yes={40} no={60}/>
                    <VoteRow label="Richmond" yes={30} no={70}/>
                    <VoteRow label="D1·4·7·11" yes={39} no={61}/>
                </div>

                <p className="case-note">Every westside bar sits left of the line. The one that counted sits right of it.</p>
            </figure>

            <figure className="case card">
                <span className="case-where">Chinatown · District 3 · 2026</span>
                <p className="case-what">
                    CCBA, a five-decade board member and 150+ merchants opposed the bridge
                    removal. The supervisor said his office received no communication on it.
                </p>
                <h3>Portsmouth Square — opposition vs the record</h3>
                <p className="case-sub">What the community held, and what the file held.</p>

                <div className="tiles">
                    <div className="tile">
                        <div className="tile-n">176<span className="tile-u">yrs</span></div>
                        <div className="tile-l">CCBA, opposed and uninvited</div>
                    </div>
                    <div className="tile">
                        <div className="tile-n">150<span className="tile-u">+</span></div>
                        <div className="tile-l">Merchants represented in protest</div>
                    </div>
                    <div className="tile zero">
                        <div className="tile-n">0</div>
                        <div className="tile-l">Communications the D3 supervisor's office received</div>
                    </div>
                </div>

                <p className="case-note">The zero is the whole story.</p>
            </figure>
        </div>;
}
