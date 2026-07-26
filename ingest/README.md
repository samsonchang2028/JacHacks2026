# `ingest/` — data pipeline reference

Everything the frontend (or the Jac graph) needs to consume this pipeline,
without reading the source. Written for hookup work: artifacts first, then
the Python API, then CLI, config, and gotchas.

---

## 1. The artifacts (what you actually consume)

### `out/fixture.json` — THE CONTRACT

One JSON document, validated by `tests/test_contract.py` against
`ingest/extract/schemas.py` (`FIXTURE_SCHEMA`). Seven collections:

| Collection | Item shape (key fields) | Notes |
|---|---|---|
| `projects` | `name, category, location, description, timeline, source_url, fetched_at, geo_zones[], decision_bodies[]` | `category` ∈ `CATEGORIES` — the P2 precedent join key |
| `geo_zones` | `name, kind (district\|neighborhood\|citywide), population_est, notes` | |
| `decision_bodies` | `name, kind, jurisdiction, accountable_to[]` | `accountable_to` names geo_zones — the hero divergence edge |
| `comment_channels` | `recipient, method (email\|web_form\|in_person\|mail), format_note, languages, source_url, deadlines[]` | every one has a live, verified `source_url` |
| ↳ `deadlines` | `kind (comment\|appeal\|signature\|hearing), date, threshold, source_url` | `date` is ISO or the literal `"unknown"` — never a guess |
| `organizations` | `name, community, language, contact, inside_process, serves[], notes` | `contact` may be `""` — then `notes` says where we looked. `inside_process` is hand-set, never model-set |
| `testimony` | `speaker, affiliation, claim, language, kind (testimony\|argument\|evidence\|counterargument), source_url` | `speaker` is a ROLE, never a private individual's name |
| `incidents` | `kind (311\|complaint_log\|forum), summary, count, source_url` | currently `forum`: one per relevant Reddit thread, LLM-summarized, `count` = comment volume |

**Display guidance:** every procedural fact carries a `source_url` — render it
as a citation chip (DESIGNDOC §6). Distinguish `fetched_at != ""` (live) from
`""` (curated). An empty `comment_channels` entry for a body is a *finding*
(the GAP), not missing data — the walkers report it as such.

### `out/fixture.jac` — generated Jac statements

`python -m ingest.emit.to_jac` regenerates it from fixture.json (also prints
to stdout). Standalone handoff artifact; verified loading under `jac run`.
Never overwrites `schemas/seed_signal.jac`.

### `cache/` — offline mode

Every fetch is cache-first (`cache/<sha256>.json`, keyed by request).
Warm cache ⇒ the whole pipeline runs with the network unplugged.
`cache/_credit_ledger.json` tracks cumulative Firecrawl spend against
`credit_budget` in `config/sources.yaml`; exceeding it raises
`BudgetExceeded` instead of silently overspending.

---

## 2. Case manifests — how a NEW case enters the system

`ingest/config/cases/<slug>.yaml`. The two demo cases are curated,
`verified: true` gold standards. A manifest holds **research knobs only**
(where to look) — never fetched facts, never the `inside_process` judgment:

```yaml
slug: portsmouth-square
title: Portsmouth Square Improvement Project
category: renovation              # ∈ CATEGORIES — P2 join key
description: >                    # drives LLM relevance filtering
search_terms: {news: "...", forum: "..."}
geography:
  impact_zones: [Chinatown, District 3]
  decision_zone: District 3       # who actually decides — the divergence input
  impact_bbox: {min_lat: ..., ...}   # optional; enables 311 queries
news_domains: [...]
procedure_targets: [...]
org_candidates: [...]             # names only
generated_by: curated | llm-bootstrap
verified: true | false
```

Python API (`ingest/case.py`):

```python
from ingest.case import list_cases, load_case
list_cases()                 # all verified manifests (drafts excluded), sorted
load_case("portsmouth-square")  # one manifest, schema-validated (CaseError if bad)
```

### Bootstrapping a new case (the agentic part)

```bash
python -m ingest.bootstrap_case --subject "Balboa Reservoir housing development"
```

Firecrawl web research → LLM (`claude` CLI, headless) fills the research
knobs → writes `<slug>.draft.yaml` (`verified: false`, excluded from
`list_cases()`) → prints a human review checklist. Degrades to a schema-valid
skeleton with no keys/CLI. A committed example draft:
`config/cases/balboa-reservoir-housing-development.draft.yaml`.

Human promotes a draft by reviewing, adding orgs to `config/orgs.yaml` with a
hand-set `inside_process`, setting `verified: true`, and renaming to
`<slug>.yaml` — from then on every pipeline stage picks it up automatically.

---

## 3. Python API by module

All functions are cache-first; a repeat call with identical args does no
network I/O and spends nothing.

### Fetchers (`ingest/fetch/`)

| Function | Returns | Cost |
|---|---|---|
| `socrata.query_311_in_bbox(bbox, limit)` | raw 311 case rows (dicts) | free |
| `socrata.resolve_dataset(topic)` | `{id, name, domain, topic}` from live catalog | free |
| `legistar.search_matters(keyword)` | historical (≤2018) legislative matters | free |
| `legistar_portal.search_legislation(text)` | **current** legislation: `{file_number, type, status, introduced, final_action, title, detail_url}` | free |
| `legistar_portal.get_calendar(body_contains=None)` | upcoming meetings: `{body, date, time, location, details_url, agenda_url}` | free |
| `reddit.search_reddit(query, case, max_items)` | posts: `{case, source, scope, query, post_id, title, body, author_role, permalink, created_at, score, num_comments}` — usernames already scrubbed | Apify credits (uncached) |
| `reddit.fetch_threads(permalinks, max_comments)` | `{thread_id: {post, comments[]}}` — call ONCE across all cases (cache key = sorted permalink set) | Apify credits (uncached) |
| `firecrawl_client.FirecrawlClient` | `.search() .map_site() .scrape() .scrape_json() .extract()` | Firecrawl credits, budget-guarded |

### Extractors (`ingest/extract/`)

| Function | Produces | LLM? |
|---|---|---|
| `procedure.run(sites=None)` | fixture-shaped `comment_channels` (dead links filtered, dates normalized-or-`"unknown"`) | Firecrawl JSON mode |
| `orgs.run()` | fixture-shaped `organizations` (contact or explicit blank + notes) | Firecrawl JSON mode |
| `narrative.run(case_queries)` | fixture-shaped `testimony` (speakers as roles) | Firecrawl JSON mode |
| `forum.load_cases()` | per-case forum config from manifests | — |
| `forum.build_incidents(case_cfg, posts, threads)` | fixture-shaped `incidents`, one per relevant thread | `claude` CLI (haiku): summary + relevance |
| `forum.main()` / `python -m ingest.extract.forum` | **writes `fixture.json`'s `incidents`** (the only extractor that writes the fixture itself) | ↑ |

### Emit (`ingest/emit/`)

`to_jac.main()` — fixture.json → `out/fixture.jac` + stdout.

---

## 4. CLI quick reference

```bash
# health checks (free, cache-served after first run)
python -m ingest.fetch.socrata --smoke
python -m ingest.fetch.socrata --case portsmouth-square     # manifest bbox
python -m ingest.fetch.legistar --smoke                     # historical API
python -m ingest.fetch.legistar_portal --smoke              # current portal
python -m ingest.fetch.legistar_portal --search "Great Highway"
python -m ingest.fetch.reddit --smoke                       # ~a cent uncached

# extraction (Firecrawl/Apify/LLM; all cache-first)
python -m ingest.extract.procedure [--case <slug>]
python -m ingest.extract.orgs
python -m ingest.extract.narrative          # queries from case manifests
python -m ingest.extract.forum             # rebuilds fixture incidents

# new case + emit
python -m ingest.bootstrap_case --subject "..."
python -m ingest.emit.to_jac
```

---

## 5. Environment

| Var | Needed by | Notes |
|---|---|---|
| `FIRECRAWL_API_KEY` | procedure/orgs/narrative, bootstrap research | budget-guarded (300 credits) |
| `APIFY_API_TOKEN` or `APIFY_API_KEY` | reddit | pay-per-event actor |
| `SOCRATA_API_ID` + `SOCRATA_API_KEY` | socrata (optional) | anonymous works, rate-limited |
| `claude` CLI logged in | forum summaries, bootstrap | no API key needed |

Load with: `set -a && source .env && set +a`

---

## 6. Gotchas for integrators

- **Nothing except `forum.main()` writes `fixture.json`** — procedure/orgs/
  narrative print their findings; merging into the fixture is a reviewed,
  manual step by design (no-fabrication rules).
- **Reddit is slow and flaky on first fetch** (2–4 min: Reddit 403-blocks
  the scraper until Apify's proxy rotation wins). Pre-warm the cache; never
  fetch live during a demo.
- **The Legistar Web API is frozen at ~Dec 2018** — use `legistar_portal`
  for anything current.
- **`jac run` persists a session DB** at `<cwd>/.jac/` — delete it if graph
  nodes appear duplicated across runs.
- **Duplicated allowlists:** `INCIDENT_KINDS` etc. exist in both
  `ingest/extract/schemas.py` and `schemas/fixture_adapter.jac`. Change both
  or `smoke_layers.jac` silently rejects records (bit us once already).
