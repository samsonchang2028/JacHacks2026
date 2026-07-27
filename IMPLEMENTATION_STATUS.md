# Implementation status

Referenced by `AGENTS.md` as required reading; created 2026-07-26 (it did not
previously exist). Newest first.

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
