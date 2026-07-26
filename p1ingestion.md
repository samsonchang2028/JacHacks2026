# P1 — Signal & Procedure Ingestion

Spec for Claude Code. Owner: P1. Consumers: `seed_signal.jac` (P1), frontend (P3).

**Read this first:** `SCHEMA.md` is the frozen contract. Your job is to produce JSON that maps 1:1 onto its node types. Do not invent fields. Do not change category strings.

---

## 0. Hard rules — do not violate these

1. **Never send email.** This pipeline drafts and stages outreach. A human reviews and sends. The orgs in §4 are real community organizations with real staff; unsolicited bulk mail from a hackathon project is both a legal problem and a genuine harm to the case you're making. Output goes to `out/drafts/`, never to an SMTP client.
2. **Org-level contacts only.** Scrape the address a group publishes for public contact. Never collect named individuals, never build person-level records, never touch PTSA parent rosters or member directories. If a page lists individuals, extract the org email and discard the rest.
3. **No fabricated procedural facts.** A `Deadline` or `CommentChannel` without a working `source_url` does not get written. Emit `"date": "unknown"` and let the walker report a gap. A wrong deadline costs an organizer the one thing they can't recover.
4. **Cache everything.** Every fetch writes to `cache/` keyed by URL hash. All reads are cache-first. The demo must run with the network unplugged.
5. **Respect robots.txt and rate limits.** Firecrawl handles most of this; don't work around it.

---

## 1. Repo layout

```
ingest/
  config/
    sources.yaml          # endpoints + dataset ids, see §3
    orgs.yaml             # outreach targets, see §4
  fetch/
    socrata.py            # DataSF / Socrata SODA
    legistar.py           # Board of Supervisors legislation
    open311.py            # 311 cases
    firecrawl_client.py   # thin wrapper, retry + cache
    news.py               # Firecrawl /search + /scrape
  extract/
    schemas.py            # JSON schemas mirroring SCHEMA.md
    procedure.py          # CommentChannel + Deadline extraction
    orgs.py               # Organization contact extraction
    narrative.py          # Testimony extraction from articles
  emit/
    to_jac.py             # writes seed_signal fragments
    fixtures.py           # writes out/fixture.json
cache/
out/
  fixture.json            # THE CONTRACT — commit this first
  drafts/
tests/
  test_contract.py
```

---

## 2. Task order

Do these in sequence. Each has an acceptance test.

### Task 1 — Commit the fixture before writing any fetcher

Hand-write `out/fixture.json` in the exact shape the pipeline will eventually emit, populated with the Portsmouth Square and Prop K data already in `seed_signal.jac`. Commit it in the first hour.

This unblocks P2 and P3 immediately. Without it they sit idle waiting on scraping.

```json
{
  "projects": [
    {
      "name": "...",
      "category": "renovation",
      "location": "...",
      "description": "...",
      "timeline": "...",
      "source_url": "...",
      "fetched_at": "2026-07-26T00:00:00Z",
      "geo_zones": ["Chinatown", "District 3"],
      "decision_bodies": ["SF Recreation and Park Department",
                          "District 3 Supervisor's Office"]
    }
  ],
  "geo_zones": [
    { "name": "District 3", "kind": "district", "population_est": 0, "notes": "" }
  ],
  "decision_bodies": [
    { "name": "...", "kind": "supervisor", "jurisdiction": "District 3",
      "accountable_to": ["District 3"] }
  ],
  "comment_channels": [
    { "recipient": "...", "method": "email", "format_note": "",
      "languages": "en,zh", "source_url": "https://...",
      "deadlines": [
        { "kind": "comment", "date": "unknown", "threshold": "",
          "source_url": "https://..." }
      ]
    }
  ],
  "organizations": [
    { "name": "...", "community": "...", "language": "zh", "contact": "...",
      "inside_process": false, "serves": ["Chinatown"] }
  ],
  "testimony": [
    { "speaker": "...", "affiliation": "...", "claim": "...",
      "language": "en", "kind": "testimony", "source_url": "https://..." }
  ],
  "incidents": [
    { "kind": "311", "summary": "...", "count": 0, "source_url": "https://..." }
  ]
}
```

**Acceptance:** `tests/test_contract.py` validates `out/fixture.json` against `extract/schemas.py`, asserts every `category` is in the `CATEGORIES` list from `SCHEMA.md`, and asserts every `comment_channels[*].source_url` and `deadlines[*].source_url` is a non-empty URL.

### Task 2 — Firecrawl wrapper with cache

`fetch/firecrawl_client.py`. Base URL `https://api.firecrawl.dev/v2`, bearer auth from `FIRECRAWL_API_KEY`.

- `map_site(url)` → `POST /v2/map`, returns candidate URLs. Use this before crawling anything.
- `scrape(url, formats)` → `POST /v2/scrape`
- `scrape_json(url, schema)` → `POST /v2/scrape` with `formats: [{"type": "json", "schema": {...}}]`
- `extract(urls, prompt, schema)` → `POST /v2/extract` for multi-page structured pulls
- `crawl(url, include_paths, limit)` → `POST /v2/crawl`, async, returns `jobId`; poll `GET /v2/crawl/{id}`

**Cost discipline.** Roughly 1 credit per scraped page, 1 per map call, and JSON extraction adds ~4 on top (so ~5/page). Free tier is small and concurrency is limited to about 2 requests. Set a hard credit budget in `sources.yaml` and fail loudly when it's hit — do not discover this at hour eight.

Always `map` first, filter to the 3–5 pages that plausibly hold what you need, then `scrape_json` only those. Never crawl a `.gov` site broadly.

**Acceptance:** two consecutive identical calls produce one network request; second is served from `cache/`.

### Task 3 — Structured APIs (cheaper and more reliable than scraping)

Do these before any scraping. They're free, fast, and stable.

- **Socrata / DataSF** — `https://data.sfgov.org/resource/{dataset_id}.json`, SoQL params (`$where`, `$limit`, `$select`). Set `X-App-Token`. Needed: 311 cases, supervisor district boundaries, neighborhood boundaries, election precinct results.
- **Legistar** — Granicus Web API for SF legislation and Board matters. This is the real source for pending legislative items, far better than news.
- **Open311** — SF's GeoReport v2 service for 311. If the endpoint gives you trouble, the same data lives in Socrata; prefer Socrata.

**Verify dataset IDs and endpoint paths at runtime.** Do not trust hardcoded IDs from any document including this one — query the catalog, log what you resolved, and cache it.

**Acceptance:** `python -m ingest.fetch.socrata --smoke` returns >0 rows for a 311 query bounded to a Chinatown lat/long box, and writes to cache.

### Task 4 — Procedure extraction (your highest-value output)

This backs the headline demo artifact. Targets:

- SF Rec & Park commission agendas and public comment instructions
- Board of Supervisors / committee agendas and comment instructions
- SF Planning notices where applicable

Use `map_site` → filter to agenda/comment pages → `scrape_json` with:

```python
PROCEDURE_SCHEMA = {
  "type": "object",
  "properties": {
    "recipient": {"type": "string"},
    "method": {"type": "string", "enum": ["email","web_form","in_person","mail"]},
    "format_note": {"type": "string"},
    "languages": {"type": "string"},
    "deadline_kind": {"type": "string",
                      "enum": ["comment","appeal","signature","hearing"]},
    "deadline_date": {"type": "string"},
    "found": {"type": "boolean"}
  },
  "required": ["found"]
}
```

`found: false` → emit nothing. Missing date → `"unknown"`. Never let the model guess a date; add an explicit instruction that unknown values must be returned as the literal string `unknown`.

**Acceptance:** for at least one real body, `out/fixture.json` contains a `comment_channel` with a live `source_url` that returns 200.

### Task 5 — Organization contacts

Input `config/orgs.yaml` (§4). For each: `map_site` → find the contact page → `scrape_json` for a public org email/phone and the languages served.

Set `inside_process` by hand, not by model. For Portsmouth Square: CCDC was inside the official process; CCBA and the merchants association were not. That flag carries the lead case's whole argument, so it's a judgment call you own.

**Acceptance:** every org in `orgs.yaml` has either a contact or an explicit `"contact": ""` plus a `notes` field saying where you looked.

### Task 6 — Narrative extraction

Firecrawl `/search` then `/scrape` for coverage of each case. Extract `Testimony` records: speaker role, affiliation, the claim in one sentence, language, and `source_url`.

Sources worth targeting: Mission Local, SF Standard, SF Examiner, Richmond Review/Sunset Beacon, and in-language press (Wind Newspaper, Sing Tao) — the last group is where the Chinatown opposition actually lived and has no API, which is exactly what Firecrawl is for.

**Speaker field takes a role, not a private individual's name.** "CCBA board member" not a full name, unless the person is a public official speaking officially.

**Acceptance:** ≥6 testimony records across the two cases, each with a resolving `source_url`.

### Task 7 — Reddit (deprioritize)

`r/SanFrancisco` is the weakest source on your list: it needs OAuth, its terms restrict downstream use, and forum sentiment is low-signal compared to 311 counts and on-the-record testimony. If you do it:

- aggregate only — thread counts and topic frequency, never usernames, never quoted comments as `Testimony`
- treat output as `Incident`-adjacent context, not evidence

Cut this first if you're behind. Nothing in the demo depends on it.

### Task 8 — Emit

`emit/to_jac.py` reads `out/fixture.json` and writes Jac node/edge statements matching `seed_signal.jac`'s existing style. Print, don't overwrite — you paste in what you want.

**Acceptance:** generated statements load under `jac run smoke.jac` with zero failures reported.

---

## 3. `config/sources.yaml`

```yaml
credit_budget: 300          # hard stop; fail loudly

apis:
  socrata:
    base: https://data.sfgov.org/resource
    app_token_env: SOCRATA_APP_TOKEN
    needed:
      - 311_cases
      - supervisor_districts
      - analysis_neighborhoods
      - election_precinct_results     # see note below
  legistar:
    note: Granicus Web API, SF client. Resolve base path at runtime.
  open311:
    note: GeoReport v2. Prefer Socrata if the endpoint misbehaves.

firecrawl_targets:
  procedure:
    - sfrecpark.org           # commission agendas, comment instructions
    - sfgov.legistar.com      # agendas if the API is short on detail
    - sfplanning.org          # notices
  news:
    - missionlocal.org
    - sfstandard.com
    - sfexaminer.com
    - richmondsunsetnews.com
  in_language:
    - windnewspaper.com
    - # add Sing Tao / other in-language outlets
```

**Add this even though it wasn't on your list: precinct-level election results.** SF publishes them, and they turn `DivergenceCheck` from a hardcoded judgment into a computed one — you can show, from data, that Prop K carried citywide while losing every precinct in the impact zone. That's your team's single best demo moment, currently resting on a hand-written edge. Making it empirical is the highest-leverage thing on this page.

Also worth adding: CEQAnet (state clearinghouse) for environmental notices, and SF Ethics for the disclosure rules that apply if the ad component ever goes live.

---

## 4. `config/orgs.yaml`

```yaml
- name: Chinese Consolidated Benevolent Association
  case: portsmouth-square
  serves: [Chinatown]
  language: zh
  inside_process: false
- name: Chinatown Merchants Association
  case: portsmouth-square
  serves: [Chinatown]
  language: zh
  inside_process: false
- name: SF Chamber of Commerce
  case: portsmouth-square
  serves: [San Francisco (citywide electorate)]
  language: en
  inside_process: false
- name: Community Youth Center
  case: portsmouth-square
  serves: [Chinatown]
  language: zh
  inside_process: false
- name: Chinatown Community Development Center
  case: portsmouth-square
  serves: [Chinatown]
  language: en
  inside_process: true

- name: Richmond Neighborhood Center
  case: prop-k-great-highway
  serves: [Richmond]
  language: en
- name: Geary Merchants Association
  case: prop-k-great-highway
  serves: [Richmond]
  language: en
- name: Lowell High School PTSA
  case: prop-k-great-highway
  serves: [Sunset]
  language: en
  note: org-level contact only, no parent records
- name: Sunset churches
  case: prop-k-great-highway
  serves: [Sunset]
  language: en
  note: resolve to specific congregations before scraping
```

### The eastside problem — read this before building outreach for Prop K

You're right that Prop K needs reach outside the west side. But org outreach won't get you there, and the plan should say so honestly.

The eastside organizations in this space — parks, transit, and cycling advocacy groups — were largely *supporters* of the closure. They will not carry an opposition message. There is no equivalent of CCBA sitting on the east side waiting to be asked.

That's precisely why the tool's output differs by case:

- **Portsmouth Square** → org outreach works, because the excluded orgs already hold the position. Output: bilingual packet with a countable submission.
- **Prop K** → org outreach fails; the decision zone has no aligned intermediaries. Output: paid and earned media aimed at the citywide electorate, plus the divergence warning itself.

So build `orgs.yaml` with a `case` field and let the pipeline emit **zero** outreach targets for the Prop K decision zone. An empty list is the correct, honest output there — and saying that on stage is stronger than pretending you found eastside allies. It's the finding, not a gap.

---

## 5. Environment

```
FIRECRAWL_API_KEY=fc-...
SOCRATA_APP_TOKEN=...
```

Never commit keys. `.env` in `.gitignore`.

---

## 6. Definition of done for P1

- `out/fixture.json` committed hour one, valid against the contract
- ≥1 real `comment_channel` with a resolving `source_url`
- All orgs resolved to a contact or an explicit blank with notes
- ≥6 testimony records with sources
- Cache warm; pipeline runs offline
- `jac run smoke.jac` reports zero failures
- Zero emails sent