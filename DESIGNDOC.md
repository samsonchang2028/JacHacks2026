# Quorum — Making Community Objections Countable
**JacHacks SF 2026 — Design Doc (v2)**

*Name is a placeholder. The thesis: an objection only matters if it is countable, on the record, and aimed at whoever actually decides.*

---

## 1. Problem Statement

When a government action harms a local community, the community usually loses for one of two reasons — and neither is "they didn't care enough."

### Failure Mode A — the objection never becomes countable (lead case)

**Portsmouth Square, SF Chinatown.** The $73M renovation broke ground in June 2026, closing the park for roughly two years. The renovation itself was broadly supported; the contested piece was the removal of the historic pedestrian bridge over Kearny Street connecting the park to the Hilton, demolished to make room for a larger two-story clubhouse.

Real opposition existed and was held by serious people:
- CCBA — the 176-year-old association representing Chinatown's family associations — says it was never invited to project-related community meetings, and that the neighborhood's nonprofits do not speak for everyone.
- Thomas Ng, a CCBA board member of five decades, opposed the removal and says he never heard the plan from city officials.
- Ed Siu of the Merchants United Association (150+ merchants) protested the removal, and objected to three major Chinatown construction projects starting simultaneously.

And yet: District 3 Supervisor Danny Sauter said he was unaware of opposition to the bridge removal, and that his office had received no communication in support of keeping it.

**That is the entire problem in one sentence.** The community held a position. The decision-maker's office recorded zero input on it. The gap was not awareness, motivation, or network — CCBA has more of all three than any tool could add. The gap was that held opinion never converted into procedurally countable comment, submitted through the right channel, before the right deadline.

### Failure Mode B — the objection is aimed at the wrong electorate (secondary case)

**Great Highway / Prop K (Nov 2024).** Prop K passed citywide with 54.73%. It lost roughly 60–40 in the Sunset and 70–30 in the Richmond; across Districts 1, 4, 7 and 11 the split was about 61% no to 39% yes.

The westside opposition was *not* disorganized. One opponent spent $269,000 against the measure. They filed a CEQA challenge, lost, appealed to the First Appellate District, and their campaign prompted the successful recall of Supervisor Engardio. They are now gathering signatures for a follow-up measure.

Their own post-mortem is the diagnosis: the organized opposition never went east of West Portal. The rest of the city heard "a new park" and little about local traffic impact or realistic utilization. **The persuadable audience was the citywide electorate. The outreach went to the impact zone, which already agreed.**

---

## 2. The Insight

Most civic-tech tools optimize awareness within the impacted community. Both failure modes above show that's the wrong target.

> **The impact zone and the decision zone are different graphs, and the tool's job is to tell you when they diverge.**

- Portsmouth Square: impact zone = Chinatown residents. Decision zone = Rec & Park, District 3 supervisor's office, specific comment periods. Divergence type: *channel*.
- Prop K: impact zone = Sunset/Richmond. Decision zone = 350,000+ citywide voters. Divergence type: *electorate*.

Naming that divergence out loud, automatically, is the product.

---

## 3. Target User

**A volunteer or junior board member at a Chinatown family association** who holds a position their community shares, knows the elders who share it, and has no idea that (a) a comment period closes in eleven days, (b) comments go to a specific commission secretary in a specific format, and (c) sixty in-language comments on the record would have outweighed a hundred people who felt strongly and told each other.

Not "civic advocacy organizations." One person, one vote she didn't know how to reach.

---

## 4. Solution Overview

Given a civic action (project, proposal, agenda item, or ballot measure), the tool:

1. **Gathers existing signal** — news coverage, in-language press, 311 records, prior meeting minutes — establishing that discontent already exists and is documented. *(Issue + Narrative layers)*
2. **Identifies the decision zone** — which body actually approves this, who that body answers to, and which constituency's opinion is load-bearing. *(Institution layer)*
3. **Surfaces hard procedural facts** — open comment periods, submission channels and formats, appeal windows, petition thresholds, named contacts. *Retrieved from curated records, never generated.* (See §6.) *(Law layer)*
4. **Matches precedent** — structurally similar past cases, what channel the opposition used, and what actually moved. *(Action layer)*
5. **Ranks which local stories are legally load-bearing** — matching resident testimony and complaints to the legal standard each one actually satisfies, then routing them to the body that applies that standard. *(Narrative × Law)*
6. **Generates the outreach packet** — bilingual emails and social copy to relevant organizations, where the call-to-action is the specific countable submission from step 3, backed by the corroborating stories from step 5.
7. **Flags divergence and targets accordingly** — when the impact zone ≠ decision zone, say so explicitly, and generate persuasion material (including geotargeted ad creative) aimed at the deciding constituency rather than the affected one.

**Headline demo artifact:** the procedural playbook and the outreach packet, wired together — a packet whose ask is a real, deadlined, correctly-addressed comment.

---

## 5. Why Jac (Architecture)

The core questions here are relational, not tabular: *who decides this, who do they answer to, which past case is this like, which channel actually counts.* Jac's Object-Spatial Programming — persistent node/edge topology with walkers carrying computation through it — is a genuine fit rather than a retrofit.

### 5.1 What Persists vs. What Arrives

Your instinct is right and it sharpens the architecture: **the curated graphs are the ones that can't be fetched in one pass.** Everything else is input, not knowledge.

Jac supports this cleanly — whatever is reachable from `root` persists, so the split is a modeling decision rather than a database chore.

**Persistent graphs (curated, traversed by walkers):**

- **Law graph** — `Ordinance`, `Statute`, `Regulation`, `CaseDecision`, `AdminDecision`, `Deadline`, `LegalStandard`
- **Action graph** — `PrecedentCase`, `Tactic`, `Outcome`
- **Institution skeleton** — `DecisionBody`, `CommentChannel`, and the `accountable_to` edge *only* (see the warning in §5.2)

These are graphs because the relationships *are* the content: which standard governs which action, which tactic relied on which legal hook, which body answers to which constituency. None of it comes back from an API call.

**Fetched at runtime (flat on arrival):**

- **Issue data** — the project record, location, 311 incident counts, affected population. Sources: Legistar API, DataSF/Socrata, Planning records.
- **Narrative data** — news coverage, in-language press, public testimony, complaint text. Sources: search API, browser agent for sites without one.
- **Institution detail** — official names, office contacts, org rosters. Mostly scrapeable or already public.

### 5.2 Flat on Arrival, Edged on Ingest

The important move: fetched data doesn't stay flat. An **`Ingest` walker** binds each arriving record into the persistent graph — attaching a `Complaint` to the `LegalStandard` it plausibly satisfies, a `Project` to the `DecisionBody` that governs it, a fetched case to the `PrecedentCase` it resembles.

**This is a stronger Jac story than v2 had**, not a weaker one. Computation traveling to newly-arrived data and wiring it into a persistent topology is the paradigm's actual pitch. It also removes the "is this just a hardcoded dictionary?" objection, since the graph visibly grows during the demo.

Edges created at ingest time:

| Edge | From → To | Created |
|---|---|---|
| `governed_by` | Issue → Law | ingest |
| `decided_by` | Issue → Institution | ingest |
| `supports_claim_under` | Narrative → Law (`LegalStandard`) | ingest *(highest value — §5.3)* |
| `rebuts` | Narrative → Narrative | ingest |
| `analogous_to` | Issue → Action | ingest |
| `accountable_to` | Institution → `GeoZone` | **curated** |
| `accepts_input_via` | Institution → `CommentChannel` → `Deadline` | **curated** |
| `relied_on` | Action → Law | **curated** |

**⚠️ One thing you can't flatten.** `DivergenceCheck` — your single best 30 seconds of demo — depends entirely on the `accountable_to` edge from `DecisionBody` to `GeoZone`. That edge is not in any API; it's the judgment that Prop K was decided by a citywide electorate while the harm landed in two districts. Flatten the Institution layer completely and the divergence reveal disappears. So keep a **three-node-type institutional skeleton** (`DecisionBody`, `CommentChannel`, `GeoZone`) and let the fetched contact details hang off it as fields. That's maybe twenty minutes of seed data for the highest-value moment in your pitch.

### 5.3 The Highest-Value Edge: `supports_claim_under`

An organizer with forty resident stories has no idea which three are *legally load-bearing*. A traffic-safety complaint may be irrelevant to a design review but decisive under an environmental standard; a senior-mobility story may be inert as sentiment and dispositive as an accessibility claim.

Fetched narrative arrives flat; `Ingest` binds it to `LegalStandard` nodes; `EvidenceMatcher` then ranks which testimony goes in front of which body under which standard. **That is work no organizer can do alone and no single-hop query can produce** — and it's the direct realization of your original "corroborate with local stories" idea. If one thing gets pointed at on stage, this is it.

### 5.4 Walkers

- **`Ingest`** — binds fetched Issue/Narrative/Institution records into the persistent Law/Action/skeleton graphs. Runs live on stage.
- **`DecisionWalker`** — Issue → `DecisionBody` → `accountable_to` `GeoZone`, and → `CommentChannel` → `Deadline`. Output: playbook + persuasion target.
- **`ImpactWalker`** — Issue → `GeoZone` → `Organization`. Output: mobilization list.
- **`DivergenceCheck`** — compares the terminal `GeoZone` of the two walkers above. On mismatch, emits the warning and reroutes persuasion to the decision zone. **The answer exists in no single node** — that's what separates a rubric 5 from a dictionary lookup.
- **`EvidenceMatcher`** — Narrative → Law, ranking testimony by which `LegalStandard` it satisfies, then routing each to the `CommentChannel` where it counts.
- **`PrecedentMatcher`** — Issue → Action by structural similarity, pulling the `Tactic`, its `Outcome`, and the `LegalStandard` it `relied_on`.

### 5.5 byLLM Boundary (important)

`by llm()` handles **framing, language, and classification**:
- plain-language brief from fetched signal
- classifying arriving records into `Argument` / `Evidence` / `Testimony`, and proposing the `supports_claim_under` binding at ingest
- outreach copy per organization (tone, language — the CCBA email in Chinese is the demo's standout moment)
- ad creative for the decision-zone audience

`by llm()` never produces: deadlines, thresholds, statutory text, legal conclusions, or contact details. Those live in curated Law and Institution nodes with source citations attached. Rationale in §6.

Note the division of labor: the LLM *proposes* a binding, the graph *holds* it, and the walker *ranks* it. The LLM never decides what the law is.

### 5.6 Fetch Reliability (the new main risk)

Trading seed data for live fetching trades one risk for another. Live fetching is what makes the demo feel real, and it's also the thing most likely to kill it on stage.

- **Prefer direct APIs over browser agents.** Legistar and DataSF/Socrata both have APIs; use the agent only for sites without one, like in-language press.
- **Cache every fetch to disk on first success**, and have the demo read cache-first with a visible "cached" badge. If the venue wifi dies at minute two, you still ship.
- **Budget the clock.** A browser agent crawling a records site can eat 40 seconds of a 4-minute demo. Pre-warm the cache before you present and let the live fetch be one visible call, not the whole pipeline.
- **Rate limits and auth** will surprise you at the worst moment. Test against the real endpoints early in the day, not at hour nine.


---

## 6. Retrieval, Not Generation, for Procedural Facts

This is the highest-harm component in the product and needs a hard rule.

A hallucinated comment deadline costs an organizer the one resource they have least of. Real procedure is also subtler than an LLM will guess — the Prop K litigation turned on whether CEQA applied at all, since the measure was placed on the ballot by a minority of supervisors, who the court held do not constitute a public agency.

**Rule:** every `Deadline` and `CommentChannel` node carries a source URL and retrieval date, surfaced in the UI. If a fact has no citation, the tool shows a gap rather than a guess. Say this out loud during the demo — judges notice teams that know where their own thin ice is.

---

## 7. Geolocated Ads — Revised Role

**What changed:** ads are no longer an impact-zone outreach channel. They're a **decision-zone persuasion channel**, deployed only when `DivergenceCheck` fires.

Reasoning: an elderly, non-digital audience is exactly who digital ads fail to reach, so the Chinatown case is the wrong home for this feature — there the channels are in-language print, WeChat groups, and in-person association meetings. The Prop K case is the right home: eastside voters who decided the outcome and lacked local-impact information were reachable, persuadable, and cheap to target relative to a citywide buy.

**Scope for the hackathon:** compute the target zone via `DecisionWalker` (real Jac logic), generate creative via byLLM, render a radius preview. No live ad buy.

**Constraints to know if asked:** issue and ballot-measure ads require platform authorization and disclaimers, geotargeting has minimum-radius floors, ballot-measure spending triggers FPPC and SF Ethics disclosure obligations, and someone has to fund it — which organizers typically can't.

---

## 8. Demo Script (4 minutes)

| Time | Beat |
|---|---|
| 0:00–0:50 | Portsmouth Square. Real opposition from CCBA, a five-decade board member, and 150+ merchants. Then the supervisor's line: no communication received. "The community had a position. The record had nothing." |
| 0:50–2:40 | Live run. Input the project → `DecisionWalker` returns the deciding body, the open comment channel, the deadline, each with a citation → `PrecedentMatcher` surfaces the analogous case → out comes the bilingual outreach packet whose ask is that specific submission. |
| 2:40–3:20 | Second run on Prop K. `DivergenceCheck` fires: "Impact zone: Sunset/Richmond. Decision zone: citywide electorate. Your outreach is aimed at people who already agree." Show the graph visualization with the walker's path lit up. Point at the Jac source for 15 seconds. |
| 3:20–4:00 | Close: the west side spent $269k and won its own districts by 60–70 points, and still lost, because the persuadable audience was somewhere else. The tool's job is to say that on day one, not in the post-mortem. |

The Prop K divergence moment is your strongest 30 seconds. It's counterintuitive, it's provably true, and it can only come from traversal.

---

## 9. One-Day Build Plan

Priority is a clean, legible demo — but the graph work comes first because it's cheap in hours and worth 40%.

**Hours 1–3 — Jac core (non-negotiable)**
- Law + Action graph schemas, plus the three-node institutional skeleton (§5.2)
- Curated seed data, small: 4–6 `LegalStandard` / `Deadline` nodes with source citations; 4–6 `PrecedentCase` nodes with the `Tactic` and `LegalStandard` each relied on; `DecisionBody` and `GeoZone` nodes for Rec & Park, the D3 supervisor's office, and the citywide electorate, wired with `accountable_to`
- `Ingest`, `DecisionWalker`, `ImpactWalker`, `DivergenceCheck`, `EvidenceMatcher`, `PrecedentMatcher`

**Hour 4 — Fetch layer**
- Legistar + DataSF API calls for Issue data; search/browser agent for Narrative
- Cache-to-disk on first success, cache-first reads (§5.6)

**Hours 5–6 — byLLM layer**
- Three calls: brief, per-org outreach copy (incl. Chinese-language CCBA email), decision-zone ad creative

**Hours 7+ — Frontend (your priority)**
- **Make the graph visible, and show it growing.** Render the persistent Law/Action graph, then animate `Ingest` attaching fetched records into it live. This is the single highest-leverage frontend decision: it doubles as Use-of-Jac evidence, so polish hours pay into the 40% instead of only the 20%.
- Divergence warning as a prominent UI state, not a log line
- Citation chips on every procedural fact; "cached" vs "live" badge on every fetched record
- Consider building in Jac itself (`jac-client`, JS codegen) so frontend time counts toward Use of Jac — only if you're comfortable with the syntax under time pressure

**Cut:**
- Live scraping — pre-fetched JSON blob
- Real ad platform integration
- Any generated legal reasoning beyond retrieved, cited facts

---

## 10. Known Risks / Prepared Answers

**"Isn't this a NIMBY tool?"** It's neutral on outcome and partisan only about procedure — that a community's position should be in the record before a decision, not after. Leading with Portsmouth Square (an excluded association with a real grievance and no channel) rather than Prop K keeps this honest. Be ready for it regardless; both motivating cases involve opposition to a park and a car-free space, and that will land differently with different judges.

**"Won't this just flood offices with AI-generated form letters?"** Real risk, and it can backfire — staff recognize bulk-generated comment and discount it. Mitigation: the tool generates *per-organization* outreach asking people to submit in their own words, and the countable unit is a distinct submitter, not a distinct email. Don't oversell volume.

**"Could this manufacture fake support?"** Yes — it's dual-use campaign infrastructure that works identically for a developer astroturfing approval. No clean technical fix in one day; name it honestly rather than pretending otherwise.

**Facts to state carefully on stage**
- Prop K: 54.73% citywide; ~60% no in the Sunset, ~70% no in the Richmond. Don't round these wrong.
- Avoid "only 2 north–south routes" — the northern Great Highway section stayed open to cars, and the southern closure was driven by coastal erosion and the Coastal Commission independent of Prop K.
- Avoid an unsourced "unused 90% of the time" claim — park attendance figures have been publicized by supporters and this will be challenged.
- Note if pressed: city survey data reportedly showed 77% of residents supported the bridge demolition. Your argument is about *process*, not that the community was unanimous — don't overclaim consensus.

---

## 11. Rubric Mapping

| Criterion | Weight | Approach |
|---|---|---|
| Use of Jac | 40% | Divergence detection is genuinely multi-hop — no single node holds the answer. Graph visualized in the UI, source pointed at on stage. Target: 5. |
| Real-World Use Case | 20% | Two real, correctly-diagnosed SF cases; one named person; a gap confirmed by the supervisor's own statement. |
| Technical Execution | 20% | Four walkers, seven node types, cited seed data, three LLM calls — scoped to one day, with the retrieval/generation boundary drawn deliberately. |
| Demo & Story | 20% | Two live runs, the counterintuitive divergence reveal, visible graph traversal, honest risk disclosure. |
