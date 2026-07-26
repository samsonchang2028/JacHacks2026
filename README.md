# Quorum — Signal & Procedure Ingestion (P1)

Making community objections countable. See [`DESIGNDOC.md`](DESIGNDOC.md) for the
full product vision and [`p1ingestion.md`](p1ingestion.md) for the ingestion
spec this pipeline implements.

This repo has two halves:

- **`schemas/`** — the Jac graph (schema, curated seed data, walkers). This is
  what the demo actually runs.
- **`ingest/`** — the Python pipeline that fetches real data (news, 311, org
  contacts, procedural comment channels) and turns it into the JSON contract
  (`out/fixture.json`) that feeds the graph.

---

## 1. Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt
pip install jaclang   # not pinned in requirements.txt; see note below
```

Create `.env` in the repo root (never commit this — it's gitignored):

```
FIRECRAWL_API_KEY=fc-...
SOCRATA_API_ID=...
SOCRATA_API_KEY=...
```

Socrata's endpoints also work anonymously (rate-limited) if you don't have
keys yet — `fetch/socrata.py` falls back gracefully.

**Why `jaclang` isn't in requirements.txt:** the ingestion pipeline
(`ingest/`) is pure Python and doesn't need it. Only running the graph itself
(`schemas/*.jac`) does. Install it separately if you want to run the demo
graph, not just the ingestion.

---

## 2. Running the ingestion pipeline

Every fetcher and extractor is cache-first: a repeated call is served from
`cache/` (gitignored, keyed by request hash) with zero network traffic and
zero additional Firecrawl credits. Delete `cache/` to force a fresh pull.
Firecrawl spend is tracked cumulatively in `cache/_credit_ledger.json` against
the `credit_budget` in `ingest/config/sources.yaml` (currently 300) — calls
raise `BudgetExceeded` rather than silently overspending.

Load `.env` into your shell first:

```bash
set -a && source .env && set +a
```

### Structured APIs (free, no Firecrawl credits)

```bash
python -m ingest.fetch.socrata --smoke     # 311 cases in a Chinatown bbox
python -m ingest.fetch.legistar --smoke    # SF legislative matters (historical only — see below)
```

Two structured sources were investigated and cut, with the findings kept in
the code rather than silently dropped:

- **Open311 (removed)** — SF's GeoReport v2 endpoint is vendor-run and
  requires an API key we don't have; the same 311 data is in Socrata anyway.
- **Legistar Web API's new-matter feed is frozen** — the last real
  legislation in it is from ~Dec 2018 (plus a stray temp record in Sept
  2020), so neither the Portsmouth Square renovation (2023+) nor Prop K
  (2024) exists in it. Old records still receive metadata updates and the
  public portal (sfgov.legistar.com) *is* current — but the portal is
  scrape-only, which is why it's listed under the Firecrawl procedure
  targets instead. The `/Events` endpoint was never configured for SF and
  always 400s. Usable for historical precedent only. Full probe notes in
  `ingest/fetch/legistar.py`.

### Firecrawl-backed extraction (spends credits on first run per URL)

```bash
# Task 4 — comment channels + deadlines for SF Rec & Park / Legistar / Planning
python -m ingest.extract.procedure

# Task 5 — org contacts from config/orgs.yaml
python -m ingest.extract.orgs

# Task 6 — testimony from news coverage of both cases
python -m ingest.extract.narrative
```

Each prints its findings and a credit-spend line. None of these write to
`out/fixture.json` automatically — that file is hand-assembled from their
output (see `out/fixture.json`'s current contents for the merged result of a
real run against live sources). Re-running is safe and free once cached.

### Emit fixture → Jac statements

```bash
python -m ingest.emit.to_jac
```

Writes Jac node/edge statements (matching `seed_signal.jac`'s style) to
**`out/fixture.jac`** and also prints them to stdout. This is a standalone
handoff artifact — it never touches `schemas/seed_signal.jac`, which is
hand-curated prose in places that a blind overwrite would destroy. Paste in
whatever pieces of `out/fixture.jac` you want.

---

## 3. Running the tests

```bash
python -m pytest tests/ -v
```

16 tests, no network required — `test_contract.py` validates
`out/fixture.json` against the schema; `test_firecrawl_client.py` verifies
cache-hit and budget-guard behavior against a fake transport;
`test_procedure.py` / `test_to_jac.py` cover the extraction/emit logic
directly.

---

## 4. Running the graph (the actual demo)

```bash
pip install jaclang
jac run schemas/smoke.jac
```

Passes when both seeders load, `DivergenceCheck` fires on Prop K and not on
Portsmouth Square, and `PrecedentMatcher` returns matches for both cases.

**`jac` persists a session DB keyed by your working directory**, at
`<cwd>/.jac/data/<script-name>.db` (gitignored) — running `jac run
schemas/smoke.jac` from the repo root creates `./.jac/`, not
`schemas/.jac/`. Each run adds to the same persisted graph, so re-running
without clearing it prints every case N times for N runs. If you ever see a
case printed more than once:

```bash
rm -rf .jac/   # from wherever you ran `jac run` from
```

---

## 5. What's real vs. what's an honest gap

This was run live against production sources, not mocked:

- **3 verified comment channels** (SF Planning Dept EIR/hearing processes),
  each with a source URL confirmed to return 200.
- **9/9 orgs** in `config/orgs.yaml` resolved to a real contact or an
  explicit blank + notes on where we looked.
- **22 testimony records** (4 curated + 18 pulled from Wind News, Richmond
  Sunset News, SF Public Press, SPUR) — all with source URLs, all with
  private individuals' names scrubbed to roles per the no-fabrication rules
  in `p1ingestion.md` §0.

**What didn't resolve, on purpose left as a gap and not a guess:** SF Rec &
Park Commission's and the D3 Supervisor's Office's own public-comment
channels. Every candidate agenda page had gone dead by scrape time, and
searching sf.gov surfaced only generic Board of Supervisors pages, not a
project-specific channel. `DecisionWalker` reports this as a `GAP` at
runtime rather than fabricating a plausible-looking one — see the comment in
`seed_signal.jac` above the Portsmouth Square procedure section. This
mirrors the case's own thesis: the channel is genuinely missing.

**`incidents` is empty on purpose.** We queried 311 both by bounding box and
by full-text keyword ("Portsmouth Square" alone returns 994 cases, 609 of
them Rec & Park requests at the exact address). All of it is routine
maintenance traffic — restrooms, trash, graffiti, recreation equipment.
SF's 311 taxonomy has no category for opposition to a project; that signal
lives in testimony and public comment (which we did capture), not 311. An
honest empty list beats maintenance tickets dressed up as controversy
evidence. Reasoning also documented in `ingest/fetch/socrata.py`.

**Skipped:** Task 7 (Reddit) — deprioritized per the spec's own instruction;
nothing in the demo depends on it.

---

## 6. Known jaclang quirks fixed here

Two bugs in the original `schemas/*.jac` files were blocking `jac run`
entirely under jaclang 0.16.7 (unrelated to the ingestion work, but needed
fixing for the pipeline's output to be usable):

1. **Field ordering** — Jac requires non-default `has` fields before
   defaulted ones in the same archetype. `Testimony`, `CommentChannel`, and
   `Deadline` had a required field after a defaulted one; reordered, no
   field/type/default changed.
2. **Boolean literals** — `false`/`true` are not valid Jac literals (Python's
   `False`/`True` are); a few `has ... = false;` defaults used the lowercase
   form and only broke when actually hit at runtime (most callers always
   passed an explicit override).
3. **Node-type filter syntax** — `` [x --> (`?Type)] `` doesn't parse on this
   version, and `` [x --> (`Type)] `` compiles but crashes at runtime for any
   archetype with 2+ required fields (it evaluates the filter type as a
   zero-arg constructor call instead of an `isinstance` target). Replaced
   with `[n for n in [x -->] if isinstance(n, Type)]`, which is verified
   working.
