"""Evidence for the problem section.

Two figures, chosen by what the data has to do:

- Prop K is polarity, so a split bar centred on the 50% line. Every westside bar
  sits left of the line; the one that decided it sits right.
- Portsmouth Square is a single value against zero, which is a stat tile, not a
  chart. A one-bar chart of zero draws nothing.

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

def:pub ProblemCharts -> JsxElement {
    return
        <>
            <div className="charts">
                <figure className="chart">
                    <figcaption>
                        <h3>Proposition K — won the westside, lost the city</h3>
                        <p className="chart-sub">Vote share, Nov 2024. The line is 50%.</p>
                    </figcaption>

                    <div className="legend">
                        <span><i className="sw" style={{"background": "#0b8f80"}}></i> Yes</span>
                        <span><i className="sw" style={{"background": "#de5b49"}}></i> No</span>
                    </div>

                    <div
                        className="bars"
                        role="img"
                        aria-label="Prop K vote share: citywide 54.7% yes; Sunset 40% yes; Richmond 30% yes; Districts 1, 4, 7 and 11 combined 39% yes."
                    >
                        <VoteRow label="Citywide" yes={54.7} no={45.3}/>
                        <VoteRow label="Sunset" yes={40} no={60}/>
                        <VoteRow label="Richmond" yes={30} no={70}/>
                        <VoteRow label="D1·4·7·11" yes={39} no={61}/>
                    </div>

                    <p className="chart-note">Every westside bar sits left of the line. The one that counted sits right of it.</p>
                </figure>

                <figure className="chart">
                    <figcaption>
                        <h3>Portsmouth Square — opposition vs the record</h3>
                        <p className="chart-sub">What the community held, and what the file held.</p>
                    </figcaption>

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

                    <p className="chart-note">The zero is the whole story.</p>
                </figure>
            </div>

            <details className="data-table">
                <summary>View the underlying numbers</summary>
                <table>
                    <thead>
                        <tr><th>Geography</th><th>Yes</th><th>No</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Citywide</td><td>54.73%</td><td>45.27%</td></tr>
                        <tr><td>Sunset</td><td>~40%</td><td>~60%</td></tr>
                        <tr><td>Richmond</td><td>~30%</td><td>~70%</td></tr>
                        <tr><td>Districts 1, 4, 7, 11</td><td>39%</td><td>61%</td></tr>
                    </tbody>
                </table>
                <p className="chart-note">Prop K, Nov 2024. District figures approximate.</p>
            </details>
        </>;
}
