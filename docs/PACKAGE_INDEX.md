# Package index

Required reading per `AGENTS.md` / `CLAUDE.md`: what lives where, what is
generated, and which document owns which contract. One line per file; follow
the pointers for detail.

## Root — entry points and governance

Root is kept to code entry points plus the two documents meant to be found
immediately: the setup/demo instructions and the submission writeup.
Everything else that used to sit at root now lives in `docs/` (below).

| File | Role |
|---|---|
| `main.jac` | Fullstack entry point: UI graph schema, curated seed, the walkers the UI spawns (`seed_graph`, `find_issues`, `issue_detail`, `issue_report`, `outreach_email`, `list_notes`, `add_note`), client CSS imports |
| `fixture_bridge.jac` | Reads `out/fixture.json` into the UI graph at seed time; pipeline archetypes + deterministic case mapping + per-issue projections (`docs/FRONTEND.md` § Backend artifact wiring) |
| `report_layer.jac` | LLM briefing layer for `issue_report`: summarize-only prompt over the workup payload, no-new-facts validation, deterministic fallback, `out/reports/` cache (`docs/FRONTEND.md` § issue_report payload) |
| `outreach_layer.jac` | The packet for `outreach_email`: per-association staged email drafts (bilingual for zh orgs), initial-signal citation, same validator stack + no-dates-without-verified-deadline rule, `out/drafts/` staging — never sends (`docs/FRONTEND.md` § outreach_email payload) |
| `jac.toml` | Project config: fullstack kind, npm deps, serve port |
| `requirements.txt` / `requirements-dev.txt` | Python deps for `ingest/` and tests (`jaclang` installed separately — see `README.md` §1) |
| `README.md` | Setup, pipeline CLI, tests, demo, honest gaps, jaclang quirks |
| `DEVPOST.md` | The hackathon submission writeup |
| `AGENTS.md` / `CLAUDE.md` | Repository instructions for agents: invariants, scope, boundaries |

## `docs/` — product, design, and build-history reference

| File | Role |
|---|---|
| `docs/OVERVIEW.md` | Product overview: the two cases, the insight, pipeline, architecture |
| `docs/PRODUCT.md` | Product schema: users, positioning, capabilities, constraints |
| `docs/DESIGNDOC.md` | Full product/architecture vision document |
| `docs/DESIGN.md` | Design system authority: type, color, spacing tokens |
| `docs/FRONTEND.md` | UI routes, walker endpoints, payload shapes, file map |
| `docs/p1ingestion.md` | P1 ingestion spec the pipeline implements (incl. no-fabrication rules §0) |
| `docs/IMPLEMENTATION_STATUS.md` | Running log of milestones, verification, and what remains |
| `docs/PACKAGE_INDEX.md` | This file |
| `docs/FIXTURE_GRAPH_MAPPING.md`, `docs/CIVIC_WALKER_INTERFACE.md`, `docs/TARGETING_MODULE.md`, `docs/SAMBA_ADAPTER.md` | Module contracts — see the `docs/` section further down |

## `schemas/` — the Jac graph (curated backbone + reasoning walkers)

| File | Role |
|---|---|
| `schema.jac` | Frozen contract: the curated node/edge archetypes (Project, GeoZone, DecisionBody, CommentChannel, Deadline, Organization, Testimony, Incident, PrecedentCase, …) |
| `layer_patch.jac` | Additive archetypes on top of the frozen core: `LayerAnchor` (7 semantic layers), `FixtureRecord`, `ProcedureGap`, `fixture_relation`, layer/gap edges |
| `seed_layers.jac` | Seeds the seven explicit semantic-layer anchors |
| `seed_signal.jac` | Hand-curated case seed (Portsmouth Square, Prop K) — prose curated; never overwritten by the emitter |
| `seed_precedent.jac` | Curated precedent library (trait-matched, not category-matched) |
| `fixture_adapter.jac` | Offline `out/fixture.json` → graph ingestion with stable fixture IDs, provenance, and explicit `ProcedureGap`s (`docs/FIXTURE_GRAPH_MAPPING.md`) |
| `graph_snapshot.jac` | Frontend-ready projection of the layered graph (nodes/edges per layer) |
| `walkers.jac` | `DivergenceCheck`, `DecisionWalker`, `ImpactWalker`, `PrecedentMatcher` |
| `walkers_evidence.jac` | `EvidenceMatcher` — only ever writes `potentially_relevant_to` (`docs/CIVIC_WALKER_INTERFACE.md`) |
| `walkers_recourse.jac` | `RecommendRecourse` — exactly three source-backed `ActionPath`s, deterministic fallback (`docs/CIVIC_WALKER_INTERFACE.md`) |
| `walkers_campaign.jac` | Campaign graph types + `BuildCampaign` — dry-run-only media planning (`docs/TARGETING_MODULE.md`) |
| `targeting_rules.jac` | Closed vocabularies, sensitive-targeting guardrails, copy templates |
| `samba_adapter.jac` | Illustrative CTV measurement adapter, simulated values only (`docs/SAMBA_ADAPTER.md`) |
| `smoke.jac`, `smoke_layers.jac`, `smoke_civic.jac`, `smoke_campaign.jac` | Executable contract checks — `jac run schemas/smoke*.jac` |

## `ingest/` — Python data pipeline (fetch → extract → emit)

Full reference: [`ingest/README.md`](ingest/README.md). Cache-first
throughout; `out/fixture.json` is the only downstream interface.

| Path | Role |
|---|---|
| `case.py` / `bootstrap_case.py` | Case-manifest loader / LLM-drafted new-case bootstrap (human-verified before trusted) |
| `config/sources.yaml`, `config/orgs.yaml` | Source endpoints + credit budget; org candidates with hand-set `inside_process` |
| `config/cases/*.yaml` | Case manifests (research knobs only; two verified gold standards + one example draft) |
| `fetch/` | `socrata.py` (311), `legistar.py` (historical API), `legistar_portal.py` (current portal scrape), `reddit.py` (Apify), `firecrawl_client.py` (budget-guarded), `_cache.py` |
| `extract/` | `procedure.py` (channels/deadlines), `orgs.py` (contacts), `narrative.py` (testimony), `forum.py` (incidents — the only stage that writes `fixture.json`), `schemas.py` (`FIXTURE_SCHEMA`) |
| `emit/to_jac.py` | `fixture.json` → `out/fixture.jac` handoff statements |

## UI — `pages/`, `components/`, `assets/`

See [`FRONTEND.md`](FRONTEND.md) for routes, endpoints, and payloads.

| Path | Role |
|---|---|
| `pages/layout.jac` | Shared shell + pill nav |
| `pages/index.jac` | Landing (hero, cases, how-it-works, pressing-now feed) |
| `pages/actions.jac` | Map + verdict-first issue panel |
| `pages/issue/[id].jac` | Decision-routing page: briefing → verdict → the record → next steps → the packet (outreach drafts) → collapsed background/sources |
| `pages/notes.jac` | Community notes wall |
| `components/*.cl.jac` | `Sections` (shared blocks incl. pipeline-record, briefing, and packet components), `IssueMap`, `HeroMap`, `CaseStudies`, `ProblemCharts` |
| `assets/*.css` | `quorum.css` (tokens, per `DESIGN.md`), `landing.css`, `actions.css` |

## Data and generated artifacts

| Path | Role |
|---|---|
| `out/fixture.json` | **THE CONTRACT** — the pipeline's one interface, schema-validated by `tests/test_contract.py` |
| `out/fixture.jac` | Generated Jac statements from the fixture (handoff artifact) |
| `out/reports/<slug>.json` | Cached AI-generated issue briefings (report layer artifact; checked in for the demo slugs, regenerate via `issue_report` with `regenerate: true`) |
| `out/drafts/<slug>/<org>.json` | Staged outreach email drafts from the outreach layer (gitignored by design: drafts are reviewed and sent by a human, never committed, never sent by Quorum) |
| `cache/` | Request-keyed fetch cache + `_credit_ledger.json` (offline mode; gitignored) |
| `.jac/` | Generated: client compile output, Vite build, persistent graph DBs (delete `data/*.db` to force a fresh seed) |
| `.lavish/` | Static HTML mockups, reference only — not served |

## `docs/` — module contracts (the rest of `docs/`, not covered above)

| File | Contract for |
|---|---|
| `docs/FIXTURE_GRAPH_MAPPING.md` | Fixture field → graph node/edge mapping and fallback behavior |
| `docs/CIVIC_WALKER_INTERFACE.md` | `EvidenceMatcher` / `RecommendRecourse` request-response shapes |
| `docs/TARGETING_MODULE.md` | `BuildCampaign`, the four zones, targeting invariants |
| `docs/SAMBA_ADAPTER.md` | Illustrative CTV measurement adapter |

## `tests/`

`python -m pytest tests/ -q` — 42 tests, no network. Fixture contract,
cache/budget behavior, extraction and emit logic, portal parsing (HTML
fixtures in `tests/fixtures/`).
