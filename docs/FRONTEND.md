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
Do that after pulling the fixture bridge (the `Organization` schema gained pipeline
fields, and the fixture attaches once per graph).

Dev-mode caveat: after editing `.jac` files, **restart** `jac start` rather than
trusting hot reload against a persisted graph — reload re-creates archetype
classes, so `isinstance`-based traversals (the fixture bridge, pipeline status)
stop matching previously persisted nodes until the process restarts.

## Backend artifact wiring

The UI graph reads the ingestion pipeline's artifact **`out/fixture.json`**
("THE CONTRACT", `ingest/README.md` §1) through `fixture_bridge.jac` at seed
time: 22 testimony records, 11 forum threads, 3 verified comment channels, and
9 organizations attach to the curated graph with provenance-based case mapping
(subject markers for testimony/threads; the case manifests' `org_candidates`
for orgs). Channels are deliberately bound to **no** decision body — the
contract carries no channel→body link, so the UI renders that as a gap instead
of guessing. A missing/unreadable fixture degrades to `pipeline.loaded: false`,
never an error page.

---

## Page routes (client)

All pages share `pages/layout.jac` (pill nav: Home · Route an issue · Community Notes).

| Path | File | What it does |
|---|---|---|
| `/` | `pages/index.jac` | Landing: hero, why, case studies, how-it-works pipeline, pressing-now feed |
| `/actions` | `pages/actions.jac` | Map + verdict-first issue panel. Optional `?case=<slug>` preselects a pin (defaults to Portsmouth) |
| `/issue/:id` | `pages/issue/[id].jac` | Issue page: briefing → verdict → the record → next steps → the packet (outreach drafts) → collapsed background/sources. (The route and validity bands were cut for length; their content reaches the reader via the briefing, panel rows, and sources table.) |
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
| `POST` | `/walker/seed_graph` | `{}` | Every page on load | `{ seeded, issues, fixture }` — idempotent seed + fixture attach (`fixture` = pipeline status/counts) |
| `POST` | `/walker/find_issues` | `{}` | Landing feed, actions map | List of pins: `slug`, `title`, `district`, `lat`, `lng`, `tier`, `on_record` (pipeline records mapped to the issue) |
| `POST` | `/walker/issue_detail` | `{ "slug": "<slug>" }` | Actions panel, issue page | Full workup (see below) or `{ found: false, slug }` |
| `POST` | `/walker/issue_report` | `{ "slug": "<slug>", "regenerate": false }` | Issue page briefing card | Compact briefing (see below); cache-first from `out/reports/<slug>.json`, `regenerate: true` forces a live LLM run |
| `POST` | `/walker/outreach_email` | `{ "slug": "<slug>", "org_name": "<name>", "regenerate": false }` | Issue page packet band | Staged outreach draft for one fixture-backed association; cache-first from `out/drafts/<slug>/<org>.json` (gitignored — drafts are staged, never committed, never sent) |
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
| `organizers`, `precedents` | Collapsed background (organizers now carry `contact` + `inside_process` when the pipeline resolved them) |
| `resources`, `sources` | Key facts + verification table |
| `testimony` | "The record" wall — pipeline statements with kind/speaker/language/source |
| `signals` | Forum-thread rows (summary, comment count, source URL) |
| `outreach` | Reachable orgs from pipeline contact research (contact or explicit blank + notes, `inside_process`) |
| `pipeline` | Artifact status: `loaded`, counts, and the 3 unbound verified channels |
| `path` | Graph traversal (demoted under Sources; now includes testimony/signal hops) |

### `issue_report` payload (the briefing card)

The LLM layer (`report_layer.jac`) congregates the whole workup into a compact
briefing: `verdict_line`, `stakes`, `record_gap`, `do_next[3]`, plus
`origin` (`llm` or `deterministic_fallback`), `ai_generated`, `model`,
`generated_at`, `summarized_from` counts, `validation_errors`, and
`legal_reviewed: false`. The runner is the `claude` CLI headless (same as
`ingest/extract/forum.py` — no API key); output is validated (no URLs/emails,
no numbers absent from the payload, no legal-conclusion phrases, exact
structure) and any failure — including a missing CLI — falls back to a
deterministic extract of curated fields. Results cache to
`out/reports/<slug>.json` (checked in for the two demo slugs), so page loads
never block on a live call. Thin issues return `{ available: false }`.

### `outreach_email` payload (the packet)

`outreach_layer.jac` drafts one email per association in `packet_orgs`
(fixture-backed orgs only — enriched organizers + pipeline outreach orgs;
individuals and campaign entities are excluded per p1ingestion §0). Each
draft: `to` (graph contact verbatim — the model never sees an address),
`subject`, `body_en`, `body_zh` (Traditional Chinese for zh-language orgs,
flagged for native-speaker review; org names kept untranslated), the
initial-signal citation (deterministically computed counts the model copies),
`origin`/`ai_generated`/`validation_errors`/`legal_reviewed: false`, and
`delivery: "manual_review_and_send"`. Validation adds a no-dates rule when no
verified deadline exists. **Nothing sends** — drafts stage to
`out/drafts/<slug>/` for human review, exactly as the ingestion spec
requires.

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
| `fixture_bridge.jac` | Reads `out/fixture.json` into the UI graph: pipeline archetypes (`Testimony`, `Incident`, `PipelineChannel`, `PipelineOrg`), deterministic case mapping, per-issue projections |
| `report_layer.jac` | LLM briefing layer: prompt + validation + deterministic fallback + `out/reports/` cache for `issue_report` |
| `outreach_layer.jac` | The packet: per-association outreach email drafts (bilingual where flagged), initial-signal citation, no-send staging to `out/drafts/` |
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
| `Sections.cl.jac` | Shared UI blocks for panel + detail: `RoutePanel`, `VerdictBlock`, `RoutePath`, `ValidityGrid`, `NextSteps`, `BackgroundContext`, `SourcesTable`, `TraversalPanel`, pipeline-record blocks (`RecordWall`, `SignalList`, `OutreachList`, `PipelineRecord`, `KindPill`, `ProcessPill`), plus legacy helpers |

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
