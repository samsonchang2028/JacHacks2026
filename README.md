# Quorum — Frontend

Jac fullstack UI for Quorum: civic decision routing for San Francisco. The client is written in Jac (`.jac` / `.cl.jac`), compiled to React, and talks to Jac walkers over HTTP.

## Run

```bash
jac start main.jac --dev
```

| Surface | URL |
|---|---|
| App (Vite) | http://localhost:8000/ |
| API (Jac walkers) | http://localhost:8001/ |

On Windows, start the server with UTF-8 so Chinese language tags on organizers print cleanly:

```powershell
$env:PYTHONIOENCODING = 'utf-8'
$env:PYTHONUTF8 = '1'
jac start main.jac --dev
```

Graph data lives in `.jac/data/*.db`. Delete those files to force a fresh `seed_graph`.

---

## Page routes (client)

All pages share `pages/layout.jac` (pill nav: Home · Route an issue · Community Notes).

| Path | File | What it does |
|---|---|---|
| `/` | `pages/index.jac` | Landing: hero, why, case studies, how-it-works pipeline, pressing-now feed |
| `/actions` | `pages/actions.jac` | Map + verdict-first issue panel. Optional `?case=<slug>` preselects a pin (defaults to Portsmouth) |
| `/issue/:id` | `pages/issue/[id].jac` | Full decision-routing page for one issue (`:id` = issue slug) |
| `/notes` | `pages/notes.jac` | Community notes wall (read + write) |

Demo slugs with a full procedural record:

- `portsmouth-square`
- `prop-k`

Thin pins (tracked, not yet routed) include `panhandle-bike-lane`, `tenderloin-sro`, `mission-bus-lane`, etc.

---

## API endpoints the frontend uses

The UI spawns walkers via the Jac client runtime (`root spawn …`), which POSTs to the API server.

Base: `http://localhost:8001`

| Method | Endpoint | Body | Used by | Returns |
|---|---|---|---|---|
| `POST` | `/walker/seed_graph` | `{}` | Every page on load | `{ seeded, issues }` — idempotent seed of the civic graph |
| `POST` | `/walker/find_issues` | `{}` | Landing feed, actions map | List of pins: `slug`, `title`, `district`, `lat`, `lng`, `tier` |
| `POST` | `/walker/issue_detail` | `{ "slug": "<slug>" }` | Actions panel, issue page | Full workup (see below) or `{ found: false, slug }` |
| `POST` | `/walker/list_notes` | `{}` | Notes page | List of `{ name, body }` (newest first) |
| `POST` | `/walker/add_note` | `{ "name": "", "body": "…" }` | Notes form | `{ ok, notes }` or `{ ok: false, error }` |

### `issue_detail` payload (when `found: true`)

| Field | Role in UI |
|---|---|
| `title`, `district`, `tier`, `short`, `problem`, `srcs` | Headers and background copy |
| `divergence` | Verdict hero (`kind`, `headline`, `why`, `correction_*`, zone names, `match`) |
| `zones_match`, `impact_zone`, `decision_zone` | Impact ≠ / ＝ decision display |
| `route` | Human-readable hops (body → zone → channel → deadline) |
| `counts`, `not_counts` | Validity grid |
| `actions` | “Do this next” steps |
| `organizers`, `precedents` | Collapsed background |
| `resources`, `sources` | Key facts + verification table |
| `path` | Graph traversal (demoted under Sources) |

### Other useful API routes (not UI-primary)

| Method | Endpoint | Notes |
|---|---|---|
| `GET` | `/walkers` | List registered walkers |
| `GET` | `/walker/<name>` | Walker metadata |
| `GET` | `/functions` | List functions |
| `POST` | `/user/register`, `/user/login`, … | Auth stubs from the Jac server (unused by this UI) |

---

## File map

### Entry & config

| File | Role |
|---|---|
| `main.jac` | Graph schema, seed data, walkers, and client CSS imports (`app` shell) |
| `jac.toml` | Project config, npm deps (Leaflet, React Router), serve port |

### Pages (`pages/`)

| File | Role |
|---|---|
| `layout.jac` | Shared shell: pill navbar, mobile menu, `<Outlet/>` |
| `index.jac` | Landing page sections; spawns `seed_graph` + `find_issues` |
| `actions.jac` | Map picker + `RoutePanel`; spawns `issue_detail` on pin click |
| `issue/[id].jac` | Decision-routing detail: verdict → route → validity → steps → background |
| `notes.jac` | Community notes form + list; spawns `list_notes` / `add_note` |

### Components (`components/`)

| File | Role |
|---|---|
| `HeroMap.cl.jac` | Non-interactive SF map behind the landing hero |
| `IssueMap.cl.jac` | Clickable Leaflet pins (`full` / `thin` tiers) for `/actions` |
| `CaseStudies.cl.jac` | Prop K vote bars + Portsmouth Square zero tiles (landing Cases section) |
| `ProblemCharts.cl.jac` | Older chart component; superseded on landing by `CaseStudies` |
| `Sections.cl.jac` | Shared UI blocks for panel + detail: `RoutePanel`, `VerdictBlock`, `RoutePath`, `ValidityGrid`, `NextSteps`, `BackgroundContext`, `SourcesTable`, `TraversalPanel`, plus legacy helpers |

### Styles (`assets/`)

| File | Role |
|---|---|
| `quorum.css` | Design tokens, page shell, pill nav, shared chrome (load first) |
| `landing.css` | Landing sections: hero, fail cards, cases, how-grid, feed, footer |
| `actions.css` | Map, issue panel, verdict, route hops, validity, next steps, sources |

Design authority: `DESIGN.md`. Product framing: `PRODUCT.md`.

### Mockups (reference only)

| Path | Role |
|---|---|
| `.lavish/landing.html` | Source mock for the landing rebuild |
| `.lavish/actions-detail.html` | Source mock for decision-routing detail |
| `.lavish/*.html` | Earlier review / critique surfaces — not served by the app |

### Generated (do not edit)

| Path | Role |
|---|---|
| `.jac/client/compiled/` | Jac → JS compile output |
| `.jac/client/dist/` | Vite build artifacts |
| `.jac/data/*.db` | Persistent graph store |

---

## Typical UI → walker flow

```
Landing (/)
  seed_graph → find_issues → feed links to /issue/:slug

Route an issue (/actions)
  seed_graph → find_issues → map pins
  pin click / ?case= → issue_detail → RoutePanel
  “See the full route” → /issue/:slug

Issue detail (/issue/:slug)
  seed_graph → issue_detail → Verdict → Route → Validity → Steps → Background

Community Notes (/notes)
  list_notes on load
  add_note on submit → refreshed notes list
```
