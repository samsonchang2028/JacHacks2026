"""Shared app shell: pill navbar with the three app tabs, routed page outlet."""

cl import from "@jac/runtime" { Outlet, Link, useLocation }

cl {
    def:pub layout -> JsxElement {
        has menu_open: bool = False;

        location = useLocation();
        path = location.pathname;

        home_on = path == "/";
        actions_on = path.startswith("/actions") or path.startswith("/issue");
        notes_on = path.startswith("/notes");

        def open_menu() -> None {
            menu_open = True;
        }

        def close_menu() -> None {
            menu_open = False;
        }

        return
            <main className="page-shell" id="top">
                <section className="app-panel">
                    <div className="nav-wrap">
                        <nav className="topbar" aria-label="Primary navigation">
                            <Link
                                className="brand"
                                to="/"
                                aria-label="Quorum home"
                                onClick={close_menu}
                            >
                                <span className="brand-mark" aria-hidden="true"></span>
                                <strong>Quorum</strong>
                            </Link>

                            <div className="nav-labels">
                                <Link
                                    to="/"
                                    className={"nav-link active" if home_on else "nav-link"}
                                >
                                    Home
                                </Link>
                                <Link
                                    to="/actions"
                                    className={"nav-link active" if actions_on else "nav-link"}
                                >
                                    Route an issue
                                </Link>
                                <Link
                                    to="/notes"
                                    className={"nav-link active" if notes_on else "nav-link"}
                                >
                                    Community Notes
                                </Link>
                            </div>

                            <button
                                type="button"
                                className="nav-burger"
                                aria-label="Open menu"
                                aria-expanded={menu_open}
                                onClick={open_menu}
                            >
                                <span aria-hidden="true"></span>
                                <span aria-hidden="true"></span>
                                <span aria-hidden="true"></span>
                            </button>
                        </nav>
                    </div>

                    {
                        <div className="nav-sheet" role="dialog" aria-label="Menu">
                            <button
                                type="button"
                                className="nav-sheet-close"
                                aria-label="Close menu"
                                onClick={close_menu}
                            >
                                ×
                            </button>
                            <div className="nav-sheet-links">
                                <Link
                                    to="/"
                                    className={"nav-sheet-link active" if home_on else "nav-sheet-link"}
                                    onClick={close_menu}
                                >
                                    Home
                                </Link>
                                <Link
                                    to="/actions"
                                    className={"nav-sheet-link active" if actions_on else "nav-sheet-link"}
                                    onClick={close_menu}
                                >
                                    Route an issue
                                </Link>
                                <Link
                                    to="/notes"
                                    className={"nav-sheet-link active" if notes_on else "nav-sheet-link"}
                                    onClick={close_menu}
                                >
                                    Community Notes
                                </Link>
                            </div>
                        </div>
                        if menu_open else <></>
                    }

                    <Outlet/>
                </section>
            </main>;
    }
}
