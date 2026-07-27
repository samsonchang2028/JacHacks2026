# Quorum

**Tell Quorum the issue. It generates your advocacy playbook.**

A civic advocacy generator built in Jac for JacHacks SF 2026. Given a civic action — a project, proposal, agenda item, or ballot measure — Quorum generates the concrete output a community needs to be heard: a plain-language issue brief, a cited procedural playbook, exactly three recourse paths, bilingual outreach drafts, and strategic advice on where that advocacy should actually be aimed.

---

## Inspiration

When a government action harms a local community, the community usually loses — not for lack of caring, but because nobody told them what to *do*. Two real San Francisco cases showed us the two ways it happens.

**Portsmouth Square, Chinatown.** A ~$73M renovation included demolishing the historic pedestrian bridge over Kearny Street. Real opposition existed: the 176-year-old CCBA says it was never invited to project meetings; a five-decade board member opposed the removal; 150+ merchants protested. And yet the District 3 supervisor said his office had received **no communication** in support of keeping the bridge. The community held a position. The decision-maker's record held nothing. Nobody generated the ask: *submit this comment, in this format, to this person, before this date.*

**Prop K / Great Highway, Nov 2024.** The measure passed citywide at 54.7% while losing ~60–40 in the Sunset and ~70–30 in the Richmond. The opposition wasn't disorganized — one opponent spent $269,000, filed a CEQA challenge, and their campaign prompted a supervisor recall. Their own post-mortem: the organized opposition never went east of West Portal. Nobody gave them the one piece of advice that mattered: *your outreach is aimed at people who already agree — the persuadable audience is the citywide electorate.*

Both communities had motivation, networks, and even money. What they lacked was output and advice: the drafted, deadlined, correctly-addressed submission, and the strategic read on who actually needed persuading.

## What it does

You point Quorum at a civic action. It generates:

1. **A plain-language issue brief** — what's happening, who it affects, what's contested — summarized from local and in-language press, forum threads, and public records.
2. **A procedural playbook** — who decides, who they answer to, where to submit, in what format, by what deadline. Every fact carries a source URL, or is shown as an explicit gap: *"No verified source found. Quorum will not guess."*
3. **Exactly three recourse paths** — its core advocacy advice: `recorded_comment` (get on the record before the decision), `decision_zone_contact` (reach the body that decides), and `escalation` (appeal, ballot, or litigation routes drawn from precedent). Each is source-backed; none is ever marked legally reviewed.
4. **Targeting advice** — Quorum compares the impact zone against the decision zone and tells you, in plain terms, when they diverge: *"You are not the electorate for this decision — here's who is."* That's the sentence the Prop K opposition paid $269,000 to learn late.
5. **Precedent-based strategy** — matched by *how the community lost*, not what got built. Boston's Parcel C garage fight informs Portsmouth Square because in both, an in-language community was excluded from an official process. Quorum surfaces which tactics worked and which didn't.
6. **A bilingual outreach packet** — per-organization English and Chinese drafts whose call to action is the playbook's real, deadlined, correctly-addressed submission. Playbook and packet aren't two deliverables: the playbook supplies the ask; the packet is the wrapper.
7. **A campaign dry-run spec** — an outreach and CTV-ready media plan, staged for human review, never executed automatically.

The target user is a volunteer at a family association who holds a position her community shares, knows the elders who share it, and has no idea that a comment period closes in eleven days or that sixty in-language comments on the record outweigh a hundred people who told each other how they feel. Quorum hands her the finished draft and the advice on where to send it.

## How we built it

**Generation grounded in a fact graph.** The hard problem with generated advocacy advice is that a confident wrong deadline costs an organizer the one resource they can't recover. So Quorum splits the work: an LLM writes the briefs, proposes evidence bindings, and drafts the outreach copy — while every procedural fact underneath is *retrieved* through a staged pipeline into a persistent Jac graph, with a source URL or an explicit gap. The advice is generated; the facts never are.

The pipeline is a one-way street. Every stage writes to disk, nothing flows back upstream, and any stage can fail or be rerun without taking the system down:

```
Structured APIs ─┐
(Socrata 311,    │
 Legistar)       ├─→ cache/ ─→ extract/ ─→ fixture.json ─→ Jac knowledge ─→ walkers ─→ playbook,
                 │   offline-   schema-     THE ONLY        graph            traverse    3 recourse
Firecrawl,      ─┘   capable    gated       INTERFACE       (7 layers)                   paths,
Apify (Reddit)                                                                           outreach packet
```

### Stage 1 — Fetch: structured APIs first, Firecrawl for the rest

Structured sources are free, fast, and typed, so they go first: **Socrata** queries DataSF 311 inside a bounding box drawn from the case manifest; **Legistar** covers legislative matters — via the official API for historical data and a portal scraper for anything current (the API feed is frozen at ~Dec 2018, a real-world gap we discovered the hard way). **Firecrawl** handles everything with no API: commission agenda pages, comment-submission instructions, and local and in-language press. **Apify** pulls Reddit threads for community context — usernames scrubbed at fetch time, disclosed as a scraping path, and never treated as testimony.

Every fetch is cache-first, keyed by a hash of the request: a repeat call does no network I/O and spends nothing, and a warm cache means the entire pipeline — and the demo — runs with the network unplugged. Firecrawl spend is tracked in a cumulative credit ledger that raises `BudgetExceeded` rather than silently overspending. New cases enter as YAML manifests holding *research knobs only* (search terms, geography, candidate orgs) — never fetched facts — bootstrapped by an LLM draft and human-verified before the pipeline trusts them.

### Stage 2 — Extract: a gate, not a transform

Four extractors turn raw fetches into fixture-shaped records, and their job is to *refuse* bad data: `procedure` extracts comment channels and deadlines (dead links filtered, dates normalized or emitted as the literal `"unknown"` — never guessed); `orgs` resolves organization contacts (a contact, or an explicit blank plus notes on where we looked); `narrative` extracts testimony from press (speakers reduced to roles, never private individuals' names); `forum` LLM-summarizes Reddit threads into context incidents. Firecrawl's JSON mode does the structured extraction; the schema gate (`FIXTURE_SCHEMA`) rejects anything without a source URL. By design, only the forum extractor writes the fixture directly — merging procedural facts is a reviewed, manual step, because those are the facts an organizer will act on.

### Stage 3 — The contract: `out/fixture.json`

One schema-validated JSON document with seven collections — projects, geo zones, decision bodies, comment channels (with deadlines), organizations, testimony, incidents. It is the **only** interface downstream: nothing past this point calls Firecrawl, reads the cache, or imports a fetcher. Every record carries `source_url` and `fetched_at`, so the UI can badge each fact `live` vs `cached`. An empty `comment_channels` entry for a decision body is a *finding*, not missing data — it flows all the way to the final output as a gap.

### Stage 4 — Materialize the knowledge graph (Jac)

`fixture_adapter.jac` reads the fixture offline and materializes it into one persistent Jac workspace. Each record gets a stable ID derived from its natural key, held by a `FixtureRecord` provenance node alongside the source URL and retrieval info — so re-running ingestion *reuses* nodes instead of duplicating them, and every graph fact can be traced back to where it was fetched. Records land in seven explicit semantic layers (issue/signal, narrative/evidence, community/stakeholder, institution/decision, law/procedure, precedent/action, campaign/activation) over a frozen contract of 15 curated node types and 13 edge types.

The edges are where fetched data meets curated judgment. Fetched records arrive flat and get edged on ingest: `located_in`, `decided_by`, `serves`, `governed_by`. The edges that *can't* be fetched are hand-curated: `accountable_to` (who a decision body answers to — the hero edge for divergence) and `inside_process` (who was in the room — never model-set). And when a link the reasoning needs doesn't exist — the fixture contract has no channel→body binding, because we never verified one — the adapter records an explicit `ProcedureGap` node instead of guessing an edge.

### Stage 5 — Walkers traverse

Six Jac walkers assemble the outputs by walking the graph — no HTTP, no model call inside a traversal:

| Walker | What it contributes to the output |
|---|---|
| `DecisionWalker` | Project → `decided_by` → body → channel → cited deadline (or a `ProcedureGap`) |
| `ImpactWalker` | Project → zones → the organizations that serve them, flagging who was never `inside_process` |
| `DivergenceCheck` | **Forks**: one traversal to impact zones, one through `accountable_to` to decision zones — the advice is whether the endpoints match. No node stores the answer |
| `PrecedentMatcher` | Trait-matched precedent (`excluded_org`, `outvoted_citywide`) → which tactics worked |
| `EvidenceMatcher` | Scans testimony against channels; proposes `potentially_relevant_to` links (term overlap, language access), each `model_proposed: true`, `review_status: "unreviewed"` |
| `RecommendRecourse` | Composes all of the above into the three recourse paths — the headline advice |

### Stage 6 — Output: validated advice, structurally honest

`RecommendRecourse` accepts optional LLM-proposed paths, then validates them ruthlessly: exactly three paths in slot order (`recorded_comment`, `decision_zone_contact`, `escalation`), each with exactly three `first_steps`, at least one stated uncertainty, a `binding_effect` from a closed vocabulary, and `source_ids` that must resolve to nodes *already in the graph* — a fixture record, a procedure gap, or a curated node. Nothing citable can be invented. If any check fails, the whole proposal is discarded and a deterministic fallback produces the three paths instead, with `origin: "deterministic_fallback"` and the rejection reasons surfaced as provenance. The endpoint never returns fewer than three paths because a model misbehaved.

The honesty boundary is structural, not a prompt: `EvidenceMatcher` can only ever write `potentially_relevant_to` — no `satisfies` or `proves` relationship is even declared in the workspace, and a runtime check (`forbidden_relation_names()`) confirms it. `legal_reviewed` is always `false` on output; no caller, model, or fixture can set it to `true`. The generator physically cannot claim a legal standard is met.

That validated JSON — divergence verdict, playbook, gaps, excluded organizations, precedent matches, three action paths — feeds the final artifacts: the **Jac fullstack UI** (pages, components, and API walkers all in Jac) renders it verdict-first with citation chips and `live`/`cached` badges, and the bilingual outreach drafts wrap the playbook's ask into per-organization English and Chinese copy, staged for human review. Nothing is a hardcoded answer, and nothing sends automatically.

## Challenges we ran into

- **Advice is only as good as the facts under it — and real procedure resists resolution.** Rec & Park's and the D3 supervisor's project-specific comment channels never resolved; every candidate agenda page had gone dead by scrape time. Rather than generate a plausible channel, `DecisionWalker` reports a first-class `ProcedureGap` — and in the lead case, the gap *proves the thesis* that the record was never reachable.
- **311 data lies by category.** "Portsmouth Square" returns 994 311 cases — 609 of them routine maintenance at that address. SF's 311 taxonomy has no category for opposing a project. We shipped an honest zero rather than dressing maintenance tickets up as controversy evidence for the brief.
- **Frozen upstream data.** Legistar's new-matter API feed is stuck at ~Dec 2018, so neither demo case exists in it; we built a portal scraper for the current data and disclosed the split.
- **Building substantially in Jac.** Keeping node, edge, walker, mutation, and validation logic in a young language — while meeting a 40%+ Jac source-line share — meant compiling after every small change and reading compiler output instead of assuming.

## Accomplishments that we're proud of

- **Generated advice with zero fabricated procedural facts.** 3 comment channels verified with source URLs returning 200; 9/9 organizations resolved to a real contact or an explicit blank with notes on where we looked; 22 testimony records from local and in-language press, all sourced, private individuals reduced to roles.
- **The targeting advice is computed, not scripted.** `DivergenceCheck` derives "your audience isn't the deciding audience" from a fork in the graph — the answer exists in no single node.
- **Gaps as output.** When the tool can't verify a channel, it says so instead of guessing — and that refusal is what makes the drafts it *does* generate trustworthy.
- **An offline-by-design demo.** Venue wifi can die; the cache is failure isolation, not an optimization. 42/42 tests pass with no network.
- **New cases are config, not code** — a YAML manifest, LLM-drafted then human-verified before it's trusted.

## What we learned

- Communities don't need another awareness tool — they need the finished output: the drafted comment, the named recipient, the deadline, and one piece of honest strategic advice about who actually decides.
- Generated advice needs a retrieval floor. The Prop K litigation turned on whether environmental review applied *at all* — a subtlety no model should guess. Structural constraints (no `satisfies` edge exists to write) beat prompt-level promises.
- Object-Spatial Programming is a genuine fit when the advice lives in the topology: divergence is a comparison of two traversal endpoints, not a field on a node.
- This is dual-use campaign infrastructure — it would generate output identically for a developer manufacturing support. There's no clean technical fix; we name it rather than pretend otherwise. Nothing sends automatically; a human reviews and sends, contacts are organization-level only, and the countable unit is a distinct submitter in their own words, not a distinct email.

## What's next for Quorum

- Wire the remaining generators (`RecommendRecourse`, `EvidenceMatcher`, `BuildCampaign`) fully into the UI — response contracts are already specified.
- Richer advice per recourse path: expected effort, historical success signals from the precedent library, and what "enough" input looks like for each channel.
- DataSF live mode with cache fallback, keeping the source badges honest.
- The accessibility entry point: in-product Chinese language path and text zoom.
- More cases as verified manifests — the pipeline already treats a new case as config.

## Built with

- **Jac / jaclang** — graph schema, walkers, seeds, validation, and the fullstack UI (pages, components, API)
- **Python** — cache-first ingestion pipeline (fetch → extract → emit)
- **Socrata (DataSF 311)** and **Legistar** — structured civic data
- **Firecrawl** — budget-guarded scraping for sources with no API
- **Apify** — Reddit community-forum context (disclosed, never testimony)
- **LLM (`by llm()`)** — issue briefs, evidence-binding proposals, bilingual outreach drafts, recourse advice copy — never procedural facts
- **pytest** — 42 offline tests covering the fixture contract, cache/budget behavior, extraction, and portal parsing
