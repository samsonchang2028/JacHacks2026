"""Community notes: an open wall where anyone can put a concern on the record.

Notes hang off root as `Concern` nodes rather than attaching to an Issue -- a
concern that has not yet become a filed civic action is exactly the signal the
rest of the app cannot see. No auth and no moderation queue: what is submitted
is what is shown. The walker, not this page, is where input is validated.
"""

cl {
    def:pub page -> JsxElement {
        has notes: list = [],
            name: str = "",
            body: str = "",
            error: str = "",
            sending: bool = False;

        async can with entry {
            got = root spawn list_notes();
            notes = got.reports[0];
        }

        def on_name(ev: any) -> None {
            name = str(ev.target.value);
        }

        def on_body(ev: any) -> None {
            body = str(ev.target.value);
        }

        async def submit(ev: any) -> None {
            ev.preventDefault();
            if sending {
                return;
            }
            sending = True;
            res = (root spawn add_note(name=name, body=body)).reports[0];
            if res["ok"] {
                notes = res["notes"];
                name = "";
                body = "";
                error = "";
            } else {
                error = res["error"];
            }
            sending = False;
        }

        return
            <div className="actions-shell notes-shell">
                <p className="eyebrow">Community notes</p>
                <h2 className="section-title">Put a concern on the record</h2>
                <p className="lead">
                    Something happening on your block that no agenda has caught up
                    with yet? Write it here. Notes are public, and they go to
                    whoever is watching this page.
                </p>

                <form className="note-form" onSubmit={submit}>
                    <div className="field">
                        <label htmlFor="note-name">
                            Your name <span className="hint">optional</span>
                        </label>
                        <input
                            id="note-name"
                            type="text"
                            maxLength={80}
                            value={name}
                            placeholder="Anonymous"
                            onChange={on_name}
                        />
                    </div>

                    <div className="field">
                        <label htmlFor="note-body">Your concern</label>
                        <textarea
                            id="note-body"
                            rows={5}
                            maxLength={1000}
                            value={body}
                            placeholder="What is happening, where, and who it affects."
                            onChange={on_body}
                        />
                        <span className="hint">{str(len(body)) + " / 1000"}</span>
                    </div>

                    {<></> if error == "" else <p className="note-error" role="alert">{error}</p>}

                    <div>
                        <button className="case-button active" type="submit" disabled={sending}>
                            {"Submitting..." if sending else "Submit note"}
                        </button>
                    </div>
                </form>

                <h3 className="notes-heading">
                    {"1 note" if len(notes) == 1 else str(len(notes)) + " notes"}
                </h3>

                {<p className="lead">No notes yet. Yours would be the first.</p>
                    if len(notes) == 0 else
                    <ul className="note-list">
                        {[
                            <li className="note" key={str(k)}>
                                <div className="note-name">{notes[k]["name"]}</div>
                                <p className="note-body">{notes[k]["body"]}</p>
                            </li>
                            for k in range(len(notes))
                        ]}
                    </ul>}
            </div>;
    }
}
