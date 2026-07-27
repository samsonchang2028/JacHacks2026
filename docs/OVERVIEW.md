# Quorum — Product Overview

**Making community objections countable.**

JacHacks SF 2026. A tool that turns held community opinion into procedurally countable input, aimed at whoever actually decides.

---

## The Problem

When a government action harms a local community, the community usually loses. Not because it didn't care enough — because it lost on structure. Two failure modes, both drawn from real San Francisco cases.

### Failure mode A — the objection never became countable

**Portsmouth Square, Chinatown.** A ~$73M renovation broke ground in June 2026, closing the park for roughly two years. The renovation was broadly supported; the contested piece was demolition of the historic pedestrian bridge over Kearny Street.

Real opposition existed, held by serious people:

- CCBA — the 176-year-old association representing Chinatown's family associations — says it was never invited to project-related community meetings, and that the neighborhood's nonprofits don't speak for everyone.
- A CCBA board member of five decades opposed the removal and says he never heard the plan from city officials.
- The Merchants United Association (150+ merchants) protested, and objected to three major Chinatown construction projects starting at once.

And yet the District 3 supervisor said he was unaware of opposition to the bridge removal, and that his office had received **no communication** in support of keeping it.

That is the problem in one sentence. The community held a position. The decision-maker's record held nothing. The gap was not awareness, motivation, or network — CCBA has more of all three than any software could add. The gap was that held opinion never converted into countable comment, through the right channel, before the right deadline.

### Failure mode B — the objection hit the wrong electorate

**Prop K / Great Highway, Nov 2024.** The measure passed citywide with 54.73%. It lost roughly 60–40 in the Sunset and 70–30 in the Richmond; across Districts 1, 4, 7 and 11 the split was about 61% no.

The westside opposition was not disorganized. One opponent spent $269,000. They filed a CEQA challenge, lost, appealed, and their campaign prompted the successful recall of a sitting supervisor.

Their own post-mortem is the diagnosis: the organized opposition never went east of West Portal. Most of the city heard "a new park" and little about local traffic impact. **The persuadable audience was the citywide electorate. The outreach went to the impact zone, which already agreed.**

---

## The Insight

Most civic tech optimizes awareness *inside* the affected community. Both failures show that's the wrong target.

> **The impact zone and the decision zone are different graphs. The product's job is to say so when they diverge.**

| Case | Impact zone | Decision zone | Divergence type |
|---|---|---|---|
| Portsmouth Square | Chinatown, District 3 | Rec & Park, D3 supervisor's office | **channel** |
| Prop K | Sunset, Richmond | ~350k+ citywide voters | **electorate** |

Same tool, opposite advice. When zones align, the fix is routing input into the record on time. When they diverge, the fix is persuading a constituency the organizer wasn't talking to.

---

## The Solution

Given a civic action — project, proposal, agenda item, or ballot measure — the tool:

1. **Gathers existing signal.** News, in-language press, 311 records, meeting minutes. Establishes that discontent is already documented.
2. **Finds who actually decides.** Which body approves this, and which constituency that body answers to.
3. **Retrieves hard procedural facts.** Recipient, submission format, comment deadline, appeal window — each with a source URL, or reported as a gap. Never generated.
4. **Matches precedent by failure mode.** Not by what got built — by *how the community lost*. Cases sharing traits like `excluded_org` or `outvoted_citywide`.
5. **Matches evidence to channel.** Ranks which testimony is *potentially relevant* to which comment channel or standard — never asserting a legal standard is met.
6. **Generates the outreach packet.** Bilingual emails and social copy to relevant organizations, where the call-to-action is that specific, deadlined, correctly-addressed submission.
7. **Flags divergence and retargets.** When impact ≠ decision, say it explicitly and aim persuasion material at the deciding constituency instead.

**Headline artifact:** the procedural playbook and the outreach packet, wired together — a packet whose ask is a real, deadlined, correctly-addressed comment. Playbook and packet aren't two deliverables. The playbook supplies the ask; the packet is the wrapper. The concrete output is **exactly three recourse paths** — `recorded_comment`, `decision_zone_contact`, `escalation` — each source-backed and never marked legally reviewed.

**Target user:** a volunteer at a family association who holds a position her community shares, knows the elders who share it, and has no idea that a comment period closes in eleven days, that comments go to a specific commission secretary in a specific format, or that sixty in-language comments on the record would outweigh a hundred people who felt strongly and told each other.

---

## The Pipeline

Every stage writes to disk, so any stage can fail without taking the system down.

```
Structured APIs  ─┐
(Socrata,         │
 Legistar)        ├─→  cache/  ─→  extract/  ─→  fixture.json  ─→  Jac graph
                  │    offline-    schema-        the only         walkers
Firecrawl        ─┘    capable     gated         interface        traverse
(pages with
 no API)
```

**Structured APIs first.** Socrata and Legistar are free, fast, and return typed data. Firecrawl handles what has no API — commission agendas, comment instructions, in-language press. (Reddit context, when used, rides Apify — a scraping path, disclosed as such, and never treated as testimony.)

**The cache is failure isolation, not an optimization.** Venue wifi dies, rate limits hit, a site changes markup — a warm cache is untouched. The pipeline runs offline by design.

**Extraction is a gate, not a transform.** Its job is to *refuse* bad records. No source URL, no node. Missing date emits the literal string `unknown`. That refusal is what makes the playbook trustworthy.

**`fixture.json` is the only interface.** Downstream consumers never call Firecrawl, read the cache, or import a fetcher. Nothing flows back upstream, so any stage can be rerun in isolation. A fixture adapter (`fixture_adapter.jac`) reads it offline and materializes graph nodes behind stable `FixtureRecord` identities, so repeated ingestion reuses nodes rather than duplicating them.

**New cases are config, not code.** The two demo cases are curated, `verified: true` gold-standard manifests (`ingest/config/cases/*.yaml`); adding a case is a manifest change, bootstrapped by an LLM draft and then human-reviewed before it's trusted.

**Firecrawl spend is budgeted.** A cumulative credit ledger raises `BudgetExceeded` rather than silently overspending.

---

## Architecture — Why a Graph

The core questions are relational, not tabular: *who decides this, who do they answer to, which past case is this like, which channel actually counts.* Jac's Object-Spatial Programming — persistent node/edge topology with walkers carrying computation through it — is a genuine fit rather than a retrofit.

**15 curated node types and 13 edge types** form the frozen contract in `schema.jac`. What persists is the curated knowledge; what's fetched is transient input bound into it by the ingestion adapter. On top of that frozen core, the walkers and adapter add a handful of *additive* archetypes for provenance and output — `FixtureRecord`, `ProcedureGap`, `ActionPath`, `Claim`, layer anchors, and the `potentially_relevant_to` relationship — so the graph visibly grows at ingest and traversal time without mutating the contract.

| Curated (can't be fetched) | Fetched (flat on arrival, edged on ingest) |
|---|---|
| `accountable_to` — who a body answers to | `Project`, `GeoZone`, `Incident` |
| `inside_process` — who was in the room | `Testimony` |
| `CommentChannel`, `Deadline` (with citations) | `located_in`, `decided_by`, `analogous_to` |
| `PrecedentCase`, `Tactic`, `Outcome` | |

### The walkers

Six walkers run entirely on the local graph — no HTTP, no model call inside the traversal.

| Walker | Question | Ends on |
|---|---|---|
| **`DivergenceCheck`** | Is your audience the deciding audience? | zone comparison |
| `DecisionWalker` | Who do I submit to, how, by when? | a cited deadline (or a `GAP`) |
| `ImpactWalker` | Who's affected, who was never in the room? | organizations |
| `PrecedentMatcher` | What's been tried, did it work? | an outcome |
| `EvidenceMatcher` | Which testimony is relevant to which channel/standard? | `potentially_relevant_to` links |
| `RecommendRecourse` | What exactly do I do next? | **exactly three** `ActionPath`s |

Of the four traversal walkers, three are single chains. `DivergenceCheck` **forks** — two paths from the same node, and the answer is whether the endpoints match. No node stores it. `EvidenceMatcher` scans and proposes links but only ever writes `potentially_relevant_to` — no `satisfies`, no `proves` archetype exists in the workspace. `RecommendRecourse` composes the other walkers and always returns three source-backed paths, falling back deterministically if a model proposal fails validation.

---

## What's Innovative

**1. Naming the divergence.** Every civic tool we know of assumes the affected community is the audience. Distinguishing impact zone from decision zone, and telling an organizer *"you are not the electorate for this decision — here's who is,"* is the thing the Prop K opposition paid $269,000 to learn late.

**2. Precedent matching by failure mode, not category.** Boston's Parcel C fight resembles Portsmouth Square because in both an in-language community was excluded from an official process — one is a park, the other a parking garage. Category matching throws that comparison away. Trait matching (`excluded_org`, `in_language_community`, `outvoted_citywide`) finds the analogy that actually transfers.

**3. A hard retrieval/generation boundary.** The LLM proposes bindings and writes copy. The graph holds facts. It never decides what the law is — enforced structurally: `EvidenceMatcher` can only ever write `potentially_relevant_to`, `legal_reviewed` is always `false` on output, and no `satisfies`/`proves` relationship is even declared. Real procedure is subtler than a model will guess — the Prop K litigation turned on whether environmental review applied at all, since the measure was placed on the ballot by a minority of supervisors, who the court held don't constitute a public agency. A confident wrong deadline costs an organizer the one resource they can't recover.

**4. Gaps as first-class output.** When a channel doesn't resolve, the tool reports a `ProcedureGap` rather than a plausible guess. Doing so is what makes the rest of the output trustworthy — and in the lead case it happens to prove the thesis.

**5. Multi-hop as the actual mechanism.** The divergence answer exists in no single node, which is what makes this graph work rather than a lookup in graph syntax.

---

## Status

Run against live production sources, not mocked:

- **3 comment channels verified**, each source URL confirmed returning 200
- **9/9 organizations** resolved to a real contact or an explicit blank plus notes on where we looked
- **22 testimony records** pulled from local and in-language press, all sourced, private individuals reduced to roles
- **0 fabricated** deadlines, channels, or outcomes

**Honest gaps, left as gaps:**

- Rec & Park and the D3 supervisor's *project-specific* comment channels never resolved — every candidate agenda page had gone dead by scrape time. `DecisionWalker` reports this as a `ProcedureGap` at runtime rather than inventing one.
- No 311 incidents, on purpose. "Portsmouth Square" returns 994 311 cases, 609 of them routine Rec & Park maintenance at that address. SF's 311 taxonomy has no category for opposition to a project. An honest zero beats maintenance tickets dressed up as controversy evidence. `incidents` instead carries 11 LLM-summarized community-forum threads (a disclosed scraping path, usernames scrubbed) — context signal, never testimony.
- Legistar's new-matter API feed is frozen at ~Dec 2018, so neither case exists in it; the public portal is current but scrape-only.

---

## Limits and Risks

**It's dual-use.** This is campaign automation infrastructure. It works identically for a developer manufacturing support. There's no clean technical fix; we name it rather than pretend otherwise.

**Mass-generated comment can backfire.** Staff recognize bulk LLM text and discount it. The tool generates per-organization outreach asking people to submit in their own words; the countable unit is a distinct submitter, not a distinct email.

**Neutral on outcome, partisan about process.** Both motivating cases involve opposition to a park and a car-free space, which will read differently to different people. The position we defend is narrow: a community's view should be in the record before the decision, not after.

**Nothing is sent automatically.** The pipeline drafts and stages. A human reviews and sends. Contacts are org-level only — no individuals, no member or parent rosters.
