# Implementation status

Referenced by `AGENTS.md` as required reading; created 2026-07-26 (it did not
previously exist). Newest first.

## 2026-07-26 — Docs moved into `docs/`

Root was cluttered with a dozen `.md` files. Moved everything except the
setup/demo README and the hackathon submission into `docs/`:
`PRODUCT.md`, `DESIGN.md`, `DESIGNDOC.md`, `FRONTEND.md`, `p1ingestion.md`,
`IMPLEMENTATION_STATUS.md`, `PACKAGE_INDEX.md`, `OVERVIEW.md` → `docs/`.
Root now holds exactly `README.md`, `DEVPOST.md`, `AGENTS.md`, `CLAUDE.md` —
the last two stay at root because agent tooling only discovers them there.
Updated every in-repo reference (README's doc-map links, AGENTS.md/CLAUDE.md
required-reading paths, `docs/p1ingestion.md` §0 citations in
`outreach_layer.jac`/`main.jac`/`ingest/*`, `DESIGNDOC.md` mentions in
`schemas/seed_signal.jac`) and re-verified: no broken markdown links beyond
the pre-existing intentional historical ones, `docs/PACKAGE_INDEX.md`'s own
root/docs split rewritten to match, 42/42 pytest, all `.jac` type-checks at
their prior baselines (doc-only move, no code touched).

## 2026-07-26 — The packet: outreach email drafts + page slimmed

- **Route and validity bands cut** from the issue page (too much text). The
  walker still reports `route`/`counts`/`not_counts` — the briefing
  summarizes from them, the actions panel keeps decides/channel/deadline
  rows, and the sources table keeps the verification story. `RoutePath` /
  `ValidityGrid` remain in `Sections.cl.jac` unused (the file's documented
  legacy-helpers convention).
- **`outreach_layer.jac` (new)** — staged outreach email drafts, one per
  association in the new `packet_orgs` payload list (fixture-backed orgs
  only: enriched organizers + pipeline outreach orgs; individuals and
  campaign entities excluded per p1ingestion §0). Each draft cites the
  initial signal already collected (counts computed deterministically so
  the model copies, never sums), asks the org to file *its own* view (no
  position presumed), keeps contacts out of the model entirely (To: renders
  verbatim from the graph), and is bilingual for zh orgs (Traditional
  Chinese, org names untranslated, flagged for native-speaker review).
  Validation = the briefing stack plus a no-dates rule when no verified
  deadline exists. Fallback = deterministic EN-only template. Staging =
  `out/drafts/<slug>/<org>.json`, gitignored by design; **nothing sends,
  ever** (`delivery: "manual_review_and_send"`).
- **`main.jac`** — `walker:pub outreach_email {slug, org_name, regenerate}`;
  `issue_payload` gains `packet_orgs`.
- **UI** — "The packet" band on the issue page: one row per association
  (contact chip or explicit gap), a per-org "Draft email" button (live LLM
  run when unstaged, instant from disk after), and the generated email
  rendered on the page: To/Subject/body, collapsible 中文 version, and the
  staged-only fine print.

## 2026-07-26 — LLM briefing layer (issue_report)

The issue page led with too much text; a report layer now congregates the
whole workup into a compact, labeled briefing.

**Changed:**

- `report_layer.jac` (new) — takes the full `issue_payload` and produces
  `verdict_line` / `stakes` / `record_gap` / `do_next[3]`. Runner is the
  `claude` CLI headless (the `ingest/extract/forum.py` pattern — no API
  key). The prompt is summarize-only; a validator rejects any URL/email, any
  multi-digit number absent from the payload (thousands-separator-aware
  tokenizer — a blanket comma strip glued digit lists into fake numbers),
  legal-conclusion phrases, and structural violations. One retry, then a
  deterministic extract of curated fields (the RecommendRecourse fallback
  pattern — the endpoint never fails because a model did). Aggregates the
  model may want (`forum_comment_total`, counts) are computed
  deterministically into the source so it copies instead of doing arithmetic.
  Results cache to `out/reports/<slug>.json`.
- `main.jac` — `issue_detail`'s body extracted into `issue_payload(issue)`
  (shared traversal, one source of truth); new `walker:pub issue_report`
  (`slug`, `regenerate`); thin issues return `available: false` without
  spending an LLM call.
- UI — `BriefingCard` (+ pending shim) at the top of the issue page, labeled
  "AI-generated summary" (or "Deterministic summary — LLM unavailable") with
  a fine-print line separating generated prose from cited fact; the record
  wall and signal list now show three items with the rest behind "Show all
  N" toggles.
- `out/reports/` — both demo briefings generated live (origin `llm`, zero
  validation errors) and checked in so the demo never blocks on a live call.

**Verified:** `jac check` — report layer 0 errors, `main.jac` at its
pre-existing 8; live generation ~35–40s per slug, cached serve ~20ms;
validator caught two real fabrications during development (a comma-glued
digit run and a model-computed rounded total) before the grounding fix;
headless renders of both issue pages show the card with zero console errors;
42/42 pytest.

**Remains:** briefings regenerate only via `regenerate: true` (no staleness
check against the fixture's content); single-flight locking if many uncached
slugs are requested at once.

## 2026-07-26 — Docs cleanup + housekeeping

- Created `PACKAGE_INDEX.md` — the repo index `AGENTS.md`/`CLAUDE.md` require
  but which never existed.
- README reworked: project-level title, demo quick start (no keys needed),
  §3 test count corrected (16 → 42, suite list updated), §4 retitled to the
  graph smoke test (the UI is the demo), doc map added.
- Removed `GRAPHING_README_TEMPLATE.md` (pre-build scaffold: placeholder
  walker names and "insert here" sections; unreferenced; its safety bullets
  live in `AGENTS.md`).
- Fixed dead references to the deleted `PLAN_reddit_and_legistar.md` in
  `README.md` and `ingest/fetch/reddit.py`; fixed `CLAUDE.md`'s "numbered
  documents in docs/" (they are not numbered).
- Housekeeping: stale pre-change dev servers stopped (old graph DB held no
  community notes), `.jac/data` UI DBs wiped, dev server restarted on the
  documented ports (app :8000, API :8001) — fresh seed verified with the
  fixture attached (22/11/7/3).

## 2026-07-26 — Frontend reads the backend artifact (fixture bridge)

The UI's Jac graph now ingests `out/fixture.json` — the ingestion pipeline's
one interface — at seed time, and the frontend renders that record.

**Changed:**

- `fixture_bridge.jac` (new) — offline reader for the artifact. Own archetypes
  (`Testimony`, `Incident`, `PipelineChannel`, `PipelineOrg`; edges
  `has_testimony`, `has_signal`, `has_outreach_org`), idempotent
  `attach_fixture`, per-issue projections. Case mapping is provenance, not
  judgment: subject markers for testimony/threads (ambiguous → unmapped, kept
  on root); manifest `org_candidates` for orgs; channels bound to **nothing**
  (the contract has no channel→body link — rendered as the gap it is).
- `main.jac` — imports the bridge; `seed_graph` attaches the fixture on both
  paths and reports `fixture` status; `Organization` gained pipeline fields
  (`community`, `contact`, `inside_process`, `notes`); `find_issues` reports
  `on_record`; `issue_detail` reports `testimony` / `signals` / `outreach` /
  `pipeline` and two extra traversal hops.
- `components/Sections.cl.jac` — `RecordWall`, `SignalList`, `OutreachList`,
  `PipelineRecord`, `KindPill`, `ProcessPill`; organizer cards show pipeline
  contact + inside/outside-process pill; `RoutePanel` gains an "On record"
  row; `CitationChip` omits the retrieval date when blank.
- `pages/issue/[id].jac` — "The record" band (record wall + forum signal) plus
  the outreach and pipeline-provenance collapsibles.
- `pages/index.jac` — feed rows show real per-issue record counts; footer note
  names the artifact once counts exist.
- `assets/actions.css`, `assets/landing.css` — token-only styles for the new
  blocks.
- Docs: `FRONTEND.md` (§ Backend artifact wiring, payload table), `README.md`.

**Verified:** `jac check` — bridge 0 errors, `main.jac` unchanged at its
pre-existing 8 false-positive errors; 42/42 pytest; `jac start` client compile
clean; headless-browser render of `/`, `/actions`, `/issue/portsmouth-square`
(10 statements + 4 threads), `/issue/prop-k` (12 + 7) with zero console
errors; all 33 mappable fixture records mapped, attach idempotent across
re-spawns.

**Remains / follow-up:**

- Wire the `schemas/` reasoning walkers (`RecommendRecourse`,
  `EvidenceMatcher`, `BuildCampaign`) to the UI — response shapes are already
  specified in `docs/CIVIC_WALKER_INTERFACE.md` and `docs/TARGETING_MODULE.md`.
- After pulling this change, delete `.jac/data/*.db` once so the fresh schema
  seeds and the fixture attaches. (Done for this working copy in the cleanup
  entry above.)
