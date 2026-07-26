"""Shared app shell: topbar, brand, nav, routed page outlet."""

cl import from "@jac/runtime" { Outlet, Link, useLocation }

cl {
    def:pub layout -> JsxElement {
        location = useLocation();
        path = location.pathname;

        return
            <main className="page-shell" id="top">
                <section className="app-panel">
                    <nav className="topbar" aria-label="Primary navigation">
                        <Link className="brand" to="/" aria-label="Quorum home">
                            <span className="brand-mark" aria-hidden="true"></span>
                            <strong>Quorum</strong>
                        </Link>
                        <div className="nav-labels">
                            <Link
                                to="/"
                                className={"nav-link active" if path == "/" else "nav-link"}
                            >
                                Home
                            </Link>
                            <Link
                                to="/actions"
                                className={"nav-link active" if path.startswith("/actions") or path.startswith("/issue") else "nav-link"}
                            >
                                Find Actions
                            </Link>
                            <Link
                                to="/how"
                                className={"nav-link active" if path.startswith("/how") else "nav-link"}
                            >
                                How it works
                            </Link>
                        </div>
                    </nav>

                    <Outlet/>
                </section>
            </main>;
    }
}
